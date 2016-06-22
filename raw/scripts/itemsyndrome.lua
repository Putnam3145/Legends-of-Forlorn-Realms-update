-- Checks for inventory changes and applies or removes syndromes that items or their materials have. Use "disable" (minus quotes) to disable and "help" to get help.
 
-- This is technically obsolete, replaced with item-trigger. However, the mod's large reliance on itemsyndrome makes upgrading inconvenient.

-- I'll probably convert later. For now, I'll just keep this.
  
local function printItemSyndromeHelp()
    print("Arguments (non case-sensitive):")
    print('    "help": displays this dialogue.')
    print(" ")
    print('    "disable": disables the script.')
    print(" ")
    print('    "debugon/debugoff": debug mode.')
    print(" ")
    print('    "contaminantson/contaminantsoff": toggles searching for contaminants.')
    print('    Disabling speeds itemsyndrome up greatly.')
    print('    "transformReEquipOn/TransformReEquipOff": toggles transformation auto-reequip.')
end
 
itemsyndromedebug=false

local argOps={}

argOps.help=function()
	printItemSyndromeHelp()
	return false
end

argOps.debugon=function()
	itemsyndromedebug=true
	return true
end

argops.debugoff=function()
	itemsyndromedebug=false
	return true
end

argops.contaminantson=function()
	itemsyndromecontaminants=true
	return true
end

argops.contaminantsoff=function()
	itemsyndromecontaminants=false
	return true
end

argops.transformreequipon=function()
	transformationReEquip=true
	return true
end

argops.transformreequipoff=function()
	transformationReEquip=false
	return true
end
 
function processArgs(args)
    for k,v in ipairs(args) do
        v=v:lower()
		if argOps.v then 
			local continue = argOps.v()
			if not continue then return end
		end
	end
end
 
local args = {...}
 
processArgs(args)
 
itemSyndromeSynClassInfo={}

itemSyndromeSynClassInfo.DFHACK_AFFECTS_HAULER=function(t)
	t.validPositions.AffectsHauler=true
end

itemSyndromeSynClassInfo.DFHACK_AFFECTS_STUCKIN=function(t)
	t.validPositions.AffectsStuckins=true
end

itemSyndromeSynClassInfo.DFHACK_STUCKINS_ONLY=function(t)
	t.validPositions.OnlyAffectsStuckins=true
end

itemSyndromeSynClassInfo.DFHACK_WIELDED_ONLY=function(t)
	t.validPositions.IsWieldedOnly=true
end

itemSyndromeSynClassInfo.DFHACK_ARMOR_ONLY=function(t)
	t.validPositions.IsArmorOnly=true
end

itemSyndromeSynClassInfo.DFHACK_ON_UNEQUIP=function(t)
	t.onUnequip=true
end

itemSyndromeSynClassInfo.DFHACK_ITEM_SYNDROME=function(t)
	t.isValid=true
end

local function syndromeIsIndiscriminate(syndrome)
    return not (#syndrome.syn_affected_class>0 or #syndrome.syn_affected_creature>0 or #syndrome.syn_affected_caste>0 or #syndrome.syn_immune_class>0 or #syndrome.syn_immune_creature>0 or #syndrome.syn_immune_caste>0)
end

local function syndromeIsTransformation(syndrome)
    for _,effect in ipairs(syndrome.ce) do
        if df.creature_interaction_effect_body_transformationst:is_instance(effect) then return true end
    end
    return false
end

local function findItemSyndromeInorganics()
    local matLookup={}
	local itemLookup={}
    for matID,material in ipairs(df.global.world.raws.inorganics) do
        if string.sub(material.id,0,29)=='DFHACK_ITEMSYNDROME_MATERIAL_' then 
			for k,syn in ipairs(material.syndrome) do
				local itemLookupInfo={}
				itemLookupInfo.syndrome=syndrome
				itemLookupInfo.validPositions={}
				for kk,syn_class in ipairs(syn.syn_class) do
					if itemSyndromeSynClassInfo[syn_class.value] then itemSyndromeSynClassInfo[syn_class.value](itemLookupInfo) end
				end
				itemLookupInfo.indiscriminate=syndromeIsIndiscriminate(syn)
				itemLookupInfo.transformation=syndromeIsTransformation(syn)
				itemLookup[syn.name]=itemLookupInfo
			end
		else
			for k,syn in ipairs(material.syndrome) do
				local matLookupInfo={}
				for kk,syn_class in ipairs(syn.syn_class) do
					if itemSyndromeSynClassInfo[syn_class.value] then itemSyndromeSynClassInfo[syn_class.value](itemLookupInfo) end
				end
				if matLookupInfo.isValid then 
					matLookup[matID]=matLookup[matID] or {}
					matLookupInfo.indiscriminate=syndromeIsIndiscriminate(syn)
					matLookupInfo.transformation=syndromeIsTransformation(syn)
					matLookupInfo.syndrome=syndrome
					matLookup[syn.syn_id]=matLookupInfo
				end
			end
		end
    end
    if itemsyndromedebug then printall(allInorganics) end
    if #allInorganics>0 then return allInorganics else return nil end
end
 
local function getAllItemSyndromeMats(itemSyndromeMatIDs)
    local allActualInorganics = {}
    for _,itemSyndromeMatID in ipairs(itemSyndromeMatIDs) do
        table.insert(allActualInorganics,df.global.world.raws.inorganics[itemSyndromeMatID].material)
    end
    if itemsyndromedebug then printall(allActualInorganics) end
    return allActualInorganics
end

local function alreadyHasSyndrome(unit,syn_id)
    for _,syndrome in ipairs(unit.syndromes.active) do
        if syndrome.type == syn_id then return true end
    end
    return false
end

local function eraseSyndrome(target,syn_id)
    for i=#target.syndromes.active-1,0,-1 do
        if target.syndromes.active[i].type==syn_id then target.syndromes.active:erase(i) end
    end
end
 
local function assignSyndrome(target,syn_id) --taken straight from here, but edited so I can understand it better: https://gist.github.com/warmist/4061959/. Also implemented expwnent's changes for compatibility with syndromeTrigger.
    if target==nil then
        return nil
    end
    if alreadyHasSyndrome(target,syn_id) then
        local syndrome
        for k,v in ipairs(target.syndromes.active) do
            if v.type == syn_id then syndrome = v end
        end
        if not syndrome then return nil end
        syndrome.ticks=1
        return true
    end
    local newSyndrome=df.unit_syndrome:new()
    local target_syndrome=df.syndrome.find(syn_id)
    newSyndrome.type=target_syndrome.id
    newSyndrome.year=df.global.cur_year
    newSyndrome.year_time=df.global.cur_year_tick
    newSyndrome.ticks=0
    newSyndrome.unk1=0
    --newSyndrome.flags=0
    for k,v in ipairs(target_syndrome.ce) do
        local sympt=df.unit_syndrome.T_symptoms:new()
        sympt.unk1=0
        sympt.unk2=0
        sympt.ticks=0
        sympt.flags=2
        newSyndrome.symptoms:insert("#",sympt)
    end
    target.syndromes.active:insert("#",newSyndrome)
    if itemsyndromedebug then
        print("Assigned syndrome #" ..syn_id.." to unit.")
    end
    return true
end
 
local function creatureIsAffected(unit,syndromeInfo)
    if syndromeInfo.indiscriminate then
        if itemsyndromedebug then
            print("Creature is affected, checking if item is in valid position...")
        end
        return true 
    end
	local syndrome=syndromeInfo.syndrome
    local affected = false
    local unitraws = df.creature_raw.find(unit.race)
    local casteraws = unitraws.caste[unit.caste]
    local unitracename = unitraws.creature_id
    local castename = casteraws.caste_id
    local unitclasses = casteraws.creature_class
    for _,unitclass in ipairs(unitclasses) do
        for _,syndromeclass in ipairs(syndrome.syn_affected_class) do
            if unitclass.value==syndromeclass.value then affected = true end
        end
    end
    for caste,creature in ipairs(syndrome.syn_affected_creature) do
        local affected_creature = creature.value
        local affected_caste = syndrome.syn_affected_caste[caste].value
        if affected_creature == unitracename and affected_caste == castename then affected = true end
    end
    for _,unitclass in ipairs(unitclasses) do
        for _,syndromeclass in ipairs(syndrome.syn_immune_class) do
            if unitclass.value==syndromeclass.value then affected = false end
        end
    end
    for caste,creature in ipairs(syndrome.syn_immune_creature) do
        local immune_creature = creature.value
        local immune_caste = syndrome.syn_immune_caste[caste].value
        if immune_creature == unitracename and immune_caste == castename then affected = false end
    end
    if itemsyndromedebug then
        if not affected then print("Creature is not affected. Cancelling.") else print("Creature is affected, checking if item is in valid position...") end
    end
    return affected
end
local function itemIsInValidPosition(item_inv, syndromeInfo)
    if not item_inv then error("no item_inv! this shouldn't happen") return false end
	local modes=unit_inventory_item.mode
    local isInValidPosition=not ((item_inv.mode == modes.Hauled and not syndromeInfo.AffectsHauler) or (item_inv.mode == modes.StuckIn and not syndromeInfo.AffectsStuckins) or (item_inv.mode ~= modes.Worn and syndromeInfo.IsArmorOnly) or (item_inv.mode ~= modes.Weapon and syndromeInfo.IsWieldedOnly) or (item_inv.mode ~= modes.StuckIn and syndromeInfo.OnlyAffectsStuckins))
    if itemsyndromedebug then print(isInValidPosition and 'Item is in correct position.' or 'Item is not in correct position.') end
    return isInValidPosition
end
 
local function rememberInventory(unit)
    local invCopy = {}
    for inv_id,item_inv in ipairs(unit.inventory) do
        invCopy[inv_id+1] = {}
        local itemToWorkOn = invCopy[inv_id+1]
        itemToWorkOn.item = item_inv.item
        itemToWorkOn.mode = item_inv.mode
        itemToWorkOn.body_part_id = item_inv.body_part_id
    end
    return invCopy
end
 
local function moveAllToInventory(unit,invTable)
    for _,item_inv in ipairs(invTable) do
        dfhack.items.moveToInventory(item_inv.item,unit,item_inv.mode,item_inv.body_part_id)
    end
end
 
local function addOrRemoveSyndromeDepending(unit,old_equip,new_equip,syndromeInfo)
	local item_inv=new_equip or old_equip
    if syndrome_info.onUnequip then
        if itemsyndromedebug then print('Syndrome is applied on unequip.') end
        if creatureIsAffected(unit,syndrome) and itemIsInValidPosition(item_inv,syndromeInfo) then
            if not new_equip then
                assignSyndrome(unit,syndrome.id)
            else
                eraseSyndrome(unit,syndrome.id)
            end
        end    
    else
        if itemsyndromedebug then print('Syndrome is applied on equip.') end
        if creatureIsAffected(unit,syndrome) and itemIsInValidPosition(item_inv,syndromeInfo) then
            if new_equip then
                assignSyndrome(unit,syndrome.id)
            else
                eraseSyndrome(unit,syndrome.id)
            end
        end
    end
end
 
eventful=require('plugins.eventful')
 
eventful.enableEvent(eventful.eventType.INVENTORY_CHANGE,5)
 
eventful.onInventoryChange.itemsyndrome=function(unit_id,item_id,old_equip,new_equip)
    local item = df.item.find(item_id)
    if not item then return false end
    local unit = df.unit.find(unit_id)
    if unit.flags1.dead then return false end
    if itemsyndromedebug then print("Checking unit #" .. unit_id) end
    local transformation = false
    if itemsyndromedebug then print("checking item #" .. item_id .." on unit #" .. unit_id) end
    local itemMaterial=itemSyndromeMats.matLookup[item:getMaterialIndex()]
    if itemMaterial then
        for k,syndromeInfo in ipairs(itemMaterial.syndrome) do
            if itemsyndromedebug then print("item has a syndrome, checking if syndrome is valid for application...") end
            if syndromeInfo.transformation then
                unitInventory = rememberInventory(unit)
                transformation = true
            end
            addOrRemoveSyndromeDepending(unit,old_equip,new_equip,syndromeInfo)
        end
    end
    local itemSyndromes = item:getSubtype()~=-1 and itemSyndromeMats[item.subtype.name] or false
    if itemSyndromes then
        if itemsyndromedebug then print("Item itself has a syndrome, checking if item is in correct position and creature is affected") end
        for k,syndromeInfo in ipairs(itemSyndromes) do
            if syndromeInfo.transformation then
                unitInventory = rememberInventory(unit)
                transformation = true
            end
            addOrRemoveSyndromeDepending(unit,old_equip,new_equip,syndromeInfo)
        end
    end
    if itemsyndromecontaminants and item.contaminants then
        if itemsyndromedebug then print("Item has contaminants. Checking for syndromes...") end
        for _,contaminant in ipairs(item.contaminants) do
            local contaminantMaterial=itemSyndromeMats.matLookup[contaminant:getMaterialIndex()]
            if contaminantMaterial then
                for k,syndromeInfo in ipairs(contaminantMaterial.syndromes) do
                    if itemsyndromedebug then print("Checking syndrome #" .. k .. "on contaminant #" .. _ .. " on item #" .. item_id .. " on unit #" .. unit_id ..".") end
                    if syndromeInfo.transformation then
                        unitInventory = rememberInventory(unit)
                        transformation= true
                    end
                    addOrRemoveSyndromeDepending(unit,old_equip,new_equip,syndromeInfo)
                end
            end
        end
    end
    if transformation and transformationReEquip then dfhack.timeout(2,"ticks",function() moveAllToInventory(unit,unitInventory) end) end
end
 
dfhack.onStateChange.itemsyndrome=function(code)
    if code==SC_WORLD_LOADED then
        itemSyndromeMats = findItemSyndromeInorganics()
    elseif code==SC_WORLD_UNLOADED then
		itemSyndromeMat = nil
	end
end
 
if disable then
    eventful.onInventoryChange.itemsyndrome=nil
    print("Disabled itemsyndrome.")
    disable = false
else
    print("Enabled itemsyndrome.")
end
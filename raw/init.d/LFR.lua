local stateEvents={}

stateEvents[SC_MAP_LOADED]=function() 
    pcall(function() dfhack.run_command('script',SAVE_PATH..'/raw/LFR_onload.txt') end) 
end

function onStateChange(op)
    local stateChangeFunc=stateEvents[op]
    if stateChangeFunc then stateChangeFunc() end
end

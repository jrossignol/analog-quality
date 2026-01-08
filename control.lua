-- Load script modules
require("scripts.inventory")
require("scripts.technology")

---Init script, adds initial qualities to unlocked qualities. This is mainly for existing
---games adding the mod.
script.on_init(function()
    for _, force in pairs(game.forces) do
        if (#force.players > 0) then
            init_quality(force)
        end
    end
end)

---Event handling for player creation, ensures the player's force has the initial tech.
---This is the main way we initialize for new game creation.
---@param event EventData | { player_index: number } The on_player_created event structure.
script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if (player ~= nil) then
        local force = game.forces[player.force_index]
        init_quality(force)
        init_player(player)
    end
end)

---Event handler for new game/scenario - we need to go and do some clean up of the broken ship parts.
script.on_event(defines.events.on_game_created_from_scenario, function(_)
    -- Within here we are going to define a very temporary on tick function, because our containers
    -- aren't ready yet. This should only run for one tick, but just in case we will kill it if it
    -- goes too far
    script.on_event(defines.events.on_tick, function(e)
        local done = cleanup_spaceship_items()

        if (e.tick > 30 or done) then
            if (not done) then
                error("Analog Quality: Couldn't do cleanup of spaceship items!")
            end
            script.on_event(defines.events.on_tick, nil)
        end
    end)
end)

-- Converted anything that is mined (including rocks) with the correct quality.
script.on_event(defines.events.on_player_mined_entity, function(e)
    ---@type LuaForce
    local force = game.get_player(e.player_index).force
    convert_quality(e.buffer, "poor-0", true, force, 1.0)
end)

-- Quality correction - for robots.
script.on_event(defines.events.on_robot_mined_entity, function(e)
    ---@type LuaForce
    local force = e.robot.force
    convert_quality(e.buffer, "poor-0", true, force, 1.0)
end)

script.on_event(defines.events.on_player_mined_tile, function(e)
    ---@type LuaPlayer
    local player = game.get_player(e.player_index)

    ---@type LuaForce
    local force = player.force

    -- We have to scan the whole inventory anyway... so just do a full conversion.
    -- But keep the quality chance low to prevent this from being a slot machine.
    convert_quality(player.get_main_inventory(), "poor-0", true, force, 0.1)
end)

script.on_event(defines.events.on_robot_mined_tile, function(e)
    ---@type LuaForce
    local force = e.robot.force

    -- We have to scan the whole inventory anyway... so just do a full conversion.
    -- But keep the quality chance low to prevent this from being a slot machine.
    convert_quality(e.robot.get_main_inventory(), "poor-0", true, force, 0.1)
end)

-- Trigger script from dummy items spoiling - we use this to correct the quality of items
-- like the rocket part (that are problematic if we use multiple qualities).
---@param e EventData.on_script_trigger_effect The script trigger event.
script.on_event(defines.events.on_script_trigger_effect, function(e)
    on_script_trigger_effect_handler(e)
end)

---Event handler for player surface changes - triggers off-world research on first visit.
script.on_event(defines.events.on_player_changed_surface, function(event)
    on_player_changed_surface_handler(event)
end)

---Event handler for research completion - triggers offworld science research.
script.on_event(defines.events.on_research_finished, function(event)
    on_research_finished_handler(event)
end)
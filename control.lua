
---Unlocks the initial quality levels.
---@param force LuaForce The force to add tech to.
function init_quality(force)
    force.unlock_quality("poor-0")
    force.unlock_quality("normal-0")
end

---Converts items in the given inventory from normal to the given quality_id
---@param inventory? LuaInventory The inventory to work against.
---@param quality_id string The quality to replace with.
---@param check_for_normal_quality boolean Whether to check for normal quality in the old items.
---@param force? LuaForce The force to check quality unlocks when rolling (initial quality_id is not checked)
---@param quality_chance? number Whether to apply quality logic to the conversion.
function convert_quality(inventory, quality_id, check_for_normal_quality, force, quality_chance)
    -- Ignore invalid or empty inventories
    if (not inventory or #inventory == 0) then
        return
    end

    -- For performance, we do a quick scan to see if we need to do conversions and exit early if we don't.
    for i = 1, #inventory do
        local old = inventory[i]
        if (old.valid_for_read and (not check_for_normal_quality or old.quality.name == "normal")) then
            break
        elseif (i == #inventory) then
            return
        end
    end

    -- At least one normal item detected - need to convert
    ---@type ItemStackDefinition[]
    local new_items = {}
    for i = 1, #inventory do
        local old = inventory[i]
        if (old.valid_for_read) then
            --- Set the new quality
            local current_quality_name = old.quality.name
            if (current_quality_name == "normal" or not check_for_normal_quality) then
                current_quality_name = quality_id

                -- Roll for new quality if there's a non-zero quality chance
                if (force and quality_chance ~= nil and quality_chance > 0) then
                    local current_quality = prototypes.quality[current_quality_name]
                    while (force.is_quality_unlocked(current_quality.next) and
                        math.random() < current_quality.next_probability * quality_chance
                    ) do
                        current_quality = current_quality.next
                    end
                    current_quality_name = current_quality.name
                end
            end

            -- Create and insert the new version of the item into the list
            ---@type ItemStackDefinition
            local new = {
                name = old.name,
                count = old.count,
                quality = current_quality_name,
                health = old.health,
                durability = old.is_tool and old.durability or nil,
                ammo = old.is_ammo and old.ammo or nil,
                tags = old.is_item_with_tags and old.tags or nil,
                custom_description = old.is_item_with_tags and old.custom_description or nil,
                spoil_percent = old.spoil_percent,
            }
            table.insert(new_items, new)
        end
    end

    -- Reconfigure inventory
    inventory.clear()
    for _, item in ipairs(new_items) do
        inventory.insert(item)
    end
end

---Initializes a player (updates to the inventory).
---@param player LuaPlayer The player to initialize.
function init_player(player)
    -- Get the player's character
    local character = player.character or player.cutscene_character
    if (not character) then
        error("Couldn't get player character for player '" .. player.name .. "'.")
        return
    end

    -- Go through the initial inventory and update the qualities to the "new normal"
    local inventory = character.get_main_inventory()
    convert_quality(inventory, "normal-0", true)
end

---Init script, adds initial qualities to unlocked qualities.  This is mainly for existing
---games adding the mod.
script.on_init(function()
    for _, force in pairs(game.forces) do
        if (#force.players > 0) then
            init_quality(force)
        end
    end
    
    -- Configure all existing rocket silos
    --configure_rocket_silos()
end)

---Load mod state on game load
---Re-applies rocket silo configurations to ensure consistency
script.on_configuration_changed(function()
    --configure_rocket_silos()
end)

---Event handling for player creation, ensures the player's force has the initial tech.
---This is the main way we initialize for new game creation.
---@param event EventData | { player_index: number } The on_player_created event structure.
function on_player_created(event)
    local player = game.get_player(event.player_index)
    if (player ~= nil) then
        local force = game.forces[player.force_index]
        init_quality(force)
        init_player(player)
    end
end
script.on_event(defines.events.on_player_created, on_player_created)

---Event handler for new game/scenario - we need to go and do some clean up of the broken ship parts.
script.on_event(defines.events.on_game_created_from_scenario, function(_)
    -- Within here we are going to define a very temporary on tick function, because our containers
    -- aren't ready yet.  This should only run for one tick, but just in case we will kill it if it
    -- goes too far
    script.on_event(defines.events.on_tick, function(e)
        local surface = game.surfaces[1]
        local done = false
        for _, entity in ipairs(surface.find_entities_filtered({type="container"})) do
            local inventory = entity.get_output_inventory()
            if (inventory) then
                -- For the crash site, fill the inventory with goodies
                if (entity.name == "crash-site-spaceship") then
                    inventory.clear()

                    -- Give the player some electric poles ...
                    inventory.insert({
                        name = "small-electric-pole",
                        count = 3,
                        quality = "normal-0",
                    })

                    -- ... some assemblers ...
                    inventory.insert({
                        name = "assembling-machine-1",
                        count = 3,
                        quality = "normal-0",
                    })

                    -- ... and something to power it
                    inventory.insert({
                        name = "solar-panel",
                        count = 3,
                        quality = "normal-0",
                    })

                -- For everything else, convert the quality
                else
                    convert_quality(inventory, "poor-0", true)
                end
            end

            done = true
        end

        if (e.tick > 30 or done) then
            if (not done) then
                error("Analog Quality: Couldn't do cleanup of spaceship items!")
            end
            script.on_event(defines.events.on_tick, nil)
        end
    end)
end)

script.on_event(defines.events.on_player_mined_item, function(e)
    log("[AQ] Player mined item: " .. serpent.line(e))
    -- For player mining events we need to do a rapid replace of what was mined if it's of base quality
    if (e.item_stack.quality == "normal") then
        --log("[AQ]   inventory: " .. serpent.block(game.players[e.player_index].get_main_inventory().get_contents()))

        local player = game.get_player(e.player_index)
    end
end)

script.on_event(defines.events.on_player_mined_entity, function(e)
    ---@type LuaForce
    local force = game.get_player(e.player_index).force
    convert_quality(e.buffer, "poor-0", true, force, 1.0)
end)
script.on_event(defines.events.on_robot_mined_entity, function(e)
    ---@type LuaForce
    local force = e.robot.force
    convert_quality(e.buffer, "poor-0", true, force, 1.0)
end)

script.on_event(defines.events.on_picked_up_item, function(e)
    log("[AQ] Player picked up item: " .. serpent.line(e))
end)

---Configure rocket silos when they are first built
---@param event EventData.on_built_entity | EventData.on_robot_built_entity
local function on_rocket_silo_built(event)
    local entity = event.entity
    if entity and entity.valid and entity.name == "rocket-silo" then
        ---@type LuaAssemblingMachineControlBehavior
        local control_behavior = entity.get_control_behavior()
        if control_behavior then
            control_behavior.circuit_set_recipe = true
        end
    end
end

script.on_event(defines.events.on_built_entity, on_rocket_silo_built)
script.on_event(defines.events.on_robot_built_entity, on_rocket_silo_built)

script.on_event(defines.events.on_script_trigger_effect, function(e)
    if (e.effect_id == "aq-spoiled-quality" and e.cause_entity) then
        local inv = e.cause_entity.get_output_inventory()
        convert_quality(inv, "normal-0", false)

        -- Give bonus progress for high quality
        -- TODO: We lie and don't overflow the bonus amount because it's hard...
        --       ...but we also trigger this on the bonus crafts, so it's kind of fair.
        ---@type LuaQualityPrototype
        local quality = prototypes.quality[e.quality]
        local bonus_productivity = (quality.default_multiplier - 1) / 4
        if (bonus_productivity > 0) then
            e.cause_entity.bonus_progress = math.min(e.cause_entity.bonus_progress + bonus_productivity, 1)
        end
    end
end)
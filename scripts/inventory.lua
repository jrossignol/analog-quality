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
            if (old.can_set_stack(new)) then
                old.set_stack(new)
            end
        end
    end
end

---Handles script trigger effects for quality conversion.
---@param event EventData.on_script_trigger_effect The script trigger event.
function on_script_trigger_effect_handler(event)
    if (event.effect_id == "aq-spoiled-quality") then
        -- Get the entity to work against
        local entity = event.cause_entity
        if (entity and entity.type ~= "assmebling-machine") then
            log("[AQ]     foo = " .. entity.type .. string.sub(entity.type, 1, 6))
            -- Inserters
            if (entity.type == "inserter") then
                entity = entity.pickup_target
            -- Loaders
            elseif (string.sub(entity.type, 1, 6) == "loader") then
                -- The loader most likely picked up both items and we have to fix the quality here.
                for i = 1, entity.get_max_transport_line_index() do
                    local line = entity.get_transport_line(i)
                    local contents = line.get_contents()
                    for pos, item in ipairs(contents) do
                        if (item.quality ~= "normal-0") then
                            line.remove_item({
                                name = item.name,
                                count = item.count,
                                quality = item.quality,
                            })
                            if (line.can_insert_at_back()) then
                            line.insert_at_back({
                                name = item.name,
                                count = item.count,
                                quality = "normal-0"
                            })
                            end
                        end
                    end
                end

                -- We will still do a check on the linked assembler.
                entity = entity.loader_container
            end
        end
        if (entity == nil) then return end

        local inv = entity.get_output_inventory()
        convert_quality(inv, "normal-0", false)

        if (entity.type == "gui-assembling-machine") then
            -- Give bonus progress for high quality
            -- TODO: We lie and don't overflow the bonus amount because it's hard...
            --       ...but we also trigger this on the bonus crafts, so it's kind of fair.
            ---@type LuaQualityPrototype
            local quality = prototypes.quality[event.quality]
            local bonus_productivity = (quality.default_multiplier - 1) / 4
            if (bonus_productivity > 0) then
                entity.bonus_progress = math.min(entity.bonus_progress + bonus_productivity, 1)
            end
        end
    end
end

---Handles cleanup of initial spaceship items and inventory conversion.
---@return boolean done Whether the cleanup was performed. 
function cleanup_spaceship_items()
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

    return done
end

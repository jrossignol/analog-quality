---Maps player index to the last tick that an inventory check was done. Used to prevent duplicate checks in handlers.
---@type integer[]
inventory_check = {}

---Caches the item used to build previously so we can substitute it if we run out.
---@type { name: string, quality: LuaQualityPrototype, tick: integer }[]
pre_build_item = {}

---Sets up the quality progression map in storage for cursor stack logic.
function setup_quality_map()
    ---@type table<string, { next: string?, prev: string? }>
    storage.quality = {}
    for name, quality in pairs(prototypes.quality) do
        -- Store the next quality information
        local next = quality.next and quality.next.name
        storage.quality[name] = storage.quality[name] or {}
        storage.quality[name].next = next

        -- Store the previous quality information
        if (next) then
            storage.quality[next] = storage.quality[next] or {}
            storage.quality[next].prev = name
        end
    end
end

---@param player LuaPlayer The player to search for items for.
---@param item string The name of the item to search for.
---@param quality LuaQualityPrototype The quality to start searching from
---@return LuaItemStack?, integer? foundStack The stack with the items to use (and its index).
function get_inventory_best_match(player, item, quality)
    ---@type LuaInventory
    local inventory = player.get_main_inventory()
    if not inventory then return end

    -- First we do a scan of the inventory for instances of the item and cache them
    ---@type table<string, { [1]: LuaItemStack, [2]: integer }>
    local stacks = {}
    for i = 1, #inventory do
        -- Store the stack if it's the first match of this quality
        local stack = inventory[i]
        if (stack.valid and stack.valid_for_read and stack.name == item) then
            local stack_quality = stack.quality.name
            stacks[stack_quality] = stacks[stack_quality] or { stack, i }
        end
    end

    ---@type "closest" | "worse" | "better"
    local stack_logic = player.mod_settings["aq-cursor-stack-logic"].value

    -- Set up next and previous pointers
    local next = stack_logic ~= "worse" and quality.next or nil
    local prev_name = stack_logic ~= "better" and storage.quality[quality.name].prev or nil

    -- Do search for closest matching quality
    local foundStack = {}
    while (next or prev_name) do
        -- Check next quality
        if (next) then
            if (stacks[next.name]) then
                foundStack = stacks[next.name]
                break
            end
            next = next.next
        end

        -- Check previous quality
        if (prev_name) then
            if (stacks[prev_name]) then
                foundStack = stacks[prev_name]
                break
            end
            prev_name = storage.quality[prev_name].prev
        end
    end

    inventory_check[player.index] = game.tick
    return foundStack[1], foundStack[2]
end

---Handles pre-build event to store the item being built with.
---@param event EventData.on_pre_build
function on_pre_build_handler(event)
    ---@type LuaPlayer
    local player = game.get_player(event.player_index)

    ---@type LuaItemStack
    local stack = player.cursor_stack

    -- Store what the player is about to build with so we can do inventory replacement if they run out
    if (stack and stack.valid and stack.valid_for_read) then
        pre_build_item[player.index] = {
            name = stack.name,
            quality = stack.quality,
            tick = game.tick
        }
    end
end

---Handles cursor stack changes to swap items based on quality preference.
---@param event EventData.on_player_cursor_stack_changed
function on_player_cursor_stack_changed_handler(event)
    -- If a previous check already occurred this tick, then don't check again
    if (inventory_check[event.player_index] == game.tick) then
        return
    end

    ---@type LuaPlayer
    local player = game.get_player(event.player_index)

    -- Short-circuit if cursor replacement is turned off
    if (player.mod_settings["aq-cursor-stack-logic"].value == "none") then
        return
    end

    ---@type LuaItemStack
    local stack = player.cursor_stack

    ---@type ItemIDAndQualityIDPair
    local ghost = player.cursor_ghost

    -- Check if we have an non-item stack
    if (stack.valid and not stack.valid_for_read) then
        ---@type string
        local item
        ---@type LuaQualityPrototype
        local quality

        -- If we have a ghost cursor then the player tried to pick an item that isn't available
        if (ghost) then
            ---@type LuaItemPrototype
            local itemProto = player.cursor_ghost.name
            item = itemProto.name
            ---@type LuaQualityPrototype
            quality = player.cursor_ghost.quality
        -- We previously stored a build event
        elseif (pre_build_item[player.index]) then
            local build = pre_build_item[player.index]
            pre_build_item[player.index] = nil

            if (build.tick == game.tick) then
                item = build.name
                quality = build.quality
            else
                return
            end
        -- No valid checks to be done
        else
            return
        end

        -- See if the stack can be swapped out
        local newstack, index = get_inventory_best_match(player, item, quality)
        if (newstack) then
            stack.swap_stack(newstack)
            player.hand_location = {
                inventory = defines.inventory.character_main,
                slot = index,
            }
        end
    end
end

---Handles pipette event to swap items based on quality preference.
---@param event EventData.on_player_pipette
function on_player_pipette_handler(event)
    -- If a previous check already occurred this tick, then don't check again
    if (inventory_check[event.player_index] == game.tick) then
        return
    end

    ---@type LuaPlayer
    local player = game.get_player(event.player_index)

    -- Short-circuit if cursor replacement is turned off
    if (player.mod_settings["aq-cursor-stack-logic"].value == "none") then
        return
    end

    ---@type LuaItemStack
    local stack = player.cursor_stack

    --- Player tried to pipette something but failed
    if (stack.valid and not stack.valid_for_read) then
        ---@type LuaItemPrototype
        local item = event.item

        local newstack, index = get_inventory_best_match(player, item.name, event.quality)
        if (newstack) then
            stack.swap_stack(newstack)
            player.hand_location = {
                inventory = defines.inventory.character_main,
                slot = index,
            }
        end
    end
end

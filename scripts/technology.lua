---Unlocks the initial quality levels.
---@param force LuaForce The force to add tech to.
function init_quality(force)
    force.unlock_quality("poor-0")
    force.unlock_quality("normal-0")
end

---Triggers the off-world research when a player first reaches a non-Nauvis planet.
---@param event EventData.on_player_changed_surface The on_player_changed_surface event.
function on_player_changed_surface_handler(event)
    local player = game.get_player(event.player_index)
    if (not player or not player.character) then
        return
    end

    local surface = player.surface
    -- Check if player is on a non-Nauvis planet
    if (surface.index ~= 1 and surface.planet ~= nil) then
        -- Initialize storage if needed
        if (not storage.first_time_offworld_triggered) then
            storage.first_time_offworld_triggered = {}
        end

        local force = player.force
        local force_name = force.name

        -- Check if this force has already triggered the off-world event
        if (not storage.first_time_offworld_triggered[force_name]) then
            -- Mark as triggered
            storage.first_time_offworld_triggered[force_name] = true

            -- Trigger the scripted research trigger event
            force.script_trigger_research("aq-rare-plus-quality")
        end
    end
end

---Helper function to get space science packs in a technology's unit.
---@param tech LuaTechnology The technology to check.
---@return table packs The set of space science pack names found in this tech.
local function get_space_science_packs(tech)
    if (not tech.research_unit_ingredients) then
        return {}
    end

    local packs_found = {}
    local space_pack_names = {
        "metallurgic-science-pack",
        "agricultural-science-pack",
        "electromagnetic-science-pack",
    }

    for _, ingredient in ipairs(tech.research_unit_ingredients) do
        for _, pack_name in ipairs(space_pack_names) do
            if (ingredient.name == pack_name) then
                packs_found[pack_name] = true
            end
        end
    end

    return packs_found
end

---Triggers offworld science research based on space science pack usage.
---@param event EventData.on_research_finished The research finished event.
function on_research_finished_handler(event)
    local tech = event.research
    local force = tech.force

    -- Initialize storage if needed
    if (not storage.offworld_science_packs_triggered) then
        storage.offworld_science_packs_triggered = {}
    end

    local force_name = force.name
    if (not storage.offworld_science_packs_triggered[force_name]) then
        storage.offworld_science_packs_triggered[force_name] = {}
    end

    local triggered_packs = storage.offworld_science_packs_triggered[force_name]

    -- Get the current count of triggered packs
    local pack_count = 0
    for _ in pairs(triggered_packs) do
        pack_count = pack_count + 1
    end
    if pack_count == 3 then return end

    -- Add any new packs found in this tech to the triggered set
    local packs_in_tech = get_space_science_packs(tech)
    for pack_name, _ in pairs(packs_in_tech) do
        if (not triggered_packs[pack_name]) then
            triggered_packs[pack_name] = true
            pack_count = pack_count + 1

            -- Trigger the research based on unique pack count
            if (pack_count == 1) then
                force.script_trigger_research("epic-quality")
            elseif (pack_count == 2) then
                force.script_trigger_research("aq-epic-plus-quality")
            elseif (pack_count == 3) then
                force.script_trigger_research("legendary-quality")
            end
        end
    end
end

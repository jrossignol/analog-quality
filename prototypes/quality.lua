-- Quality tier generation and registration
-- This file reads base quality levels from Factorio and generates intermediate tiers
-- All qualities are registered here with proper icons and colors

---Normalizes Factorio colors into a consistent format (rgba 0-1).
---@param color Color Input color in any Factorio format
---@return Color Normalized color object
local function normalise_color(color)
    local r = color.r or color[1] or 0.0
    local g = color.g or color[2] or 0.0
    local b = color.b or color[3] or 0.0
    local a = color.a or color[4]

    -- Determine if we are in 0-255 or 0-1 range
    local m = (r > 1.0 or g > 1.0 or b > 1.0 or (a and a > 1.0)) and 1/255 or 1.0

    return {r = r * m, g = g * m, b = b * m, a = (a or (1/m)) * m}
end

---Color interpolation function using Factorio Color struct
---@param color1 Color Source color (pre-normalised)
---@param color2 Color Target color (pre-normalised)
---@param t number Interpolation parameter [0, 1]
---@return Color lerped Interpolated color
local function lerp_color(color1, color2, t)
    return {
        r = color1.r * (1 - t) + color2.r * t,
        g = color1.g * (1 - t) + color2.g * t,
        b = color1.b * (1 - t) + color2.b * t,
        a = color1.a * (1 - t) + color2.a * t,
    }
end

---Number interpolation function
---@param a number Start value
---@param b number End value
---@param t number Interpolation parameter [0, 1]
---@return number lerped Interpolated integer value
local function lerp_number(a, b, t)
    return a * (1 - t) + b * t
end

---Sets up the multipliers on the quality prototype for the given effective level.
---@param quality data.QualityPrototype The quality to set levels for.
---@param effective_level number The effective level (float, unlike real level which is integer)
local function set_effective_level(quality, effective_level)
    quality.level = math.max(math.floor(effective_level), 0)
    quality.default_multiplier = math.max(1 + 0.3 * effective_level, 0.01)
    quality.tool_durability_multiplier = math.max(1 + effective_level, 0.01)
    quality.accumulator_capacity_multiplier = math.max(1 + effective_level, 0.01)
    quality.flying_robot_max_energy_multiplier  = math.max(1 + effective_level, 0.01)
    quality.range_multiplier = math.min(math.max(1 + 0.1 * effective_level, 1), 3)
    quality.asteroid_collector_collection_radius_bonus = math.max(effective_level, 0)
    quality.electric_pole_wire_reach_bonus  = math.max(2 * effective_level, 0)
    quality.electric_pole_supply_area_distance_bonus  = math.max(effective_level, 0)
    quality.beacon_supply_area_distance_bonus = math.min(math.max(effective_level, 0), 64)
    quality.mining_drill_mining_radius_bonus  = math.max(effective_level, 0)

    -- These don't have documented defaults, but can work backwards to get these formulas
    quality.beacon_power_usage_multiplier = math.max(1 - effective_level/6, 3/24)
    quality.mining_drill_resource_drain_multiplier = math.min(math.max(1 - effective_level/6, 3/24), 1)
    quality.science_pack_drain_multiplier = math.min(math.max(1 - effective_level/100, 0.25), 1)
end

---Extract base qualities from data and generate intermediate tiers
local function generate_quality_tiers()
    ---Mapping of updated icons for quality tiers
    ---@type table<string, string>
    local icon_map = {
        normal        = "__analog-quality__/graphics/icons/quality-normal.png",
        uncommon      = "__analog-quality__/graphics/icons/quality-uncommon.png",
        rare          = "__analog-quality__/graphics/icons/quality-rare.png",
        epic          = "__analog-quality__/graphics/icons/quality-epic.png",
        legendary     = "__analog-quality__/graphics/icons/quality-legendary.png",
        ["aq-mythic"] = "__analog-quality__/graphics/icons/quality-mythic.png",
        ["aq-forgot"] = "__analog-quality__/graphics/icons/quality-mythic.png",
    }

    ---Mapping of icon color tints for quality tiers
    ---@type table<string, Color>
    local color_map = {
        poor          = normalise_color({r=282, g=-60, b=-84}), -- Values overtuned to account for the fact that we lerp 50% of the way to normal
        normal        = normalise_color({r=188, g=188, b=188}),
        uncommon      = normalise_color({r=62,  g=236, b=87}),
        rare          = normalise_color({r=36,  g=149, b=255}),
        epic          = normalise_color({r=196, g=0,   b=255}),
        legendary     = normalise_color({r=255, g=149, b=0}),
        ["aq-mythic"] = normalise_color({r=69,  g=255, b=129}),
        ["aq-forgot"] = normalise_color({r=-69, g=255, b=381}), -- Values overtuned to account for the fact that we only lerp 50% of the way
    }

    ---Sparse map of where the base quality changes (stores the next quality, not current)
    ---@type table<integer, string>
    local next_quality = {
        [0]   = "normal",
        [12]  = "uncommon",
        [36]  = "rare",
        [60]  = "epic",
        [84]  = "legendary",
        [108] = "aq-mythic",
        [132] = "aq-forgot",
    }

    ---Sparse map indicating where the base qualities sit in the list (everything else is added)
    ---@type table<integer, string>
    local quality_positions = {
        [36]  = "uncommon",
        [60]  = "rare",
        [84]  = "epic",
        [108] = "legendary",
    }

    local mythic_quality = table.deepcopy(data.raw.quality.legendary)
    mythic_quality.name = "aq-mythic"
    mythic_quality.color = {r=0, g=160, b=160}
    mythic_quality.level = 7
    mythic_quality.order = "f"
    local forgot_quality = table.deepcopy(data.raw.quality.legendary)
    forgot_quality.name = "aq-forgot"
    forgot_quality.color = {r=0, g=148, b=148}
    forgot_quality.level = 9
    forgot_quality.order = "g"

    ---Fake quality prototypes for the mythic and forgotten tiers.
    ---(these are used to copy from and aren't actually loaded into Factorio)
    ---@type table<string, data.QualityPrototype>
    local quality_prototypes = {
        ["aq-mythic"] = mythic_quality,
        ["aq-forgot"] = forgot_quality,
    }

    ---Next chance table - we use a cosine wave to slightly modify the next_probability in a way that
    ---creates natural groupings in the distribution of quality items.
    ---@type table<integer, number>
    local next_chance_table = {}
    local base_chance = math.exp(math.log(0.1) / 24)
    for i = 0, 11 do
        next_chance_table[i] = base_chance * (1 - (math.cos(i * math.pi / 6) + 1) / 4)
    end

    -- Get current and next base qualities as copies (because we are going to change the real one before we're done with it)
    local normal = data.raw.quality.normal
    local next_base_quality = table.deepcopy(normal)
    local current_base_quality = next_base_quality

    -- We're dynamically building the "poor" base quality (but this won't be stored directly)
    next_base_quality.name = "poor"
    next_base_quality.level = -1 -- Technically invalid, will ensure that values >= 0 are always used
    next_base_quality.color = {235, 64, 52}

    -- Set up variables used for lerping - index is below zero so we start with poor at 50%
    local low = -999
    local high = -12

    -- Determine color information
    local next_icon_color = color_map[next_base_quality.name]
    local current_icon_color = next_icon_color

    -- Generate 145 quality levels (12 poor, 12 normal, 24 uncommon, 24 rare, 24 epic, 24 legendary, 25 mythic).
    -- Indexing is zero-based to make the math make more sense.
    for i = 0, 144 do
        -- Check if we need to switch base quality
        if (next_quality[i]) then
            current_base_quality = next_base_quality

            -- Copy next base quality if not nil
            next_base_quality = data.raw["quality"][next_quality[i]]
            if (next_base_quality) then
                next_base_quality = table.deepcopy(next_base_quality)
            -- Otherwise use our table of fake prototypes
            else
                next_base_quality = quality_prototypes[next_quality[i]]
            end

            -- Switch low/high values
            low = high
            high = low + 24

                -- Determine color information
            current_icon_color = next_icon_color
            next_icon_color = color_map[next_base_quality.name] or normalise_color(next_base_quality.color)
        end

        -- Create the quality item - either one of the original qualities or a copy of current base
        local quality = quality_positions[i] and data.raw.quality[quality_positions[i]] or table.deepcopy(current_base_quality)

        -- Calculate the effective and real levels
        local t = (i - low) / (high - low)
        local effective_level = lerp_number(current_base_quality.level, next_base_quality.level, t)
        set_effective_level(quality, effective_level)

        -- Calculate the "closest" base quality
        local name = t >= 0.5 - 0.0001 and next_base_quality.name or current_base_quality.name

        -- Localised name of the quality - overriden for the first 12 levels to be "poor"
        quality.localised_name = {
            "analog-quality.quality",
            {
                "quality-name." .. (i < 12 and "poor" or i == 144 and "aq-mythic" or name)
            },
            string.format("%3d", (effective_level + 1) * 100)
        }
        local suffix = i < 12 and i or (i - low)

        -- Set next quality, naming changes only when the real qualities are used
        if (quality_positions[i+1]) then
            quality.next = quality_positions[i+1]
        elseif (next_quality[i+1]) then
            quality.next = next_base_quality.name .. "-0"
        elseif (i ~= 144) then
            quality.next = current_base_quality.name .. "-" .. (suffix + 1)
        end

        -- Generate icon with tint
        local icon_quality = data.raw.quality[name] or quality_prototypes[name]
        local base_icon = icon_quality.icons and icon_quality.icons[1] or icon_quality
        local icon_color = lerp_color(current_icon_color, next_icon_color, t)
        quality.icons = {
            {
                icon = icon_map[name] or base_icon.icon,
                icon_size = base_icon.icon_size,
                tint = icon_color,
                shift = base_icon.shift,
                scale = base_icon.scale,
            }
        }
        quality.icon = nil
        quality.icon_size = nil

        -- Override the normal quality color to something readable in both places (black background and off-white tooltips)
        quality.color = i < 12 and current_base_quality.color or name == "normal" and {116, 105, 88} or icon_quality.color

        -- Various settings
        quality.hidden = false
        quality.draw_sprite_by_default = true
        quality.order = (current_base_quality.order or current_base_quality.name) .. "-" .. string.format("%03d", i)
        quality.next_probability = next_chance_table[i % 12]

        -- Add to data if not already present
        if (not quality_positions[i]) then
            -- Set name
            quality.name = current_base_quality.name .. "-" .. suffix

            data:extend({quality})
        end

        log("[AQ] Generated quality: " .. quality.name .. " (level=" .. tostring(quality.level) .. ", next=" .. tostring(quality.next) .. ")")
    end

    -- The base quality is normal - but we can't easily change it (forcing the icon on causes UI bugs,
    -- including not having it where we need it).  So instead we will give it a weird name, and give
    -- maximum chance to upgrade from it.  There's also some script logic that prevents it being used.
    normal.localised_name = { "analog-quality.not-normal", { "quality-name.normal" } }
    set_effective_level(normal, 0)
    normal.next = "poor-0"
    normal.next_probability = 1
end

-- Generate all quality tiers
generate_quality_tiers()

log("[AQ] Generated and registered quality tiers")
-- Analog Quality Technology Framework
-- This file defines technologies for progressively unlocking quality tiers
-- Uses research triggers to unlock quality capabilities as the player progresses

---Helper function to add quality unlocks to a tech.
---@param quality_basename string Base quality name (e.g., "normal", "uncommon")
---@param tech data.TechnologyPrototype Technology prototype to add to.
---@param min number The first quality level in the range to be unlocked.
---@param max number The last quality level in the range to be unlocked.
local function add_qualities_to_tech(quality_basename, tech, min, max)
    -- Add quality effects
    for i = min, max do
        -- Generate the quality tier name
        local qualityID = quality_basename .. "-" .. i

        -- Add effect
        table.insert(tech.effects, {
            type = "unlock-quality",
            quality = data.raw.quality[qualityID] and qualityID or quality_basename,
        })
    end
end

---Helper function to create a quality tier unlock technology
---@param quality_basename string Base quality name (e.g., "normal", "uncommon")
---@param tech_basename string Technology base name.  Will have 'aq-' prepended to it.
---@param min number The first quality level in the range to be unlocked.
---@param max number The last quality level in the range to be unlocked.
---@param trigger? data.TechnologyTrigger Research trigger
---@param prerequisites? data.TechnologyID[] Technology prerequisites
---@param unit? data.TechnologyUnit Cost to research technology.
---@return data.TechnologyPrototype tech The technology prototype to be added.
local function create_quality_tech(quality_basename, tech_basename, min, max, trigger, prerequisites, unit)
    -- Generate the base tech data
    ---@type data.TechnologyPrototype
    local tech = {
        type = "technology",
        name = "aq-" .. tech_basename,
        effects = { },
        research_trigger = trigger,
        prerequisites = prerequisites,
        unit = unit,
    }

    -- Add the quality unlock effects
    add_qualities_to_tech(quality_basename, tech, min, max)

    -- Set icons from quality
    local qualityID = quality_basename .. "-" .. min
    local quality = data.raw.quality[qualityID] or data.raw.quality[quality_basename]
    tech.icons = quality.icons
    tech.icon = quality.icon
    tech.icon_size = quality.icon_size

    return tech
end

---Helper function to create a craft-item trigger
---@param item string Item name to craft
---@param count integer Number to craft
---@return data.CraftItemTechnologyTrigger Trigger definition
local function trigger_craft_item(item, count)
    return {
        type = "craft-item",
        item = item,
        count = count,
    }
end

---Removes any quality unlocks from the given technology.
---@param tech data.TechnologyPrototype
local function remove_quality_unlocks(tech)
    for i = #tech.effects, 1, -1 do
        if (tech.effects[i].type == "unlock-quality") then
            table.remove(tech.effects, i)
        end
    end
end

-- Create first unlock
data:extend({create_quality_tech(
    "poor",
    "poor-quality",
    1, 2,
    trigger_craft_item("iron-plate", 10),
    nil  -- No prerequisites
)})

-- Ensure that we have required techs
local required_techs = {
    "circuit-network",
    "automation-science-pack",
    "logistic-science-pack",
    "advanced-combinators",
    "advanced-circuit",
    "quality-module",
    "chemical-science-pack",
    "low-density-structure",
    "advanced-material-processing-2",
    "rocket-silo",
    "space-science-pack",
    "space-platform-thruster",
    "epic-quality",
    "legendary-quality",
    "planet-discovery-aquilo",
    "cryogenic-science-pack",
    "promethium-science-pack",
    "research-productivity",
}
for _, tech_name in ipairs(required_techs) do
    if (data.raw.technology[tech_name] == nil) then
        error("Analog Quality: Couldn't find required technology: " .. tech_name)
    end
end

-- Automation science pack tech unlocks three quality levels
local automation = data.raw.technology["automation-science-pack"]
add_qualities_to_tech("poor", automation, 3, 5)
table.insert(automation.prerequisites, "aq-poor-quality")

-- Modify the circuit network technology - it is now available earlier and requied to move to green science
local circuit_network = data.raw.technology["circuit-network"]
circuit_network.prerequisites = { "automation-science-pack" }
table.insert(data.raw.technology["logistic-science-pack"].prerequisites, "circuit-network")
if (circuit_network.unit) then
    circuit_network.unit.count = circuit_network.unit.count / 4
    for i, ingredient in ipairs(circuit_network.unit.ingredients) do
        if (ingredient[1] == "logistic-science-pack") then
            table.remove(circuit_network.unit.ingredients, i)
            break
        end
    end
end
add_qualities_to_tech("poor", circuit_network, 6, 9) -- It also unlocks more quality

-- Logistics science pack tech unlocks four quality levels
local logistics = data.raw.technology["logistic-science-pack"]
add_qualities_to_tech("poor", logistics, 10, 11)
add_qualities_to_tech("normal", logistics, 0, 1)

-- Advanced combinators are available in green tech and requried to move to blue
local advanced_combinators = data.raw.technology["advanced-combinators"]
advanced_combinators.prerequisites = { "advanced-circuit", "circuit-network" }
table.insert(data.raw.technology["chemical-science-pack"].prerequisites, "advanced-combinators")
if (advanced_combinators.unit) then
    advanced_combinators.unit.count = advanced_combinators.unit.count * 2
    for i, ingredient in ipairs(advanced_combinators.unit.ingredients) do
        if (ingredient[1] == "chemical-science-pack") then
            table.remove(advanced_combinators.unit.ingredients, i)
            break
        end
    end
end
add_qualities_to_tech("normal", advanced_combinators, 2, 6) -- It also unlocks more quality

-- Chemical science pack tech unlocks five quality levels
add_qualities_to_tech("normal", data.raw.technology["chemical-science-pack"], 7, 11)

-- Remove the unlocks from the quality module tech
remove_quality_unlocks(data.raw.technology["quality-module"])

-- Create a new uncommon-quality tech
data:extend({ create_quality_tech(
    "normal",
    "uncommon-quality",
    12, 23,
    nil,
    { "chemical-science-pack" },
    {
        count = 100,
        time = 30,
        ingredients = {
            { "automation-science-pack", 1 },
            { "logistic-science-pack", 1 },
            { "chemical-science-pack", 1 },
        }
    }
)})
table.insert(data.raw.technology["low-density-structure"].prerequisites, "aq-uncommon-quality")
table.insert(data.raw.technology["advanced-material-processing-2"].prerequisites, "aq-uncommon-quality")

-- Rocket silo unlocks the uncommon+ tiers
add_qualities_to_tech("uncommon", data.raw.technology["rocket-silo"], 0, 11)

-- Space science unlocks the rare tiers
add_qualities_to_tech("uncommon", data.raw.technology["space-science-pack"], 12, 23)

-- Create a new rare-plus quality tech
data:extend({ create_quality_tech(
    "rare",
    "rare-plus-quality",
    0, 11,
    {
        type = "scripted",
        trigger_description = { "analog-quality.first-time-offworld" },
        icons = { {
            icon = "__space-age__/graphics/technology/gleba.png",
            icon_size = 256,
        } }
    },
    { "space-platform-thruster" }
)})

-- Replace the existing epic quality completely
local epic_tech = data.raw.technology["epic-quality"]
epic_tech.prerequisites = { "aq-rare-plus-quality" }
epic_tech.unit = nil
epic_tech.research_trigger = {
    type = "scripted",
    trigger_description = { "analog-quality.offworld-science-1" },
    icons = { {
        icon = "__space-age__/graphics/icons/agricultural-science-pack.png",
        icon_size = 64,
        scale = 4,
        shift = { -104, 32 },
        floating = true,
    }, {
        icon = "__space-age__/graphics/icons/electromagnetic-science-pack.png",
        icon_size = 64,
        scale = 4,
        shift = { 0, -32 },
        floating = true,
    }, {
        icon = "__space-age__/graphics/icons/metallurgic-science-pack.png",
        icon_size = 64,
        scale = 4,
        shift = { 104, 32 },
        floating = true,
    }}
}
remove_quality_unlocks(epic_tech)
add_qualities_to_tech("rare", epic_tech, 12, 23)

-- Create a new epic-plus quality tech
data:extend({ create_quality_tech(
    "epic",
    "epic-plus-quality",
    0, 11,
    {
        type = "scripted",
        trigger_description = { "analog-quality.offworld-science-2" },
        icons = { {
            icon = "__space-age__/graphics/icons/agricultural-science-pack.png",
            icon_size = 64,
            scale = 4,
            shift = { -104, 32 },
            floating = true,
        }, {
            icon = "__space-age__/graphics/icons/electromagnetic-science-pack.png",
            icon_size = 64,
            scale = 4,
            shift = { 0, -32 },
            floating = true,
        }, {
            icon = "__space-age__/graphics/icons/metallurgic-science-pack.png",
            icon_size = 64,
            scale = 4,
            shift = { 104, 32 },
            floating = true,
        }}
    },
    { "epic-quality" }
)})

-- Replace the existing legendary quality completely
local legendary_tech = data.raw.technology["legendary-quality"]
legendary_tech.prerequisites = { "aq-epic-plus-quality" }
legendary_tech.unit = nil
legendary_tech.research_trigger = {
    type = "scripted",
    trigger_description = { "analog-quality.offworld-science-3" },
    icons = { {
        icon = "__space-age__/graphics/icons/agricultural-science-pack.png",
        icon_size = 64,
        scale = 4,
        shift = { -104, 32 },
        floating = true,
    }, {
        icon = "__space-age__/graphics/icons/electromagnetic-science-pack.png",
        icon_size = 64,
        scale = 4,
        shift = { 0, -32 },
        floating = true,
    }, {
        icon = "__space-age__/graphics/icons/metallurgic-science-pack.png",
        icon_size = 64,
        scale = 4,
        shift = { 104, 32 },
        floating = true,
    }}
}
remove_quality_unlocks(legendary_tech)
add_qualities_to_tech("epic", legendary_tech, 12, 23)

-- Create a new legendary-plus quality tech
data:extend({ create_quality_tech(
    "legendary",
    "legendary-plus-quality",
    0, 11,
    nil,
    { "legendary-quality" },
    {
        count = 1000,
        time = 60,
        ingredients = {
            { "automation-science-pack", 1 },
            { "logistic-science-pack", 1 },
            { "chemical-science-pack", 1 },
            { "production-science-pack", 1 },
            { "utility-science-pack", 1 },
            { "space-science-pack", 1 },
            { "metallurgic-science-pack", 1 },
            { "agricultural-science-pack", 1 },
            { "electromagnetic-science-pack", 1 },
        }
    }
)})
table.insert(data.raw.technology["planet-discovery-aquilo"].prerequisites, "aq-legendary-plus-quality")

-- Create a new mythic quality tech
data:extend({ create_quality_tech(
    "legendary",
    "mythic-quality",
    12, 23,
    nil,
    { "cryogenic-science-pack" },
    {
        count = 2000,
        time = 60,
        ingredients = {
            { "automation-science-pack", 1 },
            { "logistic-science-pack", 1 },
            { "chemical-science-pack", 1 },
            { "production-science-pack", 1 },
            { "utility-science-pack", 1 },
            { "space-science-pack", 1 },
            { "metallurgic-science-pack", 1 },
            { "agricultural-science-pack", 1 },
            { "electromagnetic-science-pack", 1 },
            { "cryogenic-science-pack", 1 },
        }
    }
)})
table.insert(data.raw.technology["promethium-science-pack"].prerequisites, "aq-mythic-quality")

-- Create a the final mythic+ quality tech
data:extend({ create_quality_tech(
    "aq-mythic",
    "mythic-plus-quality",
    0, 12,
    nil,
    { "promethium-science-pack" },
    {
        count = 1000,
        time = 60,
        ingredients = {
            { "automation-science-pack", 1 },
            { "logistic-science-pack", 1 },
            { "chemical-science-pack", 1 },
            { "production-science-pack", 1 },
            { "utility-science-pack", 1 },
            { "space-science-pack", 1 },
            { "metallurgic-science-pack", 1 },
            { "agricultural-science-pack", 1 },
            { "electromagnetic-science-pack", 1 },
            { "cryogenic-science-pack", 1 },
            { "promethium-science-pack", 1 },
        }
    }
)})
data.raw.technology["research-productivity"].prerequisites = { "aq-mythic-plus-quality" }

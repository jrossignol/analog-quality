-- Rocket Silo Modifications
-- Updates rocket silo, rocket-part recipe, and rocket-part item for quality system integration

-- Store the original rocket-part recipe before modifications
---@type data.RecipePrototype
local rocket_part_recipe = data.raw.recipe["rocket-part"]

--  Make a copy of the the recipe that we'll use on the assembler version
---@type data.RecipePrototype
local assembler_rocket_part_recipe = table.deepcopy(rocket_part_recipe)

if not assembler_rocket_part_recipe then
    error("Analog Quality: Could not find rocket-part recipe")
end

-- Update the existing rocket-part recipe to be passthrough (ingredients: 1x rocket-part)
if rocket_part_recipe then
    rocket_part_recipe.ingredients = {
        {type = "item", name = "rocket-part", amount = 1}
    }
    rocket_part_recipe.allow_productivity = false
end

-- Update the rocket-part item to be visible and properly categorized
---@type data.ItemPrototype
local rocket_part_item = data.raw.item["rocket-part"]
if rocket_part_item then
    -- Remove hidden flag
    rocket_part_item.hidden = false
    -- Set subgroup to space-interactors
    rocket_part_item.subgroup = "space-interactors"
end

-- Create a new fake item that will be part of the rocket recipe.  We'll use this for the spoil trigger.
---@type data.ItemPrototype
local quality_item = {
    name = "aq-normal-0",
    localised_name = { "analog-quality.quality-long", { "quality-name.normal" }, "100" },
    localised_description = { "analog-quality.recipe-quality", data.raw.quality["normal-0"].localised_name },
    type = "item",
    flags = { "ignore-spoil-time-modifier" },
    stack_size = 1,
    icons = { {
        icon = "__analog-quality__/graphics/icons/quality-normal.png",
        icon_size = 64,
        tint = {r=188, g=188, b=188},
        scale = 1,
    } },
    hidden = true,
    hidden_in_factoriopedia = true,
    weight = 20000,
    auto_recycle = false,

    -- Spoils immediately and triggers a script
    spoil_ticks = 1,
    spoil_to_trigger_result = {
        items_per_trigger = 1,
        trigger = {
            type = "direct",
            action_delivery = {
                type = "instant",
                source_effects = {
                    type = "script",
                    effect_id = "aq-spoiled-quality",
                }
            }
        }
    },

    custom_tooltip_fields = { {
        name = { "analog-quality.productivity-bonus-from-quality" },
        value = { "format-percent", "0" },
        --quality_header = "quality header",
        quality_values = { },
    } }
}

-- Generate custom tooltip quality values
local vals = quality_item.custom_tooltip_fields[1].quality_values
for _, quality in pairs(data.raw.quality) do
    if (quality.default_multiplier) then
        local bonus_productivity = math.max((quality.default_multiplier - 1) / 4, 0)
        vals[quality.name] = { "format-percent", string.format("%d", bonus_productivity * 100) }
    end
end


data:extend({quality_item})

-- Create a new recipe from the original: the original recipe will be in an assembler with the original ingredients
assembler_rocket_part_recipe.name = "aq-rocket-part"
assembler_rocket_part_recipe.localised_name = { "item-name.rocket-part" }
assembler_rocket_part_recipe.localised_description = { "recipe-description.rocket-part" }
assembler_rocket_part_recipe.category = "crafting"
assembler_rocket_part_recipe.subgroup = "space-interactors"
assembler_rocket_part_recipe.enabled = true
assembler_rocket_part_recipe.result_is_always_fresh = true
--assembler_rocket_part_recipe.preserve_products_in_machine_output = true
assembler_rocket_part_recipe.icon = rocket_part_item.icon
table.insert(assembler_rocket_part_recipe.results, {
    type = "item",
    name = "aq-normal-0",
    amount = 1,
    --show_details_in_recipe_tooltip = false,
})
-- Register the new recipe
data:extend({assembler_rocket_part_recipe})

-- Update the silo tech to unlock our new recipe
---@type data.TechnologyPrototype
rocket_silo_tech = data.raw.technology["rocket-silo"]
local added = false
for i, eff in ipairs(rocket_silo_tech.effects or {}) do
    if (eff.type == "unlock-recipe" and eff.recipe == "rocket-part") then
        local neweffect = table.deepcopy(eff)
        neweffect.recipe = "aq-rocket-part"
        table.insert(rocket_silo_tech.effects, i, neweffect)
        added = true
        break
    end
end

-- If we weren't able to add the recipe in the right spot, just force it
if (not added) then
    if (rocket_silo_tech) then
        table.insert(rocket_silo_tech, {
            type = "unlock-recipe",
            recipe = "aq-rocket-part",
        })
    else
        error("Analog Quality: Couldn't add new rocket part recipe unlock!")
    end
end

---Update the rocket silo to use fixed quality
---@type data.RocketSiloPrototype
local rocket_silo = data.raw["rocket-silo"]["rocket-silo"]
if rocket_silo then
    -- Update fixed quality to normal-0
    rocket_silo.fixed_quality = "normal-0"
else
    error("Analog Quality: Unable to update rocket silo recipe!")
end

log("Analog Quality: Updated rocket silo for quality system integration")

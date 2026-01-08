---@type data.ModSettingPrototype
local cursor_stack_setting = {
    type = "string-setting",
    name = "aq-cursor-stack-logic",
    setting_type = "runtime-per-user",
    allowed_values = {"none", "closest", "worse", "better"},
    default_value = "closest",
}
data:extend({cursor_stack_setting })

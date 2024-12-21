--[[
* MIT License
*
* Copyright (c) 2024 sockentrocken
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
]]

light_array = {}

---@class light
light = {}

function light:new(shader, type, point, focus, color)
    local i = {}
    setmetatable(i, {
        __index = self
    })

    i.style = 1
    i.state = 1
    i.point = point
    i.focus = focus
    i.color = color
    i.index = #light_array + 1

    i.location_style = shader:get_location_name("lights[" .. tostring(#light_array) .. "].type")
    i.location_state = shader:get_location_name("lights[" .. tostring(#light_array) .. "].enabled")
    i.location_point = shader:get_location_name("lights[" .. tostring(#light_array) .. "].position")
    i.location_focus = shader:get_location_name("lights[" .. tostring(#light_array) .. "].target")
    i.location_color = shader:get_location_name("lights[" .. tostring(#light_array) .. "].color")

    i:update(shader)

    table.insert(light_array, i)

    return i
end

---@param shader shader
function light:update(shader)
    shader:set_shader_number(self.location_state, self.state)
    shader:set_shader_number(self.location_style, self.style)
    shader:set_shader_vector_3(self.location_point, self.point)
    shader:set_shader_vector_3(self.location_focus, self.focus)
    shader:set_shader_vector_4(self.location_color,
        vector_4:old(self.color.r / 255.0, self.color.g / 255.0, self.color.b / 255.0, self.color.a / 255.0))
end

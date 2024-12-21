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

-- the state of the game.
---@class state
---@field time         number
---@field step         number
---@field camera_3d    camera_3d
---@field camera_2d    camera_2d
---@field rapier       rapier
---@field entity       table
---@field entity_index number
---@field asset        table
---@field map          string
state = {}

function state:new()
    state = nil

    local i = {}
    setmetatable(i, {
        __index = self
    })

    local shape = quiver.window.get_shape()
    shape.x = shape.x * DRAW_SCALE
    shape.y = shape.y * DRAW_SCALE

    local dither_shader = quiver.shader.new("data/asset/video/shader/base.vs", "data/asset/video/shader/dither.fs")

    local light_shader = quiver.shader.new("data/asset/video/shader/light.vs", "data/asset/video/shader/light.fs")
    light_shader:set_location(SHADER_LOCATION.VECTOR_VIEW, light_shader:get_location_name("viewPos"))

    local ambient = light_shader:get_location_name("ambient")
    light_shader:set_shader_vector_4(ambient, vector_4:old(0.25, 0.25, 0.25, 1.0))

    light:new(light_shader, 0, vector_3:new(0.0, 4.0, 0.0), vector_3:new(0.0, 0.0, 0.0),
        color:new(255.0, 255.0, 255.0, 255.0))

    i.time = 0.0
    i.step = 0.0
    i.camera_3d = camera_3d:new(vector_3:zero():old_to_new(), vector_3:zero():old_to_new(), vector_3:y():old_to_new(),
        90.0)
    i.camera_2d = camera_2d:new(vector_2:zero():old_to_new(), vector_2:zero():old_to_new(), 0.0, 1.0)
    i.camera_render = camera_3d:new(vector_3:new(1.0, 0.0, 0.0), vector_3:zero():old_to_new(), vector_3:y():old_to_new(),
        90.0)
    i.rapier = quiver.rapier.new()
    i.entity = {}
    i.entity_index = 0.0
    i.asset = {
        ["sky.png"] = quiver.texture.new("data/asset/video/sky.png"),
        ["light"]   = light_shader,
        ["dither"]  = dither_shader,
        ["view"]    = quiver.render_texture.new(shape),
        ["hand"]    = quiver.render_texture.new(shape),
    }
    i.map = nil

    state = i
end

function state:new_map(model_path, texture_path)
    -- reset the current state.
    state:new()

    -- load map model and texture.
    local model   = quiver.model.new(model_path)
    local texture = quiver.texture.new(texture_path)

    texture:set_mipmap()
    texture:set_filter(TEXTURE_FILTER.POINT)

    -- bind model to the texture.
    model:bind(texture)
    model:bind_shader(state.asset["light"])

    -- for each mesh in the model, create a new collider.
    for x = 0, model.mesh_count - 1 do
        local mesh = model:mesh_vertex(x)
        state.rapier:collider_convex_mesh(mesh)
    end

    -- bind model and texture to asset table.
    state.asset[model_path] = model
    state.asset[texture_path] = texture

    -- bind current map to model name.
    state.map = model_path

    -- create new player.
    player:new(state)
end

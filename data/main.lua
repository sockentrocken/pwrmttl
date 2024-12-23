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

require "asset/script/base"
require "asset/script/help"
require "asset/script/window"
require "asset/script/entity"
require "asset/script/player"
require "asset/script/weapon"
require "asset/script/light"
require "asset/script/state"

--[[----------------------------------------------------------------]]

function quiver.main()
    quiver.window.set_state(WINDOW_FLAG.RESIZABLE, true)
    --quiver.window.set_state(WINDOW_FLAG.BORDERLESS_WINDOWED_MODE, true)

    quiver.general.set_frame_rate(288)
    quiver.general.set_exit_key(INPUT_BOARD.KEY_F3)

    state:new()

    -- while the window shouldn't close...
    while not (quiver.window.get_close() or state.close) do
        -- debug restart.
        if quiver.input.board.get_press(INPUT_BOARD.KEY_F1) then
            return true
        end

        if quiver.input.board.get_press(INPUT_BOARD.KEY_F2) then
            state:new()
        end

        -- get frame time, cap if the last frame took longer than 0.25 to render.
        local frame = math.min(quiver.general.get_frame_time(), 0.25)

        if not state.window.state then
            -- increment accumulator.
            state.step = state.step + frame

            -- while accumulator is greater than TICK_RATE...
            while state.step >= TICK_RATE do
                table_pool:begin()

                -- run a game tick for every entity.
                for _, entity in pairs(state.entity) do
                    if entity.tick then
                        entity:tick()
                    end
                end

                -- run a game tick for the rapier simulation.
                state.rapier:step()

                -- increment time, decrement accumulator.
                state.time = state.time + TICK_RATE
                state.step = state.step - TICK_RATE
            end
        end

        table_pool:begin()

        -- begin drawing.
        quiver.draw.begin(draw)
    end

    return false
end

--[[----------------------------------------------------------------]]

function draw()
    ---@class shader
    local shader = state.asset["light"]
    local shader_dither = state.asset["dither"]

    -- get the view/hand render texture and current window size.
    local view = state.asset["view"]
    local hand = state.asset["hand"]
    local window = quiver.window.get_shape()
    local shape = vector_2:old(window.x, window.y)
    shape.x = shape.x * DRAW_SCALE
    shape.y = shape.y * DRAW_SCALE

    if quiver.input.board.get_press(INPUT_BOARD.KEY_ESCAPE) then
        state.window:set_state(not state.window.state)
    end

    -- if the window has shrunk or grown, update the render texture
    if quiver.window.get_resize() then
        state.asset["view"] = quiver.render_texture.new(shape)
        state.asset["hand"] = quiver.render_texture.new(shape)
    end

    -- standard view render pass.
    view:begin(function()
        quiver.draw.clear(color:white())

        -- draw the current sky.
        state.asset["sky.png"]:draw_pro(box_2:old(0.0, 0.0, 1024.0, 1024.0), box_2:old(0.0, 0.0, shape.x, shape.y),
            vector_2:zero(), 0.0, color:white())

        local fade = (math.sin(state.time) + 1.0) * 0.5 * 127.0

        state.light[1].color = color:new(fade, fade, fade, fade)
        state.light[1]:update(shader)

        shader:set_shader_vector_3(shader:get_location(SHADER_LOCATION.VECTOR_VIEW), state.camera_3d.point)

        -- draw 3D/2D scene.
        quiver.draw_3d.begin(draw_3d, state.camera_3d)
        quiver.draw_2d.begin(draw_2d, state.camera_2d)
    end)

    -- hand view-model render pass.
    hand:begin(function()
        quiver.draw.clear(color:old(0, 0, 0, 0))

        -- draw 3D/2D scene.
        quiver.draw_3d.begin(draw_render, state.camera_render)
    end)

    shader_dither:begin(function()
        -- draw the standard view render texture, and then overlay the hand view-model on top.
        view:draw_pro(box_2:old(0.0, 0.0, shape.x, -shape.y), box_2:old(0.0, 0.0, window.x, window.y),
            vector_2:zero(), 0.0, color:white())

        if not state.window.state then
            hand:draw_pro(box_2:old(0.0, 0.0, shape.x, -shape.y), box_2:old(0.0, 0.0, window.x, window.y),
                vector_2:zero(), 0.0, color:white())
        end
    end)
end

--[[----------------------------------------------------------------]]

function draw_render()
    -- draw every entity (hand render-texture pass).
    for _, entity in pairs(state.entity) do
        if entity.draw_render then
            entity:draw_render()
        end
    end
end

function draw_3d()
    -- draw the current map.
    if not state.window.state then
        state.asset[state.map]:draw(vector_3:zero(), 1.0, color:white())

        -- draw every entity (3D pass).
        for key, entity in pairs(state.entity) do
            if entity.draw_3d then
                entity:draw_3d()
            end
        end

        -- draw the rapier scene.
        --state.rapier:debug_render()
    else
        local time = quiver.general.get_time()

        local x = math.sin(time * 0.25) * 4.0
        local z = math.cos(time * 0.25) * 4.0

        state.camera_3d.point:copy(vector_3:old(x, 16.0, z))
        state.camera_3d.focus:copy(vector_3:old(0.0, 0.0, 0.0))
        --state.camera_3d.angle:copy(vector_3:old(0.0, 1.0, 0.0))
        --state.camera_3d.zoom = 90.0

        local max = 256

        local size = vector_3:old(1.0, 8.0, 1.0)

        for x = 1, max do
            local max_x = math.floor((max - 1) % 16.0) * 2.0
            local max_z = math.floor((max - 1) / 16.0) * 2.0

            local point = vector_3:old(
                math.floor((x - 1) % 16.0) * 2.0 - max_x * 0.5,
                math.sin(time * (x / max) * 2.0) * 8.0,
                math.floor((x - 1) / 16.0) * 2.0 - max_z * 0.5
            )

            local fade = (math.sin(time * (x / max) * 2.0) + 1.0) * 0.5 * 255.0

            quiver.draw_3d.draw_cube(point, size, color:old(0.0, 0.0, 0.0, math.floor(fade)))
        end
    end
end

--[[----------------------------------------------------------------]]

function draw_2d()
    -- draw every entity (2D pass).
    for _, entity in pairs(state.entity) do
        if entity.draw_2d then
            entity:draw_2d()
        end
    end

    if state.window.state then
        state.window:draw()
    end

    local frame = quiver.general.get_frame_rate()
    local count = quiver.general.get_memory()

    --quiver.draw_2d.draw_text(tostring(frame), vector_2:old(16.0, 8.0 + 32.0 * 0.0), 32.0, color:black())
    --quiver.draw_2d.draw_text(tostring(count), vector_2:old(16.0, 8.0 + 32.0 * 1.0), 32.0, color:black())
end

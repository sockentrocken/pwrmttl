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

TICK_RATE = 1.0 / 60.0
DRAW_SCALE = 0.5

--[[----------------------------------------------------------------]]

debug_ray = {}

function debug_ray:new(ray)
	local i = entity:new()
	setmetatable(i, {
		__index = self,
	})

	i.ray  = ray
	i.time = 1.0
end

function debug_ray:draw_3d()
	if self.time <= 0.0 then
		state.entity[self.index] = nil
		return
	end

	quiver.draw_3d.draw_ray(self.ray, color:new(255.0, 0.0, 0.0, math.floor(255.0 * self.time)))
	self.time = self.time - quiver.general.get_frame_time() * 0.25
end

--[[----------------------------------------------------------------]]

debug_cube = {}

function debug_cube:new(point)
	local i = entity:new()
	setmetatable(i, {
		__index = self,
	})

	i.point = point:old_to_new()
	i.time = 1.0
end

function debug_cube:draw_3d()
	if self.time <= 0.0 then
		state.entity[self.index] = nil
		return
	end

	quiver.draw_3d.draw_cube(self.point, vector_3:one() * 0.1, color:new(255.0, 0.0, 0.0, math.floor(255.0 * self.time)))
	self.time = self.time - quiver.general.get_frame_time() * 0.25
end

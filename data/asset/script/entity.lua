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

---@class entity
---@field index number
---@field point vector_3
---@field angle vector_4
---@field scale vector_3
entity = {}

---Create a new entity.
---@return entity entity # The entity.
function entity:new()
	local i = {}
	setmetatable(i, {
		__index = self,
	})

	-- update entity index.
	state.entity_index = state.entity_index + 1
	i.index = state.entity_index

	-- standard entity data.
	i.point = vector_3:new(0.0, 0.0, 0.0)
	i.angle = vector_4:new(0.0, 0.0, 0.0, 0.0)
	i.speed = vector_3:new(0.0, 0.0, 0.0)

	-- insert us into entity table.
	table.insert(state.entity, i)

	return i
end

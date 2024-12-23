widget = {}

function widget:new()
	local i = {}
	setmetatable(i, {
		__index = self
	})

	i.hover = 0.0
	i.focus = 0.0

	return i
end

function widget:is_hover(shape)
	local mouse = quiver.input.mouse.get_point()
	local check_x = mouse.x * DRAW_SCALE >= shape.x and mouse.x * DRAW_SCALE <= shape.x + shape.width
	local check_y = mouse.y * DRAW_SCALE >= shape.y and mouse.y * DRAW_SCALE <= shape.y + shape.height

	return (check_x and check_y)
end

function widget:set_hover(shape)
	local frame = quiver.general.get_frame_time()
	local speed = 4.0
	local increase_hover = self.hover + (frame * speed * (1.0 - self.hover))
	local decrease_hover = self.hover - (frame * speed * self.hover)

	-- update hover.
	self.hover = self:is_hover(shape) and increase_hover or decrease_hover

	-- clamp to 0.0, 1.0.
	self.hover = number_clamp(0.0, 1.0, self.hover)

	return self.hover
end

--[[----------------------------------------------------------------]]

---@enum
WINDOW_STATE = {
	MAIN = 0.0,
	REASSEMBLY_VIDEO = 1.0,
	REASSEMBLY_AUDIO = 2.0,
	REASSEMBLY_INPUT = 3.0,
	DETACHMENT = 4.0,
}

window = {}

function window:new()
	local i = {}
	setmetatable(i, {
		__index = self
	})

	i.data = {}
	i.state = true
	i.which = 0
	i.focus = nil
	i.count = 0

	quiver.input.mouse.set_active(true)
	quiver.input.mouse.set_hidden(true)

	return i
end

function window:get(text)
	-- get the widget from the data table.
	local w = self.data[text]

	-- if widget is nil...
	if w == nil then
		-- create a new widget, then assign it to the data table.
		w = widget:new()
		self.data[text] = w
	end

	return w
end

function window:button(point, shape, text)
	local shape_outer = box_2:old(point.x, point.y, shape.x, shape.y)
	local widget = self:get(text)
	local hover = widget:set_hover(shape_outer)
	local shape_inner = box_2:old(shape_outer.x + 4.0, shape_outer.y + 4.0, (shape_outer.width - 8.0) * hover,
		(shape_outer.height - 8.0))

	quiver.draw_2d.draw_box_2(shape_outer, vector_2:zero(), 0.0, color:black())
	quiver.draw_2d.draw_box_2(shape_inner, vector_2:zero(), 0.0, color:white())

	local fade = math.floor(255.0 * (1.0 - hover))

	---@class font
	local font = state.asset["font-side"]

	font:draw(text, vector_2:old(point.x + 6.0, point.y - 4.0), 24.0, 1.0, color:old(fade, fade, fade, 255.0))

	return widget:is_hover(shape_outer) and quiver.input.mouse.get_press(INPUT_MOUSE.MOUSE_BUTTON_LEFT)
end

function window:footer(shape, mouse)
	local font_side    = state.asset["font-side"]

	local color        = color:old(0.0, 0.0, 0.0, 255.0)
	local CPU_text     = "cortex logic processor: Intel© Core™ i7-9750H CPU @ 2.60GHz × 6"
	local GPU_text     = "render sight processor: NVIDIA Corporation TU117M [GeForce GTX 1650 Mobile / Max-Q]"
	local RAM_text     = "target cache capacity: 32.0GB"
	local mouse_text   = string.format("selection interface target module: %.2f, %.2f", mouse.x, mouse.y)
	local shape_text   = string.format("world view render buffer: %.2f, %.2f", shape.x, shape.y)
	local version_text = "world version: 1.0.0"
	local pin          = 104.0

	font_side:draw(CPU_text, vector_2:old(4.0, shape.y - pin + (16.0 * 0.0)), 24.0, 1.0, color)
	font_side:draw(GPU_text, vector_2:old(4.0, shape.y - pin + (16.0 * 1.0)), 24.0, 1.0, color)
	font_side:draw(RAM_text, vector_2:old(4.0, shape.y - pin + (16.0 * 2.0)), 24.0, 1.0, color)
	font_side:draw(mouse_text, vector_2:old(4.0, shape.y - pin + (16.0 * 3.0)), 24.0, 1.0, color)
	font_side:draw(shape_text, vector_2:old(4.0, shape.y - pin + (16.0 * 4.0)), 24.0, 1.0, color)
	font_side:draw(version_text, vector_2:old(4.0, shape.y - pin + (16.0 * 5.0)), 24.0, 1.0, color)
end

function window:set_state(value)
	self.state = value

	if self.state then
		quiver.input.mouse.set_active(true)
		quiver.input.mouse.set_hidden(true)
	else
		quiver.input.mouse.set_active(false)
	end
end

function window:draw()
	-- TO-DO: replace this with get current render shape.
	local shape = quiver.window.get_shape()
	shape.x = shape.x * DRAW_SCALE
	shape.y = shape.y * DRAW_SCALE

	local mouse = quiver.input.mouse.get_point()

	local time = quiver.general.get_time() * 64.0

	quiver.draw_2d.draw_box_2(box_2:old(0.0, 0.0, shape.x, 40.0), vector_2:zero(), 0.0,
		color:old(0.0, 0.0, 0.0, 255.0))

	---@class font
	local font_main = state.asset["font-main"]

	if self.which == WINDOW_STATE.MAIN then
		font_main:draw("pwrmttl.", vector_2:old(8.0, 4.0), 32.0, 1.0, color:white())

		if state.map == nil then
			if self:button(vector_2:old(8.0, 48.0 + 24.0 * 0.0), vector_2:old(160.0, 20.0), "attachment") then
				state:new_map("data/asset/level/map.glb", "data/asset/video/test.png")
			end
		else
			if self:button(vector_2:old(8.0, 48.0 + 24.0 * 0.0), vector_2:old(160.0, 20.0), "reattach") then
				self:set_state(false)
			end
		end
		if self:button(vector_2:old(8.0, 48.0 + 24.0 * 1.0), vector_2:old(160.0, 20.0), "reassembly") then
			self.which =
				WINDOW_STATE.REASSEMBLY_VIDEO
		end
		if self:button(vector_2:old(8.0, 48.0 + 24.0 * 2.0), vector_2:old(160.0, 20.0), "detachment") then
			self.which =
				WINDOW_STATE.DETACHMENT
		end
	elseif self.which == WINDOW_STATE.REASSEMBLY_VIDEO then
		font_main:draw("reassembly :: video.", vector_2:old(8.0, 4.0), 32.0, 1.0, color:white())

		if self:button(vector_2:old(8.0 + 72 * 0.0, 48.0), vector_2:old(64.0, 20.0), "audio") then
			self.which =
				WINDOW_STATE.REASSEMBLY_AUDIO
		end
		if self:button(vector_2:old(8.0 + 72 * 1.0, 48.0), vector_2:old(64.0, 20.0), "input") then
			self.which =
				WINDOW_STATE.REASSEMBLY_INPUT
		end

		if self:button(vector_2:old(8.0 + 72 * 2.0, 48.0), vector_2:old(64.0, 20.0), "return") then
			self.which =
				WINDOW_STATE.MAIN
		end
	elseif self.which == WINDOW_STATE.REASSEMBLY_AUDIO then
		font_main:draw("reassembly :: audio.", vector_2:old(8.0, 4.0), 32.0, 1.0, color:white())

		if self:button(vector_2:old(8.0 + 72 * 0.0, 48.0), vector_2:old(64.0, 20.0), "video") then
			self.which =
				WINDOW_STATE.REASSEMBLY_VIDEO
		end
		if self:button(vector_2:old(8.0 + 72 * 1.0, 48.0), vector_2:old(64.0, 20.0), "input") then
			self.which =
				WINDOW_STATE.REASSEMBLY_INPUT
		end

		if self:button(vector_2:old(8.0 + 72 * 2.0, 48.0), vector_2:old(64.0, 20.0), "return") then
			self.which =
				WINDOW_STATE.MAIN
		end
	elseif self.which == WINDOW_STATE.REASSEMBLY_INPUT then
		font_main:draw("reassembly :: input.", vector_2:old(8.0, 4.0), 32.0, 1.0, color:white())

		if self:button(vector_2:old(8.0 + 72 * 0.0, 48.0), vector_2:old(64.0, 20.0), "video") then
			self.which =
				WINDOW_STATE.REASSEMBLY_VIDEO
		end
		if self:button(vector_2:old(8.0 + 72 * 1.0, 48.0), vector_2:old(64.0, 20.0), "audio") then
			self.which =
				WINDOW_STATE.REASSEMBLY_AUDIO
		end

		if self:button(vector_2:old(8.0 + 72 * 2.0, 48.0), vector_2:old(64.0, 20.0), "return") then
			self.which =
				WINDOW_STATE.MAIN
		end
	elseif self.which == WINDOW_STATE.DETACHMENT then
		font_main:draw("detachment.", vector_2:old(8.0, 4.0), 32.0, 1.0, color:white())

		if self:button(vector_2:old(8.0, 48.0 + 24.0 * 0.0), vector_2:old(160.0, 20.0), "accept") then state.close = true end
		if self:button(vector_2:old(8.0, 48.0 + 24.0 * 1.0), vector_2:old(160.0, 20.0), "return") then self.which = 0.0 end
	end

	--self:footer(shape, mouse)

	mouse.x = (mouse.x * DRAW_SCALE) - 4.0
	mouse.y = (mouse.y * DRAW_SCALE) - 4.0

	quiver.draw_2d.draw_box_2(box_2:old(mouse.x, mouse.y, 8.0, 8.0), vector_2:zero(), 0.0, color:black())
	quiver.draw_2d.draw_box_2(box_2:old(mouse.x + 2.0, mouse.y + 2.0, 4.0, 4.0), vector_2:zero(), 0.0, color:white())
end

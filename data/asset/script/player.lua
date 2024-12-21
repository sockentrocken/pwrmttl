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

CHECK_EPSILON     = -2.0
GRAVITY           = 24.0
FLOOR_FRICTION    = 8.0
FLOOR_ACCELERATE  = 8.0
FLOAT_ACCELERATE  = 4.0
FLOAT_THRESHOLD   = 4.0
MOUSE_SENSITIVITY = 0.1
WALK_SPEED        = 8.0
WALK_FORCE        = 0.25
TILT_FORCE        = 0.05
VIEW_SHIFT        = 1.0
HAND_WALK_FORCE   = vector_3:new(0.25, 0.25, 0.25)
HAND_SWAY_FORCE   = 0.01
MAX_SPEED         = 16.0
MIN_SPEED         = 0.01
SLAM_CAMERA_FORCE = 0.25
DASH_CAMERA_FORCE = 15.0
SLAM_FORCE        = 16.0
DASH_FORCE        = 24.0
MOVEMENT_KEY_X_A  = INPUT_BOARD.KEY_W
MOVEMENT_KEY_X_B  = INPUT_BOARD.KEY_S
MOVEMENT_KEY_Y_A  = INPUT_BOARD.KEY_A
MOVEMENT_KEY_Y_B  = INPUT_BOARD.KEY_D
MOVEMENT_KEY_JUMP = INPUT_BOARD.KEY_SPACE
MOVEMENT_KEY_SLAM = INPUT_MOUSE.MOUSE_BUTTON_LEFT
MOVEMENT_KEY_PULL = INPUT_MOUSE.MOUSE_BUTTON_RIGHT

--[[----------------------------------------------------------------]]

---@class player: entity
---@field on_floor boolean
---@field on_slide boolean
---@field move table
---@field body table
---@field sway vector_2
---@field slam number
---@field pull number
player = {}

---Create a new player entity.
---@return player entity # The player entity.
function player:new()
    ---@class player
    local i = entity:new()
    setmetatable(i, {
        __index = self,
    })

    i.speed_interpolate = vector_3:zero():old_to_new()
    i.on_floor = false
    i.on_slide = false
    i.move = nil
    i.body = nil
    i.sway = vector_2:zero():old_to_new()
    i.slam = 0.0
    i.pull = 0.0
    i.hold = nil
    i.camera_fall_force = 0.0
    i.camera_fall_speed = 0.0
    i.camera_slam = 0.0
    i.camera_dash = 0.0
    i.action = 0.0
    i.slam_interpolate = 0.0

    -- create kinematic character controller and collider.
    local move, body = state.rapier:character_controller()
    i.move = move
    i.body = body

    -- load asset data.
    state.asset["snap"] = quiver.shader.new("data/asset/video/shader/snap.vs", "data/asset/video/shader/base.fs")
    state.asset["hand_a.glb"] = quiver.model.new("data/asset/video/hand_a.glb")
    state.asset["hand_b.glb"] = quiver.model.new("data/asset/video/hand_b.glb")
    state.asset["test.png"] = quiver.texture.new("data/asset/video/test.png")
    state.asset["footstep_concrete_000.ogg"] = quiver.sound.new("data/asset/audio/footstep_concrete_000.ogg")
    state.asset["footstep_concrete_001.ogg"] = quiver.sound.new("data/asset/audio/footstep_concrete_001.ogg")
    state.asset["footstep_concrete_002.ogg"] = quiver.sound.new("data/asset/audio/footstep_concrete_002.ogg")
    state.asset["footstep_concrete_003.ogg"] = quiver.sound.new("data/asset/audio/footstep_concrete_003.ogg")
    state.asset["footstep_concrete_004.ogg"] = quiver.sound.new("data/asset/audio/footstep_concrete_004.ogg")
    state.asset["impactBell_heavy_001.ogg"] = quiver.sound.new("data/asset/audio/impactBell_heavy_001.ogg")
    state.asset["cloth1.ogg"] = quiver.sound.new("data/asset/audio/cloth1.ogg")
    state.asset["cloth3.ogg"] = quiver.sound.new("data/asset/audio/cloth3.ogg")
    state.asset["cloth4.ogg"] = quiver.sound.new("data/asset/audio/cloth4.ogg")
    state.player = i

    -- bind texture.
    state.asset["hand_a.glb"]:bind(state.asset["test.png"])
    state.asset["hand_b.glb"]:bind(state.asset["test.png"])

    -- bind shader.
    state.asset["hand_a.glb"]:bind_shader(state.asset["snap"])
    state.asset["hand_b.glb"]:bind_shader(state.asset["snap"])

    weapon:new()

    return i
end

--[[----------------------------------------------------------------]]

function player:tick()
    -- get the "X" and "Z" direction vector, but only from the yaw angle.
    local d_x, _, d_z = direction_from_euler(vector_3:old(self.angle.x, 0.0, 0.0))

    -- create movement vector.
    local movement = vector_3:zero()

    -- update movement vector.
    if quiver.input.board.get_down(MOVEMENT_KEY_X_A) then movement.x = movement.x + MAX_SPEED end
    if quiver.input.board.get_down(MOVEMENT_KEY_X_B) then movement.x = movement.x - MAX_SPEED end
    if quiver.input.board.get_down(MOVEMENT_KEY_Y_A) then movement.z = movement.z + MAX_SPEED end
    if quiver.input.board.get_down(MOVEMENT_KEY_Y_B) then movement.z = movement.z - MAX_SPEED end

    -- align movement with view.
    movement = movement.x * d_x + movement.z * d_z

    -- get wish direction, wish speed.
    local wish_where = movement:normalize()
    local wish_speed = movement:magnitude()

    -- check if we are truly on ground or not, being on the very surface of a face will make rapier alternate between true/false.
    local check = self.speed.y == 0.0 and vector_3:old(0.0, CHECK_EPSILON, 0.0) or vector_3:zero()

    local fall = self.speed.y

    -- move kinematic character controller.
    local point, floor, slide, collision = state.rapier:move_character_controller(self.move, self.body,
        self.speed + check, 1.0 / 60.0)

    -- a collision has taken place during movement.
    if not (collision == nil) then
        -- for each collision...
        for _, v in pairs(collision) do
            -- get the normal of the collision.
            local normal = vector_3:old(v[1], v[2], v[3])

            -- adjust the player's speed to slide along the wall. note that Rapier already does this, but we need to change the speed.
            self.speed:copy(self.speed - normal * self.speed:dot(normal));
        end
    end

    -- apply rapier translation.
    self.point.x = point[1]
    self.point.y = point[2]
    self.point.z = point[3]
    self.on_floor = floor
    self.on_slide = slide

    if floor then
        -- we are on floor, run floor code.
        self:tick_floor(wish_where, wish_speed)

        -- floor speed.
        if fall < 0.0 then
            self.camera_fall_force = math.max(fall * 0.1, -1.0)
            self.camera_fall_speed = 1.0
        end

        self.speed.y = 0.0

        -- jump.
        self:tick_jump()
    else
        -- we are not on floor, run float code.
        self:tick_float(wish_where, wish_speed)
    end

    -- slam/pull.
    self:tick_slam()
    self:tick_pull()
end

--[[----------------------------------------------------------------]]

function player:draw_render()
    -- cap the speed to the maximum, just so stuff doesn't get too out of hand...
    local cap_speed = vector_3:old(
        number_clamp(-MAX_SPEED, MAX_SPEED, self.speed_interpolate.x),
        number_clamp(-MAX_SPEED, MAX_SPEED, self.speed_interpolate.y),
        number_clamp(-MAX_SPEED, MAX_SPEED, self.speed_interpolate.z)
    )

    local hand_a = state.asset["hand_a.glb"]
    local hand_b = state.asset["hand_b.glb"]

    -- get the "X", "Y" and "Z" direction from the player angle.
    local d_x, d_y, d_z = direction_from_euler(self.angle)

    -- idle animation, bob up and down.
    local idle = math.sin(state.time * 2.0) * 0.05

    -- fall animation.
    local fall = self.camera_fall_force * math.sin(number_interpolate(0.0, math.pi, self.camera_fall_speed))

    -- slam animation, pull slam-hand back.
    local slam = vector_3:old(
        number_random(self.slam_interpolate * 0.1) + self.slam_interpolate * 0.75,
        number_random(self.slam_interpolate * 0.1),
        number_random(self.slam_interpolate * 0.1)
    )

    -- pull animation, pull pull-hand back.
    local pull = vector_3:old(self.pull * 0.75, 0.0, 0.0)

    -- sway animation.
    local sway_y = self.sway.y * HAND_SWAY_FORCE
    local sway_z = self.sway.x * HAND_SWAY_FORCE

    -- calculate vertical speed.
    local speed_y = math.min(math.abs(cap_speed.y), 4.0) * number_sign(cap_speed.y) * -0.1

    -- move animation.
    local move_x = (cap_speed:dot(d_x) / MAX_SPEED) * HAND_WALK_FORCE.x * 2.0
    local move_y = speed_y * (1.0 - fall) + fall * 0.35
    local move_z = (cap_speed:dot(d_z) / MAX_SPEED) * HAND_WALK_FORCE.z * 2.0 * -1.0

    -- walk animation, move hand on the Y axis, and Z axis depending on player speed.
    local walk_y = HAND_WALK_FORCE.y * math.cos(state.time * WALK_SPEED * 1.0) *
        (cap_speed:magnitude() / MAX_SPEED)
    local walk_z = HAND_WALK_FORCE.z * math.sin(state.time * WALK_SPEED * 0.5) *
        (cap_speed:magnitude() / MAX_SPEED)

    -- camera slam shake.
    local slam_shake = vector_3:old(
        number_random(self.camera_slam) * SLAM_CAMERA_FORCE * 2.0,
        number_random(self.camera_slam) * SLAM_CAMERA_FORCE * 2.0,
        number_random(self.camera_slam) * SLAM_CAMERA_FORCE * 2.0
    )

    -- calculate final hand point.
    local point = vector_3:old(move_x, move_y + sway_y + walk_y + idle, sway_z + walk_z + move_z) + slam_shake
    local point_a = vector_3:old(-1.25 + point.x, -1.75 + point.y, 1.75 + point.z) + slam
    local point_b = vector_3:old(-1.25 + point.x, -1.75 + point.y, 1.75 * -1.0 + point.z) + pull

    -- dash animation.
    local dash = math.sin(number_interpolate(0.0, math.pi, self.camera_dash)) * DASH_CAMERA_FORCE

    -- TO-DO: not correct. should follow the real 3D camera for proper lighting.
    hand_a:draw_transform(point_a, vector_4:w(), vector_3:one(),
        color:white())
    hand_b:draw_transform(point_b, vector_4:w(), vector_3:one(),
        color:white())

    state.camera_render.zoom = 90.0 + dash
end

function player:draw_3d()
    -- update interpolation speed (we use this for the camera, mainly.)
    self.speed_interpolate:copy(self.speed_interpolate + (self.speed - self.speed_interpolate) * TICK_RATE * 4.0)

    -- update interpolation speed (we use this for the camera, mainly.)
    self.slam_interpolate = self.slam_interpolate + (self.slam - self.slam_interpolate) * TICK_RATE * 4.0

    -- get frame time.
    local frame = quiver.general.get_frame_time()

    -- update player camera animation.
    self.camera_fall_speed = self.camera_fall_speed - (frame * self.camera_fall_speed * 4.0)
    self.camera_slam = self.camera_slam - (frame * self.camera_slam * 4.0)
    self.camera_dash = self.camera_dash - (frame * self.camera_dash * 4.0)

    -- get the mouse delta.
    local delta = quiver.input.mouse.get_delta()

    -- update the player angle.
    self.angle.x = self.angle.x - delta.x * MOUSE_SENSITIVITY
    self.angle.y = self.angle.y + delta.y * MOUSE_SENSITIVITY

    -- clamp player angle.
    self.angle.x = math.fmod(self.angle.x, 360.0)
    self.angle.y = number_clamp(-90.0, 90.0, self.angle.y)

    -- update the player hand sway.
    self.sway.x = self.sway.x + delta.x * MOUSE_SENSITIVITY
    self.sway.y = self.sway.y + delta.y * MOUSE_SENSITIVITY
    self.sway:copy(self.sway - (frame * self.sway * 4.0))

    -- fall animation.
    local fall = self.camera_fall_force * math.sin(number_interpolate(0.0, math.pi, self.camera_fall_speed))

    -- dash animation.
    local dash = math.sin(number_interpolate(0.0, math.pi, self.camera_dash)) * DASH_CAMERA_FORCE

    -- get the "X", "Y" and "Z" direction from the player angle.
    local d_x, d_y, d_z = direction_from_euler(vector_3:old(self.angle.x, self.angle.y - fall, self.angle.z))

    -- camera walk bob + walk tilt.
    local walk = math.sin(state.time * WALK_SPEED) * (self.speed_interpolate:magnitude() / MAX_SPEED) * WALK_FORCE
    local tilt = (self.speed_interpolate:dot(d_z) / MAX_SPEED) * TILT_FORCE

    -- camera slam shake.
    local slam = vector_3:old(
        number_random(self.slam_interpolate * 0.05) + number_random(self.camera_slam) * SLAM_CAMERA_FORCE,
        number_random(self.slam_interpolate * 0.05) + number_random(self.camera_slam) * SLAM_CAMERA_FORCE,
        number_random(self.slam_interpolate * 0.05) + number_random(self.camera_slam) * SLAM_CAMERA_FORCE
    )

    -- the camera's point.
    local point = self.point + vector_3:old(0.0, VIEW_SHIFT + fall + walk, 0.0) + slam

    -- update camera.
    state.camera_3d.point:copy(point)
    state.camera_3d.focus:copy(point + d_x)
    state.camera_3d.angle:copy(d_y:rotate_axis_angle(d_x, tilt))
    state.camera_3d.zoom = 90.0 + dash - (self.pull * 15.0)
end

--[[----------------------------------------------------------------]]

function player:draw_2d()
    -- cap the speed to the maximum, just so stuff doesn't get too out of hand...
    local cap_speed = vector_3:old(
        number_clamp(-MAX_SPEED, MAX_SPEED, self.speed_interpolate.x),
        number_clamp(-MAX_SPEED, MAX_SPEED, self.speed_interpolate.y),
        number_clamp(-MAX_SPEED, MAX_SPEED, self.speed_interpolate.z)
    )

    -- get the "X", "Y" and "Z" direction from the player angle.
    local _, _, d_z = direction_from_euler(self.angle)

    -- calculate vertical speed.
    local speed_y = math.min(math.abs(cap_speed.y), 4.0) * number_sign(cap_speed.y) * -0.1

    -- fall animation.
    local fall = self.camera_fall_force * math.sin(number_interpolate(0.0, math.pi, self.camera_fall_speed)) * 4.0

    -- move animation.
    local move_y = (speed_y * (1.0 - fall) + fall * 0.35) * 4.0
    local move_z = (cap_speed:dot(d_z) / MAX_SPEED) * HAND_WALK_FORCE.z * 2.0 * -4.0

    -- sway animation.
    local sway = self.sway * HAND_SWAY_FORCE * 8.0

    -- slam animation.
    local slam = vector_2:old(
        number_random(self.slam * 1.0) + number_random(self.camera_slam) * SLAM_CAMERA_FORCE * 32.0,
        number_random(self.slam * 1.0) + number_random(self.camera_slam) * SLAM_CAMERA_FORCE * 32.0
    )

    -- get the center of the screen.
    local shape = quiver.window.get_shape()
    shape.x = (shape.x * DRAW_SCALE) * 0.5 - sway.x + slam.x - move_z
    shape.y = (shape.y * DRAW_SCALE) * 0.5 - sway.y + slam.y - move_y

    local radius = 6.0 - (self.pull * 2.0) + (self.slam_interpolate * 2.0)

    -- calculate slam circle start/end.
    local slam = (self.slam * -360) + 270.0

    local action_color = color:white()

    if self.action == 1.0 then action_color = color:old(255.0, 0.0, 0.0, 255.0) end
    if self.action == 2.0 then action_color = color:old(0.0, 0.0, 255.0, 255.0) end

    quiver.draw_2d.draw_circle(shape, radius, color:black())
    quiver.draw_2d.draw_circle_sector(shape, radius, 270.0, slam, 0.0,
        color:old(0.0, 255.0, 0.0, 255.0))
    quiver.draw_2d.draw_circle(shape, radius * 0.5, action_color)
end

--[[----------------------------------------------------------------]]

function player:tick_jump()
    -- if the JUMP key is down, jump.
    if quiver.input.board.get_down(MOVEMENT_KEY_JUMP) then
        self.speed.y = 8.0

        -- play sound.
        local sound = state.asset["cloth4.ogg"]
        sound:set_volume(4.0)
        sound:play()
    end
end

--[[----------------------------------------------------------------]]

function player:perform_slam(hit)
    -- apply new speed to the player.
    local normal = vector_3:old(hit.normal[1], hit.normal[2], hit.normal[3])
    self.speed:copy(self.slam * SLAM_FORCE * normal)

    -- apply camera slam shake.
    self.camera_slam = self.slam
end

--[[----------------------------------------------------------------]]

function player:perform_dash()
    if not self.on_floor then
        local d_x = direction_from_euler(vector_3:old(self.angle.x, 0.0, 0.0))

        self.speed:copy(self.slam * DASH_FORCE * d_x)

        -- apply camera dash field-of-view increase.
        self.camera_dash = 1.0
    end
end

function player:tick_slam()
    -- update slam animation.
    local slam_speed = self.on_floor and 1.0 or 2.0
    self.slam = math.min(self.slam + (quiver.input.mouse.get_down(MOVEMENT_KEY_SLAM) and TICK_RATE * slam_speed or 0.0),
        1.0)

    self.action = 0.0

    -- get the "X" direction from the player angle.
    local d_x = direction_from_euler(self.angle)

    -- cast a ray, ignoring the player's collision body.
    local index, body, hit = state.rapier:cast_ray(ray:new(self.point + vector_3:old(0.0, VIEW_SHIFT, 0.0), d_x),
        2.5, {}, { self.body })

    -- if the SLAM key is up...
    if quiver.input.mouse.get_up(MOVEMENT_KEY_SLAM) then
        -- if slam is higher than 0.0...
        if self.slam > 0.0 then
            -- hit object...
            if hit then
                self:perform_slam(hit)

                local entity = state.entity[index]

                -- object is a valid entity..
                if entity then
                    -- check if we can drop the object.
                    local drop = true

                    -- hit object is our currently held item...
                    if index == self.hold then
                        -- currently held item has slam-specific code.
                        if entity.slam then
                            -- should {drop} be true, then we apply speed to the object and stop holding it.
                            drop = entity:slam(self)
                        end
                    end

                    -- we can drop object.
                    if drop then
                        -- stop holding object, apply speed.
                        self.hold = nil
                        state.rapier:set_rigid_body_data(entity.move, d_x * self.slam * 64.0)
                    end
                end
            else
                self:perform_dash()
            end
        end

        -- reset slam.
        self.slam = 0.0
    else
        self.action = hit and 1.0 or not self.on_floor and 2.0 or 0.0
    end
end

--[[----------------------------------------------------------------]]

function player:tick_pull()
    -- if the PULL key was set off...
    if quiver.input.mouse.get_press(MOVEMENT_KEY_PULL) then
        -- get the "X" direction from the player angle.
        local d_x = direction_from_euler(self.angle)

        -- cast a ray, ignoring the player's collision body.
        local index, body, hit = state.rapier:cast_ray(ray:new(self.point + vector_3:old(0.0, VIEW_SHIFT, 0.0), d_x),
            16.0, {}, { self.body })

        -- hit object...
        if hit then
            local entity = state.entity[index]

            -- object is a valid entity..
            if entity then
                -- hold object.
                self.hold = index
            end
        end
    end

    -- if the PULL key is down...
    if quiver.input.mouse.get_down(MOVEMENT_KEY_PULL) then
        -- update pull animation.
        self.pull = self.pull + TICK_RATE * (1.0 - self.pull) * 8.0

        -- get the "X" direction from the player angle.
        local d_x = direction_from_euler(self.angle)

        -- currently holding an entity...
        if self.hold then
            -- get entity, rigid body data.
            local hold = state.entity[self.hold]
            local move = state.rapier:get_rigid_body_data(hold.move).pos.position.translation

            -- keep some distance away.
            d_x = d_x * (self.speed:magnitude() * 0.1 + 2.0)
            d_x.y = d_x.y + VIEW_SHIFT

            -- calculate entity velocity to look angle.
            local pull = vector_3:old(
                (self.point.x + d_x.x) - move[1],
                (self.point.y + d_x.y) - move[2],
                (self.point.z + d_x.z) - move[3]
            )

            state.rapier:set_rigid_body_data(hold.move, pull:normalize() * pull:magnitude() * 8.0)
        end
    else
        -- update pull animation.
        self.pull = self.pull + TICK_RATE * self.pull * -8.0

        -- let go of whatever it was we were holding.
        self.hold = nil
    end
end

--[[----------------------------------------------------------------]]

function player:tick_float(where, speed)
    local friction = 0.0

    -- decrease vertical velocity.
    if self.camera_dash < 0.5 then
        self.speed.y = self.speed.y - (GRAVITY * TICK_RATE)
    end

    if speed < FLOAT_THRESHOLD then
        friction = speed - self.speed:dot(where)
    else
        friction = FLOAT_THRESHOLD - self.speed:dot(where)
    end

    if self.camera_dash > 0.5 then
        print("apply dash friction")
        friction = 0.1
    end

    -- apply speed.
    if friction > 0.0 then
        self.speed:copy(self.speed + (where * math.min(friction, FLOAT_ACCELERATE * TICK_RATE * speed)))
    end
end

--[[----------------------------------------------------------------]]

function player:tick_floor(where, speed)
    local friction = FLOOR_FRICTION
    local velocity = vector_3:old(self.speed.x, 0.0, self.speed.z):magnitude()

    if velocity > 0.0 then
        local f = velocity

        if f < MIN_SPEED then
            f = 1.0 - TICK_RATE * (MIN_SPEED / f) * friction
        else
            f = 1.0 - TICK_RATE * friction
        end

        if f < 0.0 then
            -- round speed to 0.0 if friction is negative.
            self.speed.x = 0.0
            self.speed.y = 0.0
            self.speed.z = 0.0
        else
            -- apply speed.
            self.speed.x = self.speed.x * f
            self.speed.z = self.speed.z * f
        end
    end

    friction = speed - self.speed:dot(where)

    -- apply speed.
    if friction > 0.0 then
        self.speed:copy(self.speed + (where * math.min(friction, FLOOR_ACCELERATE * TICK_RATE * speed)))
    end
end

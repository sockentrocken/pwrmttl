---@class weapon: entity
weapon = {}

function weapon:new()
    local i = entity:new()
    setmetatable(i, {
        __index = self,
    })

    state.asset["blasterA.glb"] = quiver.model.new("data/asset/video/blasterA.glb")
    state.asset["laser6.ogg"] = quiver.sound.new("data/asset/audio/laser6.ogg")

    local info = rigid_body_info:new(RIGID_BODY_KIND.DYNAMIC, i.index,
        vector_3:new(0.0, 4.0, 0.0))
    local move = state.rapier:create_rigid_body(info)

    local info = collider_info:new({ Cube = { 0.10, 0.25, 0.5 } }, i.index, move)
    local body = state.rapier:create_collider(info)

    i.move = move
    i.body = body
    i.hold = false
end

function weapon:tick()
    local move = state.rapier:get_rigid_body_data(self.move).pos.position

    self.point.x = move.translation[1]
    self.point.y = move.translation[2]
    self.point.z = move.translation[3]

    self.angle.x = move.rotation[1]
    self.angle.y = move.rotation[2]
    self.angle.z = move.rotation[3]
    self.angle.w = move.rotation[4]
end

function weapon:draw_3d()
    state.asset["blasterA.glb"]:draw_transform(self.point, self.angle, vector_3:one(),
        color:new(255.0, 255.0, 255.0, state.player.hold == self.index and 66.0 or 255.0))
end

function weapon:slam(player)
    -- get the "X" direction from the player angle.
    local d_x, d_y, d_z = direction_from_euler(player.angle)

    for x = 1, 16 do
        local point = player.point + vector_3:old(0.0, VIEW_SHIFT, 0.0)
        local angle = d_x + d_y * number_random(0.1) + d_z * number_random(0.5)

        local index, body, hit = state.rapier:cast_ray(
            ray:new(point, angle),
            1024.0, { self.move }, { player.body })

        -- hit object...
        if hit then
            local entity = state.entity[index]

            debug_ray:new(ray:new(point, angle))
            debug_cube:new(point + (angle * hit.time_of_impact))

            -- object is a valid entity..
            if entity then
                state.rapier:set_rigid_body_data(entity.move, angle * 32.0)
            end
        end
    end

    state.asset["laser6.ogg"]:set_volume(4.0)
    state.asset["laser6.ogg"]:play()

    return false
end

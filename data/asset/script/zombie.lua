zombie = {}

function zombie:new(point)
    local i = entity:new()
    setmetatable(i, {
        __index = self,
    })

    state.asset["zombie.glb"] = quiver.model.new("data/asset/video/zombie.glb")
    state.asset["zombie.png"] = quiver.texture.new("data/asset/video/zombie.png")

    state.asset["zombie.glb"]:bind(state.asset["zombie.png"])

    local info = rigid_body_info:new(RIGID_BODY_KIND.DYNAMIC, i.index, point)
    local move = state.rapier:create_rigid_body(info)

    local info = collider_info:new({ Cube = { 0.5, 2.0, 0.5 } }, i.index, move)
    local body = state.rapier:create_collider(info)

    i.move = move
    i.body = body
end

function zombie:tick()
    local move = state.rapier:get_rigid_body_data(self.move).pos.position

    self.point.x = move.translation[1]
    self.point.y = move.translation[2]
    self.point.z = move.translation[3]

    self.angle.x = move.rotation[1]
    self.angle.y = move.rotation[2]
    self.angle.z = move.rotation[3]
    self.angle.w = move.rotation[4]
end

function zombie:draw_3d()
    --state.asset["zombie.glb"]:draw_transform(self.point - vector_3:old(0.0, 2.0, 0.0), self.angle, vector_3:one(),
    --color:old(255.0, 255.0, 255.0, state.player.hold == self.index and 66.0 or 255.0))
end

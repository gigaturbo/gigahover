gigahover.hovercraft = {}

--------------------------------------------------------------------------------
-- local
--------------------------------------------------------------------------------

local S = gigahover.S
local floor = math.floor
local pi = math.pi
local chat_send_player = minetest.chat_send_player
local get_player_by_name = minetest.get_player_by_name

--------------------------------------------------------------------------------
-- private
--------------------------------------------------------------------------------

local function fastacc(vx, vy, vz, yaw, cu, cj, d, dt)
    local tmp3 = vy * vy
    local tmp4 = vz * vz
    local tmp5 = vx * vx
    local tmp6 = tmp3 + tmp4
    local tmp7 = tmp5 + tmp6
    local tmp8 = math.sqrt(tmp7)
    return {
        x = dt * (150 * cu * math.cos(yaw) - 0.1 * vx * tmp8),
        y = dt * (50 + 45 * cj - 50 * d - 0.1 * vy * tmp8),
        z = dt * (150 * cu * math.sin(yaw) - 0.1 * vz * tmp8)
    }
end

local hovercraft = {
    physical = true,
    collisionbox = {-0.8, 0, -0.8, 0.8, 1.2, 0.8},
    visual = 'mesh',
    mesh = 'hovercraft.x',
    textures = {'hovercraft_black.png'},
    player = nil,
    owner = nil,
    timer = 0,
    vel = vector3.zero,
    on_activate = function(self, staticdata, dtime_s) -- time since unloaded
        self.object:set_armor_groups({immortal = 1})
        self.object:set_animation({x = 0, y = 24}, 30)
        self.owner = core.deserialize(staticdata).owner
    end,
    on_punch = function(self, puncher)
        if not puncher or not puncher:is_player() then return end
        if self.player then return end

        local pname = puncher:get_player_name()
        if self.owner and pname ~= self.owner then
            core.chat_send_player(pname, S('You cannot take @1\'s hovercraft.',
                                           self.owner))
            return
        end
        local stack = ItemStack('gigahover:hovercraft_item')
        local pinv = puncher:get_inventory()
        if not pinv:room_for_item('main', stack) then
            core.chat_send_player(pname,
                                  S('You don\'t have room in your inventory.'))
            return
        end
        self.object:remove()
        pinv:add_item('main', stack)
    end,
    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then return end

        local pos = self.object:get_pos()
        if self.player and clicker == self.player then -- leave hovercraft
            self.acc = vector3.zero
            self.player = nil
            self.object:set_animation({x = 0, y = 24}, 30)
            clicker:set_animation({x = 0, y = 0})
            clicker:set_detach()
        elseif not self.player then -- join hovercraft
            local pname = clicker:get_player_name()
            if self.owner and pname ~= self.owner then
                core.chat_send_player(pname, S(
                                          'You cannot ride @1\'s hovercraft.',
                                          self.owner))
                return
            end

            self.player = clicker
            local attach_y = 16.5
            if core.features.object_independent_selectionbox then
                attach_y = 5.75
            end

            clicker:set_attach(self.object, '', {x = -2, y = attach_y, z = 0},
                               {x = 0, y = 90, z = 0})
            clicker:set_animation({x = 81, y = 81})
            self.object:set_animation({x = 0, y = 0})
        end
    end,
    -- on_step = function(self, dtime)

    --     local vel = vector3(self.object:get_velocity())
    --     local pos = self.object:get_pos()
    --     local ctrlup = 0
    --     local ctrljump = 0
    --     local yaw = self.object:get_yaw()

    --     if vel:length() < 0.5 then -- stop
    --         vel = vector3.zero
    --         self.object:set_velocity(vel)
    --     end

    --     -- controls 
    --     if self.player then

    --         self.player:set_animation({x = 81, y = 81})
    --         local ctrl = self.player:get_player_control()

    --         -- yaw
    --         if ctrl.left then
    --             yaw = yaw + 0.05
    --         elseif ctrl.right then
    --             yaw = yaw - 0.05
    --         end
    --         self.object:set_yaw(yaw)

    --         -- ctrlup
    --         if ctrl.up then
    --             ctrlup = 1
    --         elseif ctrl.down then
    --             ctrlup = -1
    --         end

    --         -- ctrljump
    --         if ctrl.jump then ctrljump = 1 end

    --     end

    --     -- dist
    --     local p1 = (vector3(pos):round() + vector3(-2, -3, -2))
    --     local p2 = (vector3(pos):round() + vector3(2, -1, 2))
    --     p1, p2 = p1:sort(p2)
    --     local dist = 3
    --     local nname
    --     for z = p1.z, p2.z do
    --         for y = p1.y, p2.y do
    --             for x = p1.x, p2.x do
    --                 nname = minetest.get_node({x = x, y = y, z = z}).name
    --                 if nname ~= 'air' then
    --                     dist = pos.y - y - 0.5
    --                 end
    --             end
    --         end
    --     end

    --     self.object:add_velocity(fastacc(vel.x, vel.y, vel.z, yaw, ctrlup,
    --                                      ctrljump, dist, dtime))
    -- end,
    on_step = function(self, dtime)

        local acc = vector3.zero
        local vel = vector3.zero
        local thrust = vector3.zero
        local drag = vector3.zero
        local brake = 0
        local weight = vector3.zero
        local pos = vector3(self.object:get_pos())
        local speed

        vel = vector3(self.object:get_velocity())
        if vel:length() < 0.5 then -- stop
            vel = vector3.zero
            self.object:set_velocity(vel)
        end
        speed = vel:length()

        -- controls 
        if self.player then

            self.player:set_animation({x = 81, y = 81})
            local yaw = self.object:get_yaw()
            local pyaw = self.player:get_look_horizontal() + pi / 2
            local ctrl = self.player:get_player_control()
            if not yaw then return end

            local inc = (30 - math.min(30, speed)) / 30 * 0.04 + 0.04
            -- turning
            if ctrl.left then
                yaw = yaw + inc
            elseif ctrl.right then
                yaw = yaw - inc
            end

            -- local mod = function(a, n) return a - floor(a / n) * n end
            -- local da = (((yaw - pyaw) + pi) % (2 * pi)) - pi
            -- minetest.chat_send_all('Y: ' .. yaw % (2 * pi))
            -- minetest.chat_send_all('P: ' .. pyaw % (2 * pi))
            -- minetest.chat_send_all('D: ' .. da)
            -- if math.abs(da) > pi / 4 then
            --     self.player:set_look_horizontal(pyaw - da)
            -- end
            self.object:set_yaw(yaw)

            -- forward/brake
            if ctrl.up then
                thrust = thrust + vector3.x
            elseif ctrl.down then
                brake = 1
            end
            thrust = thrust:rotate_around(vector3.y, yaw)
            thrust = thrust:scale(30)

            -- lift?
            -- if ctrl.jump then -- end

        end

        -- drag force
        if speed > 5 then
            drag = -(vel:norm() * (speed * speed)) * (0.04 + 0.08 * brake)
        else
            drag = -(vel:norm() * (speed * speed)) * (5 - speed) / 2
        end

        minetest.chat_send_all('V: ' .. speed)

        local rp = pos:round()
        local p1 = (rp + vector3(-2, -3, -2))
        local p2 = (rp + vector3(2, 0, 2))
        p1, p2 = p1:sort(p2)
        local dist = 4
        local found
        local nname
        for y = p2.y, p1.y, -1 do
            for z = p1.z, p2.z do
                for x = p1.x, p2.x do
                    nname = minetest.get_node({x = x, y = y, z = z}).name
                    if nname ~= 'air' then
                        -- minetest.set_node({x = x, y = y, z = z},
                        --                   {name = 'wool:blue'})
                        dist = pos.y + 0.5 - y
                        found = true
                        break
                    end
                end
                if found then break end
            end
            if found then break end
        end

        if dist < 2 then -- 0 - 2 UP
            vel = vel:set(_, 5 + speed / 2, _)
            acc = thrust + drag:set(_, 0, _)
            self.object:set_velocity(vel + acc * dtime)
        elseif dist < 3 then -- 2 -- 3 STABLE
            vel = vel:set(_, 0, _)
            acc = thrust + drag:set(_, 0, _)
            self.object:set_velocity(vel + acc * dtime)
        else -- 3+
            weight = -vector3.y:scale(40)
            acc = drag + weight + thrust
            self.object:set_velocity(vel + acc * dtime)
        end
    end,
    get_staticdata = function(self)
        local sdata = {owner = self.owner}
        return core.serialize(sdata)
    end
}

--- export

gigahover.hovercraft = setmetatable(hovercraft, {})


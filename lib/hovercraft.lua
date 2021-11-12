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
    --
    -- ACTIVATE
    --
    on_activate = function(self, staticdata, dtime_s) -- time since unloaded
        self.object:set_armor_groups({immortal = 1})
        self.object:set_animation({x = 0, y = 24}, 30)
        self.owner = core.deserialize(staticdata).owner
    end,
    --
    -- PUNCH
    --
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
    --
    -- RIGHTCLICK
    --
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
    --
    -- STEP
    --
    on_step = function(self, dtime)

        local acc = vector3.zero
        local vel = vector3.zero
        local thrust = vector3.zero
        local drag = vector3.zero
        local lift = vector3.zero
        local weight = vector3.zero
        local brake = 0
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
            if ctrl.jump then lift = vector3.y:scale(80) end

        end

        -- drag force
        if speed > 5 then
            drag = -(vel:norm() * (speed * speed)) * (0.04 + 0.08 * brake)
        else
            drag = -(vel:norm() * (speed * speed)) * (5 - speed) / 2
        end

        -- minetest.chat_send_all('V: ' .. speed)

        local rp = pos:round()
        local p1 = (rp + vector3(-2, -1, -2))
        local p2 = (rp + vector3(2, -1, 2))
        p1, p2 = p1:sort(p2)
        local grounded = nil
        local nname = nil
        for y = p2.y, p1.y, -1 do
            for z = p1.z, p2.z do
                for x = p1.x, p2.x do
                    nname = minetest.get_node({x = x, y = y, z = z}).name
                    if nname ~= 'air' then
                        -- minetest.set_node({x = x, y = y, z = z},
                        --                   {name = 'wool:brown'})
                        grounded = true
                        -- break
                    end
                end
                -- if found then break end
            end
            -- if found then break end
        end

        local blocked = false

        if speed == 0 then
            if grounded then
                -- tDO
                if blocked then

                else

                end
            else -- nevermind blocked
                weight = -vector3.y:scale(40)
            end
        else -- moving
            if grounded then
                local apos = pos -- - vector3(0, 0.5, 0)
                local fvel = vel:set(_, 0, _):scale(4)
                local prot = pi / 4
                local nw1, bp1 = minetest.line_of_sight(apos, apos + fvel)
                local nw2, bp2 = minetest.line_of_sight(apos, apos +
                                                            fvel:rotate_around(
                                                                vector3.y, prot))
                local nw3, bp3 = minetest.line_of_sight(apos, apos +
                                                            fvel:rotate_around(
                                                                vector3.y, -prot))
                local blocked = (not nw1) or (not nw2) or (not nw3)
                if blocked then
                    local d = 5
                    if not nw1 then
                        minetest.set_node({x = bp1.x, y = bp1.y, z = bp1.z},
                                          {name = 'wool:green'})
                        d = math.min(d, apos:dist(bp1))
                    end
                    if not nw2 then
                        minetest.set_node({x = bp2.x, y = bp2.y, z = bp2.z},
                                          {name = 'wool:red'})
                        d = math.min(d, apos:dist(bp2))
                    end
                    if not nw3 then
                        minetest.set_node({x = bp3.x, y = bp3.y, z = bp3.z},
                                          {name = 'wool:blue'})
                        d = math.min(d, apos:dist(bp3))
                    end
                    d = math.max(d - 1.4, 0.2)
                    local hspeed = vel:set(_, 0, _):length()
                    local time_before_hit = d / hspeed
                    local vspeed = 1 / time_before_hit
                    vel = vel:set(_, vspeed, _):limit(40)
                else -- not blocked
                    vel = vel:set(_, 0, _)
                end
            else -- not grounded but maybe blocked?
                local apos = pos - vector3(0, 0.5, 0)
                local fvel = vel:set(_, 0, _):scale(3)
                local prot = pi / 4
                local nw1, bp1 = minetest.line_of_sight(apos, apos + fvel)
                local nw2, bp2 = minetest.line_of_sight(apos, apos +
                                                            fvel:rotate_around(
                                                                vector3.y, prot))
                local nw3, bp3 = minetest.line_of_sight(apos, apos +
                                                            fvel:rotate_around(
                                                                vector3.y, -prot))
                local blocked = (not nw1) or (not nw2) or (not nw3)
                if blocked then
                    weight = -vector3.y:scale(40)
                else -- not blocked
                    weight = -vector3.y:scale(40)
                end
            end
        end

        -- minetest.chat_send_all('G: ' .. tostring(not not grounded))
        -- minetest.chat_send_all('B: ' .. tostring(blocked))
        -- minetest.chat_send_all('S: ' .. tostring(speed == 0))

        acc = drag + weight + thrust + lift
        self.object:set_velocity(vel + acc * dtime)

        -- if dist < 2 then -- 0 - 2 UP
        --     vel = vel:set(_, 5 + speed / 2, _)
        --     acc = thrust + drag:set(_, 0, _)
        --     self.object:set_velocity(vel + acc * dtime)
        -- elseif dist < 3 then -- 2 -- 3 STABLE
        --     vel = vel:set(_, 0, _)
        --     acc = thrust + drag:set(_, 0, _)
        --     self.object:set_velocity(vel + acc * dtime)
        -- else -- 3+
        --     weight = -vector3.y:scale(40)
        --     acc = drag + weight + thrust
        --     self.object:set_velocity(vel + acc * dtime)
        -- end
    end,
    --
    -- STATICDATA
    --
    get_staticdata = function(self)
        local sdata = {owner = self.owner}
        return core.serialize(sdata)
    end
}

--- export

gigahover.hovercraft = setmetatable(hovercraft, {})


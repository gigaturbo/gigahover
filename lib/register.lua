--------------------------------------------------------------------------------
-- local
--------------------------------------------------------------------------------
local S = gigahover.S
local get_player_by_name = minetest.get_player_by_name
local get_pointed_thing_position = minetest.get_pointed_thing_position
local chat_send_player = minetest.chat_send_player

--------------------------------------------------------------------------------
-- private
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- tools
--------------------------------------------------------------------------------

minetest.register_craftitem('gigahover:hovercraft_item', {
    description = S('hovercraft'),
    inventory_image = 'hovercraft_black_inv.png',
    liquids_pointable = true,
    on_drop = function(itemstack, dropper, pos) return itemstack end,
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then return end
        pointed_thing.under.y = pointed_thing.under.y + 0.5
        minetest.add_entity(pointed_thing.under, 'gigahover:hovercraft',
                            core.serialize({owner = placer:get_player_name()}))
        itemstack:take_item()
        return itemstack
    end
})

--------------------------------------------------------------------------------
-- entities
--------------------------------------------------------------------------------

minetest.register_entity("gigahover:hovercraft", gigahover.hovercraft)

--------------------------------------------------------------------------------
-- players
--------------------------------------------------------------------------------

minetest.register_on_newplayer(function(player)

    local name = player:get_player_name()

end)

minetest.register_on_joinplayer(function(player)

    local name = player:get_player_name()

    -- overrides
    player:override_day_night_ratio(1)
    player:set_stars({visible = false})
    player:set_sun({visible = false})
    player:set_moon({visible = false})
    player:set_clouds({density = 0})

end)

minetest.register_on_leaveplayer(function(player, timed_out)
    local name = player:get_player_name()
end)

--------------------------------------------------------------------------------
-- Commands and privileges
--------------------------------------------------------------------------------

minetest.register_privilege("gigahover", {
    description = "Player can use the gigahover admin commands",
    give_to_singleplayer = false
})

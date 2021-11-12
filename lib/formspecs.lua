gigahover.formspecs = {}

--------------------------------------------------------------------------------
-- local
--------------------------------------------------------------------------------

local S = gigahover.S

local formspec_escape = minetest.formspec_escape
local chat_send_all = minetest.chat_send_all
local chat_send_player = minetest.chat_send_player
local destroy_form = minetest.destroy_form
local update_form = minetest.update_form
local explode_textlist_event = minetest.explode_textlist_event
local get_player_by_name = minetest.get_player_by_name

--------------------------------------------------------------------------------
-- private
--------------------------------------------------------------------------------

-- formspec1

local fs1 = {

    get_form = function(meta)

        local fs = "size[16,10.5]"

        -- styles 
        fs = fs .. 'style[remove;bgcolor=red]'
        fs = fs .. 'style[create;bgcolor=green]'

        return fs
    end,

    on_close = function(meta, player, fields)

        local name = player:get_player_name()

        -- FIELDS INPUTS

        if fields.quit == 'true' then
            destroy_form(name, minetest.FORMSPEC_SIGEXIT)
        end

    end

}

--------------------------------------------------------------------------------
-- export
--------------------------------------------------------------------------------

gigahover.formspecs.fs1 = fs1


-- Case Open Mod for Luanti (Minetest)

-- Registration of sounds for the caseopen mod
dofile(minetest.get_modpath("caseopen") .. "/sounds.lua")


local sound_path = minetest.get_modpath("caseopen") .. "/sound/case_open.ogg"
if not io.open(sound_path, "r") then
    minetest.log("warning", "[caseopen] Audio Error: " .. sound_path)
end

local case_items = {
    {name = "default:diamond", chance = 1},
    {name = "default:gold_ingot", chance = 5},
    {name = "default:steel_ingot", chance = 10},
    {name = "default:apple", chance = 20},
    {name = "default:stick", chance = 64},
}

local COOLDOWN = 5
local player_cooldowns = {}

local visible_cells = 12 
local gui_width = 14
local gui_height = 6

local function can_open_case(playername)
    local now = minetest.get_gametime()
    if player_cooldowns[playername] and now - player_cooldowns[playername] < COOLDOWN then
        return false, COOLDOWN - (now - player_cooldowns[playername])
    end
    player_cooldowns[playername] = now
    return true
end

local function get_random_item()
    local total = 0
    for _, item in ipairs(case_items) do
        total = total + item.chance
    end
    local rnd = math.random(1, total)
    local acc = 0
    for _, item in ipairs(case_items) do
        acc = acc + item.chance
        if rnd <= acc then
            return item.name
        end
    end
    return case_items[#case_items].name
end

-- Keeping items in random order for each player
local player_item_orders = {}

-- Function to shuffle items in random order
local function shuffle_items(items)
    local shuffled = {}
    for i, item in ipairs(items) do
        shuffled[i] = {name = item.name, chance = item.chance}
    end
    
    -- Fisher-Yates mixing algorithm
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    
    return shuffled
end

local function show_case_formspec(playername, rolling, progress, won_item_name)
    local items_str = ""
    -- Create or get a random order of items for the player
    if not player_item_orders[playername] or not rolling then
        -- Sort items by drop chance (from rare to common)
        local sorted_items = {}
        for i, item in ipairs(case_items) do
            sorted_items[i] = {name = item.name, chance = item.chance}
        end
        table.sort(sorted_items, function(a, b) return a.chance < b.chance end)
        -- We create a tape taking into account the chances of falling out
        local weighted_items = {}
        for i, item in ipairs(sorted_items) do
            local count = math.max(1, math.floor(item.chance / 5))
            for j = 1, count do
                table.insert(weighted_items, {name = item.name, chance = item.chance})
            end
        end
        -- Mixing objects
        player_item_orders[playername] = shuffle_items(weighted_items)
    end
    local items = player_item_orders[playername]

    local cell_frames = ""
    local cell_size = 0.9
    local cell_y = 2.1
    for i = 0, visible_cells-1 do
        local x = i + 1.1 + (1-cell_size)/2
        cell_frames = cell_frames .. "box[" .. x .. "," .. cell_y .. ";" .. cell_size .. "," .. cell_size .. ";#888888]box[" .. x .. "," .. cell_y .. ";" .. cell_size .. "," .. cell_size .. ";#CCCCCC88]"
    end
    local center_x = math.floor(visible_cells/2) + 1.1
    local center_highlight = "box["..center_x..",2;1,1;#FF0000]"
    local center_line = "box["..(center_x+0.45)..",2;0.1,1;#888888]"
    local offset = rolling and progress or 0
    for i, item in ipairs(items) do
        local x_pos = ((i-1) - offset) % #items
        if x_pos >= 0 and x_pos < visible_cells then
            local x = x_pos + 1.1 + (1-cell_size)/2
            if math.floor(x_pos) == math.floor(visible_cells/2) then
                items_str = items_str .. "box["..center_x..",2;1,1;#FFFFFF88]item_image["..center_x..",2;1,1;"..item.name.."]"
            else
                items_str = items_str .. "box["..x..","..cell_y..";"..cell_size..","..cell_size..";#CCCCCC88]item_image["..x..","..cell_y..";"..cell_size..","..cell_size..";"..item.name.."]"
            end
        end
    end
    local arrow = "image["..center_x..",1;1,0.8;case_item.png]"
    local btn = rolling and "" or "button["..(center_x-0.2)..",4.5;4,1;roll;Roll]"
    local info_text = ""
    if not rolling then
        info_text = "label[1,5.5;Rare items drop less often! ///by Saiko]"
    end
    minetest.show_formspec(playername, "caseopen:case",
        "size["..gui_width..","..gui_height.."]" ..
        cell_frames ..
        center_highlight ..
        center_line ..
        items_str ..
        arrow ..
        btn ..
        info_text
    )
end

minetest.register_craftitem("caseopen:case", {
    description = "Case",
    inventory_image = "case_item.png",
    on_use = function(itemstack, user)
        local name = user:get_player_name()
        show_case_formspec(name, false, 0, nil)
        return itemstack
    end,
    stack_max = 99,
})

minetest.register_node("caseopen:black_block", {
    description = "Black Block case",
    tiles = {"case.png"},
    groups = {cracky=3},
    on_rightclick = function(pos, node, clicker)
        local name = clicker:get_player_name()
        show_case_formspec(name, false, 0, nil)
    end,
})

minetest.register_craft({
    output = "caseopen:case",
    recipe = {
        {"default:steel_ingot", "default:gold_ingot", "default:steel_ingot"},
        {"default:gold_ingot", "default:diamond", "default:gold_ingot"},
        {"default:steel_ingot", "default:gold_ingot", "default:steel_ingot"},
    },
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "caseopen:case" then return end
    local name = player:get_player_name()
    
    -- Closing a form when the exit button is clicked
    if fields.quit then
        return
    end
    
    if fields.roll then
        local can_open, left = can_open_case(name)
        if not can_open then
            minetest.chat_send_player(name, "Please wait "..left.." seconds before opening the case again.")
            return
        end
        
        -- We check the presence of the case in the inventory and remove it
        local inv = player:get_inventory()
        local case_stack = ItemStack("caseopen:case")
        
        if not inv:contains_item("main", case_stack) then
            minetest.chat_send_player(name, "You don't have a case to open!   ///by Saiko")
            return
        end
        
        -- We remove the case from the inventory
        inv:remove_item("main", case_stack)
        
        -- Determine the winning item in advance to synchronize with the animation
        local won_item = get_random_item()
        
        -- Run the scroll animation for 5 seconds (increase the time for a smoother animation)
        local total_animation_time = 5.0 -- Total animation time in seconds
        local animation_steps = 100 -- Number of animation steps (20 steps per second)
        local step_delay = total_animation_time / animation_steps -- Delay between steps
        
        -- Generate a fixed order of objects for animation
        local items_order = {}
        for i, item in ipairs(case_items) do
            for j = 1, item.chance do
                table.insert(items_order, {name = item.name, chance = item.chance})
            end
        end
        -- We shuffle the order only once per player.
        if not player_item_orders then player_item_orders = {} end
        if not player_item_orders[name] then
            local shuffled = {}
            for i = 1, #items_order do shuffled[i] = items_order[i] end
            for i = #shuffled, 2, -1 do
                local j = math.random(1, i)
                shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
            end
            player_item_orders[name] = shuffled
        end
        local order = player_item_orders[name]
        -- We determine the winning item in advance
        local won_item = get_random_item()
        -- Finding the position of the winning item
        local won_item_position = -1
        for i, item in ipairs(order) do
            if item.name == won_item then
                won_item_position = i
                break
            end
        end
        if won_item_position == -1 then
            won_item_position = math.random(1, #order)
            table.insert(order, won_item_position, {name = won_item, chance = 1})
        end
        -- Animation: only offset, order does not change
        local center_index = math.floor(visible_cells/2) + 1
        local final_offset = won_item_position - center_index
        local full_rotations = math.random(4, 6)
        local total_scroll_distance = final_offset + (full_rotations * #order)
        for i=1, animation_steps do
            minetest.after(i*step_delay, function()
                local progress_factor = i / animation_steps
                -- Using the ease-out cubic function for smooth deceleration
                local eased_progress = 1 - math.pow(1 - progress_factor, 3)
                local current_offset = (1 - eased_progress) * (total_scroll_distance) + eased_progress * final_offset
                if i == animation_steps then
                    current_offset = final_offset
                end
                show_case_formspec(name, true, current_offset, won_item)
            end)
        end
        
        -- End of animation and item delivery
        minetest.after(total_animation_time + 0.3, function()
            -- Win Final Sound (win.ogg)
            -- Remove old audio file check
            dofile(minetest.get_modpath("caseopen") .. "/sounds.lua")
            
            -- Update sound calls in animation
            if minetest.registered_sounds["caseopen_win"] then
                minetest.sound_play({name = "caseopen_win", gain = 1.0}, {to_player = name})
            end
            if minetest.registered_sounds["caseopen_case_open"] then
                minetest.sound_play({name = "caseopen_case_open", gain = 0.9}, {to_player = name})
            end
            inv:add_item("main", won_item)
            minetest.chat_send_player(name, "Your reward: "..minetest.registered_items[won_item].description)
            minetest.close_formspec(name, "caseopen:case")
        end)
    end
end)
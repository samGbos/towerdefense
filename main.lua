io.stdout:setvbuf("no")
local push = require "push"
local gameWidth, gameHeight = 1280, 800 --fixed game resolution
local windowWidth, windowHeight = love.window.getDesktopDimensions()
print(string.format("ww %s, wh %s", windowWidth, windowHeight))
push:setupScreen(gameWidth, gameHeight, windowWidth, windowHeight, { fullscreen = true })

local fps = 0;

local function read_file(path)
    local file = io.open(path, "rb") -- r read mode and b binary mode
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end


function love.load(arg)

    if arg and arg[#arg] == "-debug" then require("mobdebug").start() end
    local lunajson = require 'lunajson'


    local map_raw = read_file("maps/map.json")
    local map = lunajson.decode(map_raw)

    waves = map.waves
    cur_wave = 1
    is_wave_ongoing = false


    local creeps_raw = read_file("creeps.json")
    creep_types = lunajson.decode(creeps_raw)
    cur_creeps = {}
    path = map.path
    gold = map.starting_gold
    available_towers = map.towers

    local towers_raw = read_file("towers.json")
    tower_types = lunajson.decode(towers_raw)


    fired_shots = {}
    --    success = love.window.setFullscreen(true)
end

function love.keyreleased(key)
    if (key == "space" and not is_wave_ongoing) then
        start_next_wave()
    end
end

function finish_wave()
    cur_wave = cur_wave + 1

    is_wave_ongoing = false
end

function start_next_wave()

    cur_creeps = {}
    for _, creep_name in pairs(waves[cur_wave].creeps) do
        print(string.format("Create creep %s", creep_name))
        local creep_ref = creep_types[creep_name]
        local creep = {}
        -- Start the creep way off the map until they come in
        creep.x = -800
        creep.y = -800
        creep.damage = creep_ref.damage
        creep.health = creep_ref.health
        creep.speed = creep_ref.speed
        table.insert(cur_creeps, creep)
    end

    wave_start_time = love.timer.getTime()
    is_wave_ongoing = true
    print("Started wave")
end

function love.mousepressed(x, y, button, istouch, presses)
    --    shoot(x, y)
end

function love.update(dt)

    fps = 1 / dt;

    local remCreep = {}
    local remShot = {}

    -- update the shots
    for i, v in ipairs(fired_shots) do
        -- move them up up up
        v.y = v.y + v.dy * dt
        v.x = v.x + v.dx * dt

        -- mark shots that are not visible for removal
        if v.y < 0 or v.y > love.graphics.getHeight() or v.x < 0 or v.x > love.graphics.getWidth() then
            table.insert(remShot, i)
        end

        -- check for collision with enemies
        for ii, vv in ipairs(cur_creeps) do
            if CheckCollision(v.x, v.y, 2, 5, vv.x, vv.y, vv.width, vv.height) then
                -- mark that enemy for removal
                table.insert(remCreep, ii)
                -- mark the shot to be removed
                table.insert(remShot, i)
            end
        end
    end

    if is_wave_ongoing then
        local time_since_wave_start = love.timer.getTime() - wave_start_time
        local DELAY_PER_CREEP = 1
        -- update the creeps
        for i, creep in ipairs(cur_creeps) do

            if creep.x < 0 and i * DELAY_PER_CREEP < time_since_wave_start then
                print(string.format("Put %d on map", i))
                -- Put the creep on the map
                creep.x = path[1].x
                creep.y = path[1].y
                creep.next_path_idx = 2
            elseif creep.x >= 0 then
                -- Creep is already on map, move it
                local next_path_point = path[creep.next_path_idx]

                -- For now, creeps can only go in cardinal directions
                -- Creeps lose a tiny amount of speed rounding corners because we
                -- snap to the grid once we reach the next path point
                if next_path_point.y - creep.y < 0 then
                    -- Going up
                    creep.y = math.max(creep.y + creep.speed * dt, next_path_point.y)
                elseif next_path_point.y - creep.y > 0 then
                    -- Going down
                    creep.y = math.min(creep.y + creep.speed * dt, next_path_point.y)
                elseif next_path_point.x - creep.x > 0 then
                    -- Going right
                    creep.x = math.min(creep.x + creep.speed * dt, next_path_point.x)
                else
                    -- Going left
                    creep.x = math.max(creep.x + creep.speed * dt, next_path_point.x)
                end

                if creep.x == next_path_point.x and creep.y == next_path_point.y then
                    creep.next_path_idx = creep.next_path_idx + 1
                end
            end
        end

        -- remove the marked enemies
        for i, v in ipairs(remCreep) do
            table.remove(cur_creeps, v)
        end
        -- remove the marked enemies
        for i, v in ipairs(remShot) do
            table.remove(fired_shots, v)
        end
    end
end

function love.draw()
    push:start()

    -- let's draw a background
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.rectangle("fill", 0, 0, 1280, 800)

    -- let's draw our heros shots
    --    love.graphics.setColor(255, 255, 255, 255)
    --    for i, v in ipairs(hero.shots) do
    --        love.graphics.circle("fill", v.x, v.y, 4)
    --    end

    -- let's draw our creeps
    love.graphics.setColor(0, 255, 255, 255)
    for i, creep in ipairs(cur_creeps) do
        love.graphics.rectangle("fill", creep.x, creep.y, 32, 32)
    end

    drawControlPanel()
    drawFPS()

    push:finish()
end

function drawControlPanel()
    love.graphics.setColor(127, 127, 0, 255)
    local panel_width = 240;
    local panel_start = gameWidth - panel_width;
    love.graphics.rectangle("fill", panel_start, 0, 240, 800)

    --  draw gold
    love.graphics.setColor(0, 0, 0, 255)
    love.graphics.print(string.format("Gold: %.1f", gold), panel_start+8, 0)

    -- Draw available towers
    local towers_start_y = 120;
    for i, tower in ipairs(available_towers) do
        local tower_center_x = panel_start + (panel_width / 2)
        local tower_center_y = towers_start_y + (i - 1) * panel_width + panel_width/2
        love.graphics.setColor(0, 127, 0, 255)
        love.graphics.circle("fill", tower_center_x, tower_center_y, panel_width/2)
        love.graphics.setColor(0, 0, 0, 255)
        love.graphics.print("hello", tower_center_x, tower_center_y)
        love.graphics.print(tower, tower_center_x, tower_center_y+50)
    end
end

function drawFPS()
    love.graphics.setColor(0, 0, 0, 255)
    love.graphics.print(string.format("FPS: %.1f", fps), 0, 0)
end

function shoot(x, y)
    local shot = {}
    shot.x = hero.x
    shot.y = hero.y

    local bulletSpeed = 300
    local scale = math.sqrt(((x - hero.x) * (x - hero.x) + (y - hero.y) * (y - hero.y)) / (bulletSpeed * bulletSpeed))

    shot.dx = (x - hero.x) / scale
    shot.dy = (y - hero.y) / scale
    table.insert(hero.shots, shot)
end

-- Collision detection function.
-- Checks if a and b overlap.
-- w and h mean width and height.
function CheckCollision(ax1, ay1, aw, ah, bx1, by1, bw, bh)
    local ax2, ay2, bx2, by2 = ax1 + aw, ay1 + ah, bx1 + bw, by1 + bh
    return ax1 < bx2 and ax2 > bx1 and ay1 < by2 and ay2 > by1
end

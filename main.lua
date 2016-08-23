require "slam"
vector = require "hump.vector"
Timer = require "hump.timer"
Camera = require "hump.camera"

-- Converts HSL to RGB. (input and output range: 0 - 255)
function HSL(h, s, l, a)
    if s<=0 then return l,l,l,a end
    h, s, l = h/256*6, s/255, l/255
    local c = (1-math.abs(2*l-1))*s
    local x = (1-math.abs(h%2-1))*c
    local m,r,g,b = (l-.5*c), 0,0,0
    if h < 1     then r,g,b = c,x,0
    elseif h < 2 then r,g,b = x,c,0
    elseif h < 3 then r,g,b = 0,c,x
    elseif h < 4 then r,g,b = 0,x,c
    elseif h < 5 then r,g,b = x,0,c
    else              r,g,b = c,0,x
    end return (r+m)*255,(g+m)*255,(b+m)*255,a
end

function lerp(a, b, t)
    return a + t*(b-a)
end

function love.load()
    images = {}
    for i,filename in pairs(love.filesystem.getDirectoryItems("images")) do
        images[filename:sub(1,-5)] = love.graphics.newImage("images/"..filename)
    end

    sounds = {}
    for i,filename in pairs(love.filesystem.getDirectoryItems("sounds")) do
        sounds[filename:sub(1,-5)] = love.audio.newSource("sounds/"..filename, "static")
    end

    music = {}
    for i,filename in pairs(love.filesystem.getDirectoryItems("music")) do
        music[filename:sub(1,-5)] = love.audio.newSource("music/"..filename)
        music[filename:sub(1,-5)]:setLooping(true)
    end

    fonts = {}
    for i,filename in pairs(love.filesystem.getDirectoryItems("fonts")) do
        fonts[filename:sub(1,-5)] = {}
        for size = 100,1000,100 do
            fonts[filename:sub(1,-5)][size] = love.graphics.newFont("fonts/"..filename, size)
        end
    end

    --love.audio.play(music.fushing)

    camera = Camera(300, 300)
    camera.smoother = Camera.smooth.damped(3)

    --font = love.graphics.newFont(80)
    love.graphics.setFont(fonts.lobster[200])

    pos = vector(300, 300)
    dir = vector(1, 0)
    speed = 0

    trail = {}

    mouse = vector(0,0)

    bunnies = {}
    for i = 1,1 do
        table.insert(bunnies,{pos = vector(love.math.random(0,2000),love.math.random(0,1000))})
    end

    color = 0

    ps = love.graphics.newParticleSystem(images.bunny, 20)
    ps:setParticleLifetime(1, 3) -- Particles live at least 2s and at most 5s.
    ps:setEmissionRate(10)
    ps:setSizes(0,1)
    --ps:setSizeVariation(1)
    ps:setLinearAcceleration(-40, -40, 40, 40) -- Random movement in all directions.
    ps:setColors(255, 255, 255, 255, 255, 255, 255, 0) -- Fade to transparency.

    --love.window.setMode(800,600)
    love.window.setFullscreen(true)
end

function love.draw()
    camera:attach()

    for i,bunny in pairs(bunnies) do
        love.graphics.draw(images.bunny, bunny.pos.x, bunny.pos.y)
    end

    love.graphics.setColor(HSL(color,255,100))
    love.graphics.print('Hello World!', 400, 300)
    love.graphics.setColor(255,255,255)

    r = math.atan2(dir.y, dir.x)
    love.graphics.draw(images.car, pos.x, pos.y, r, 0.3, 0.3, 300, 200)

    love.graphics.draw(ps, 0, 0)

    for i,p in ipairs(trail) do
        if trail[i+1] then
            love.graphics.line(p.x, p.y, trail[i+1].x, trail[i+1].y)
        end
    end

    camera:detach()
end

function love.update(dt)
    Timer.update(dt)
    ps:update(dt)

    color = color + dt*100

    if love.keyboard.isDown("up") then
        speed = speed+20*dt
    end
    if love.keyboard.isDown("down") then
        speed = speed-20*dt
    end
    if love.keyboard.isDown("left") then
        dir:rotateInplace(-3*dt)
    end
    if love.keyboard.isDown("right") then
        dir:rotateInplace(3*dt)
    end

    pos_tmp = pos + speed*dt*60*dir
    pos.x = pos_tmp.x
    pos.y = pos_tmp.y
    speed = 0.98*speed

    table.insert(trail, pos:clone())

    ps:setPosition(pos.x, pos.y)
    d = 500

    cx, cy = camera:position()
    cp = vector(cx, cy)
    ccp = lerp(cp, pos, 2*dt)
    camera:lookAt(ccp.x, ccp.y)
    --camera:lockWindow(pos.x, pos.y, d, love.graphics.getWidth()-d, d, love.graphics.getHeight()-d)
    --camera:zoomTo(1-speed/50)

    for i,bunny in pairs(bunnies) do
        bunny.pos.x = bunny.pos.x + love.math.random(-10,10)
        bunny.pos.y = bunny.pos.y + love.math.random(-10,10)
    end

    x, y = camera:cameraCoords(mouse.x, mouse.y)
    love.mouse.setPosition(x,y)
end

function love.keypressed(key)
    if key == "escape" then
        love.window.setFullscreen(false)
        love.timer.sleep(0.1)
        love.event.quit()
    end
end

function love.mousepressed(x, y, button)
    x,y = camera:mousePosition()
    Timer.tween(1, pos, {x = x, y = y}, "out-elastic")
    sounds.bloop:play()
end

function love.mousemoved(x, y, dx, dy)
    mouse.x, mouse.y = camera:worldCoords(x,y)
end

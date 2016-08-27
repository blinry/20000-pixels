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

function table.slice(tbl, first, last, step)
    local sliced = {}

    for i = first or 1, last or #tbl, step or 1 do
        sliced[#sliced+1] = tbl[i]
    end

    return sliced
end

function lerp(a, b, t)
    return a + t*(b-a)
end

function worldCoords(camera, x1, y1, x2, y2, x3, y3, x4, y4)
    a1, b1 = camera:worldCoords(x1, y1)
    a2, b2 = camera:worldCoords(x2, y2)
    a3, b3 = camera:worldCoords(x3, y3)
    a4, b4 = camera:worldCoords(x4, y4)
    return a1, b1, a2, b2, a3, b3, a4, b4
end

function cameraCoords(camera, x1, y1, x2, y2, x3, y3, x4, y4)
    a1, b1 = camera:cameraCoords(x1, y1)
    if x2 then
        a2, b2 = camera:cameraCoords(x2, y2)
    end
    if x3 then
        a3, b3 = camera:cameraCoords(x3, y3)
    end
    if x4 then
        a4, b4 = camera:cameraCoords(x4, y4)
    end
    return a1, b1, a2, b2, a3, b3, a4, b4
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
        for size = 50,200,50 do
            fonts[filename:sub(1,-5)][size] = love.graphics.newFont("fonts/"..filename, size)
        end
    end

    love.physics.setMeter(100)
    world = love.physics.newWorld(0, 0, true)

    ship = {}
    ship.body = love.physics.newBody(world, 0, 0, "dynamic")
    ship.shape = love.physics.newRectangleShape(0, 50, 100, 200)
    ship.fixture = love.physics.newFixture(ship.body, ship.shape)
    ship.body:setInertia(100000)

    sail = 0
    rudder = 0
    flip = 1

    islands = {}
    for i = 1,10 do
        x = love.math.random(-2000, 2000)
        y = love.math.random(-2000, 2000)
        table.insert(islands, {x = x, y = y})
        island = {}
        island.body = love.physics.newBody(world, x, y)
        island.shape = love.physics.newCircleShape(250)
        island.fixture = love.physics.newFixture(island.body, island.shape)
    end


    --love.audio.play(music.fushing)

    camera = Camera(300, 300)
    camera.smoother = Camera.smooth.damped(3)

    love.graphics.setFont(fonts.lobster[50])

    trail = {}

    --ps = love.graphics.newParticleSystem(images.bunny, 20)
    --ps:setParticleLifetime(1, 3) -- Particles live at least 2s and at most 5s.
    --ps:setEmissionRate(10)
    --ps:setSizes(0,1)
    ----ps:setSizeVariation(1)
    --ps:setLinearAcceleration(-40, -40, 40, 40) -- Random movement in all directions.
    --ps:setColors(255, 255, 255, 255, 255, 255, 255, 0) -- Fade to transparency.
end

function love.update(dt)
    Timer.update(dt)
    --ps:update(dt)
    world:update(dt)

    speed = vector(ship.body:getLinearVelocity())

    if love.keyboard.isDown("right")or love.keyboard.isDown("d")then
        if rudder > -math.pi/6 then
            rudder = rudder-dt*2
        end
    end
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        if rudder < math.pi/6 then
            rudder = rudder+dt*2
        end
    end

    --if love.keyboard.isDown("d") then
    --    if sail > -math.pi/2 then
    --        sail = sail-dt*2
    --    end
    --end
    --if love.keyboard.isDown("a") then
    --    if sail < math.pi/2 then
    --        sail = sail+dt*2
    --    end
    --end

    while sail > math.pi do
        sail = sail - 2*math.pi
    end
    while sail < -math.pi do
        sail = sail + 2*math.pi
    end

    wind = vector(0, -10)
    relativewind = wind - speed/20

    forward = vector(math.cos(ship.body:getAngle()-math.pi/2), math.sin(ship.body:getAngle()-math.pi/2))

    abssail = sail+ship.body:getAngle()+math.pi/2
    abswind = math.atan2(wind.y, wind.x)
    ang = abswind - abssail

    sailvector = vector(math.cos(sail+ship.body:getAngle()+math.pi/2)*50, math.sin(sail+ship.body:getAngle()+math.pi/2)*50)

    while ang > math.pi do
        ang = ang - 2*math.pi
    end
    while ang < -math.pi do
        ang = ang + 2*math.pi
    end

    if ang > 0 then
        forcedir = sailvector:rotated(math.pi/2):normalized()
        flip = -1
    else
        forcedir = sailvector:rotated(-math.pi/2):normalized()
        flip = 1
    end

    forceamount = math.abs(sailvector:projectOn(relativewind:rotated(math.pi/2)):len())*relativewind:len()
    force = forceamount*forcedir
    forwardforce = force:projectOn(forward)

    x, y = ship.body:getWorldPoints(0, 0)
    ship.body:applyForce(forwardforce.x, forwardforce.y, x, y)

    -- damping
    x, y = ship.body:getLinearVelocity()
    ship.body:applyForce(-x, -y)
    v = ship.body:getAngularVelocity()
    ship.body:applyTorque(-100000*v)

    ship.body:applyTorque(-rudder*1000*speed:len())

    x, y = ship.body:getWorldPoints(0, 0)
    for i,island in ipairs(islands) do
        if vector(island.x, island.y):dist(vector(x, y)) < 300 then
            --table.remove(islands, i)
        end
    end

    mouse = vector(camera:worldCoords(love.mouse.getPosition()))
    d = vector(x, y) - mouse
    sail = math.atan2(d.y, d.x) - ship.body:getAngle() + math.pi/2

    --table.insert(trail, pos:clone())
    --trail = table.slice(trail, #trail-100, #trail)

    --ps:setPosition(pos.x, pos.y)

    --cx, cy = camera:position()
    --cp = vector(cx, cy)
    --ccp = lerp(cp, pos, 2*dt)
    x, y = ship.body:getPosition()
    camera:lookAt(x, y)
end

function love.keypressed(key)
    if key == "escape" then
        love.window.setFullscreen(false)
        love.timer.sleep(0.1)
        love.event.quit()
    end
end

function love.draw()
    camera:attach()

    love.graphics.setColor(255,255,255)
    for x = -10,10 do
        for y = -10,10 do
            love.graphics.draw(images.ocean, images.ocean:getWidth()*x, images.ocean:getHeight()*y)
        end
    end

    x, y = ship.body:getWorldPoints(0, 150)
    love.graphics.draw(images.rudder, x, y, rudder+ship.body:getAngle(), 0.3, 0.3, images.rudder:getWidth()/2, 0)

    x, y = ship.body:getPosition()

    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(images.ship, x, y, ship.body:getAngle(), 1, 1, images.ship:getWidth()/2, images.ship:getHeight()/2.5)

    love.graphics.setColor(255, 255, 255)
    --love.graphics.line(x, y, x+sailvector.x, y+sailvector.y)
    love.graphics.draw(images.sail, x, y, abssail-math.pi/2, flip*(0.5+force:len()/1000), 1, 0, 0)

    for i,island in ipairs(islands) do
        --love.graphics.rectangle("fill", island.x, island.y, 200, 200)
        love.graphics.draw(images.island, island.x, island.y, 0, 1, 1, images.island:getWidth()/2, images.island:getHeight()/2)
    end

    love.graphics.setColor(0, 255, 0)
    love.graphics.line(x, y, x+forwardforce.x, y+forwardforce.y)

    --love.graphics.setColor(0, 0, 255)
    --love.graphics.line(x, y, x+force.x, y+force.y)

    --love.graphics.draw(ps, 0, 0)

    --for i,p in ipairs(trail) do
    --    if trail[i+1] then
    --        love.graphics.setLineWidth(i)
    --        love.graphics.setColor(HSL(i*3,255,i))
    --        love.graphics.line(p.x, p.y, trail[i+1].x, trail[i+1].y)
    --    end
    --end

    camera:detach()

    love.graphics.circle("fill", 200, 200, 200, 64)

    for i,island in ipairs(islands) do
        v = vector(island.x, island.y) - vector(ship.body:getPosition())
        p = vector(200, 200) + v:normalized()*200
        d = v:len()
        love.graphics.setColor(255, 0, 0)
        love.graphics.circle("fill", p.x, p.y, 30-1/100*d, 32)
    end
end


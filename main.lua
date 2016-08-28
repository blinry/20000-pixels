require "slam"
vector = require "hump.vector"
Timer = require "hump.timer"
Camera = require "hump.camera"

savePerPhase = 1
fontsize = 30

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
    end

    return (r+m)*255,(g+m)*255,(b+m)*255,a
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

function makePeople(layer)
    for i = 1,8 do
        repeat
            j = love.math.random(#islands)
        until islands[j].layer == layer

        person = {}
        person.x = islands[j].x + math.random(-100, 100)
        person.y = islands[j].y + math.random(0, 100)
        person.r, person.g, person.b = HSL(math.random(255), 255, 100)
        person.boarded = false
        table.insert(people, person)
    end
end

function say(text, now)
    if now then
        lines = {}
    end
    table.insert(lines, text)
    if now then
        line = text
    end
end

function nextPhase()
    if phase == 0 then
        makePeople(1)
        say("Welcome to a quick sailing lesson!")
        say("You can turn your sail with your mouse.")
        say("And you can steer your rudder with left/right or A/D.")
        say("Finally, you can lift your anchor with up or W. Off you go!")
        say("On the islands to the right, some people are waiting to be rescued!")
        say("Drop your anchor next to an island, and they will board your ship.")
        say("Then bring them back here and drop your anchor.")
    elseif phase == 1 then
        makePeople(2)
        say("Save 5 MORE people to continue!")
    elseif phase == 2 then
        makePeople(3)
        say("Save EVEN 5 MORE people to continue!")
    elseif phase == 3 then
    end

    phase = phase + 1
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
        fonts[filename:sub(1,-5)][fontsize] = love.graphics.newFont("fonts/"..filename, fontsize)
    end

    love.physics.setMeter(100)
    world = love.physics.newWorld(0, 0, true)

    ship = {}
    ship.body = love.physics.newBody(world, 0, 0, "dynamic")
    ship.shape = love.physics.newRectangleShape(0, 75, 100, 150)
    ship.shape2 = love.physics.newCircleShape(0, 0, 100)
    ship.fixture = love.physics.newFixture(ship.body, ship.shape)
    ship.fixture2 = love.physics.newFixture(ship.body, ship.shape2)
    ship.body:setInertia(100000)
    ship.body:setMass(10)
    ship.fixture:setFriction(0)
    ship.fixture2:setFriction(0)
    ship.body:setPosition(500, 0)

    sail = 0
    rudder = 0
    flip = 1
	anchor = 1
    line = "Loading..."
    lines = {}

    wind = vector(0, -80)

    phase = 0

    beach = {}
    beach.body = love.physics.newBody(world, 0, 0)
    beach.shape = love.physics.newRectangleShape(1,20000000)
    beach.fixture = love.physics.newFixture(beach.body, beach.shape)
    beach.fixture:setFriction(0)

    islands = {}
    for l = 1,3 do
        for i = 1,20 do
            island = {}
            island.x = 1000+8000*(l-1)+love.math.random(0, 4000)
            island.y = love.math.random(-6000, 6000)
            island.body = love.physics.newBody(world, island.x, island.y)
            island.shape = love.physics.newCircleShape(150)
            island.fixture = love.physics.newFixture(island.body, island.shape)
            island.fixture:setFriction(0)
            island.layer = l
            table.insert(islands, island)
        end
    end

    people = {}
    saved = 0

    --love.audio.play(music.fushing)

    camera = Camera(300, 300)
    camera.smoother = Camera.smooth.damped(3)
    camera:zoom(0.5)

    love.graphics.setFont(fonts.lobster[fontsize])

    love.graphics.setBackgroundColor(0, 0, 200)

    ps = love.graphics.newParticleSystem(images.wake, 100)
    ps:setParticleLifetime(3, 5) -- Particles live at least 2s and at most 5s.
    ps:setEmissionRate(10)
    ps:setSizes(3,6)
    --ps:setSizeVariation(1)
    --ps:setLinearAcceleration(-40, -40, 40, 40) -- Random movement in all directions.
    ps:setColors(255, 255, 255, 255, 255, 255, 255, 0) -- Fade to transparency.
end

function love.update(dt)
    Timer.update(dt)
    ps:update(dt)
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
	
	if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
		--if ship.body:getLinearVelocity() < 1 then
			timer = love.timer.getTime()
			anchor = 1
		--end
	end
	
	if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
		--if love.timer.getTime() >  timer + 3 then
			anchor = 0
		--end
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

    relativewind = wind - speed/5

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

    forwardforce = forwardforce + forward*700

    x, y = ship.body:getWorldPoints(0, 0)
	
	if anchor == 0 then
		ship.body:applyForce(forwardforce.x, forwardforce.y, x, y)
	end

    -- damping
    x, y = ship.body:getLinearVelocity()
    ship.body:applyForce(-10*x, -10*y)
    v = ship.body:getAngularVelocity()
    ship.body:applyTorque(-100000*v)

    ship.body:applyTorque(-rudder*1000*speed:len())

    x, y = ship.body:getWorldPoints(0, 0)
    for i,island in ipairs(islands) do
        if vector(island.x, island.y):dist(vector(x, y)) < 300 then
            --table.remove(islands, i)
        end
    end

    for i,person in ipairs(people) do
        if vector(person.x, person.y):dist(vector(x, y)) < 300 and anchor == 1 and person.x > 0 then
            person.boarded = true
            person.x = love.math.random(-20, 20)
            person.y = love.math.random(-20, 20)
        end

        if person.boarded and anchor == 1 and x < 200 then
            person.boarded = false
            person.x = love.math.random(-400, -50)
            person.y = y + love.math.random(-100, 100)
            saved = saved + 1
        end
    end
    if phase == 1 and saved >= savePerPhase then
        nextPhase()
    end
    if phase == 2 and saved >= savePerPhase*2 then
        nextPhase()
    end
    if phase == 3 and saved >= savePerPhase*3 then
        nextPhase()
        say("Travel east! Here be dragons!")
    end

    mouse = vector(camera:worldCoords(love.mouse.getPosition()))
    d = vector(x, y) - mouse
    sail = math.atan2(d.y, d.x) - ship.body:getAngle() + math.pi/2

    while sail > math.pi do
        sail = sail - 2*math.pi
    end
    while sail < -math.pi do
        sail = sail + 2*math.pi
    end

    rudder = rudder*0.9

    if true or phase > 1 then
        wind = wind:rotated((love.math.random()-0.5)*0.1)
        wind = wind:normalized()*(100+20*math.sin(love.timer.getTime()/5))
    end

    --table.insert(trail, pos:clone())
    --trail = table.slice(trail, #trail-100, #trail)

    ps:setPosition(ship.body:getWorldPoints(0, 150))

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
    elseif key == "+" then
        camera:zoom(0.5)
    elseif key == "-" then
        camera:zoom(2)
    elseif key == "f11" then
        fs, fstype = love.window.getFullscreen()
        if fs then
            love.window.setFullscreen(false)
            love.window.setMode(1280, 720)
        else
            love.window.setFullscreen(true)
        end
    end
end

function love.mousepressed(x, y, button, touch)
    if phase == 0 then
        nextPhase()
    end
    if #lines > 0 then
        line = lines[1]
        table.remove(lines, 1)
    end
end

function love.draw()
    camera:attach()

    love.graphics.setColor(255,255,255)
    x, y = camera:worldCoords(0, 0)
    xx = math.floor(x/images.ocean:getWidth())
    yy = math.floor(y/images.ocean:getWidth())
    for x = xx-1,xx+6 do
        for y = yy-1,yy+6 do
            love.graphics.draw(images.ocean, images.ocean:getWidth()*x, images.ocean:getHeight()*y)
        end
    end

    love.graphics.setColor(255, 255, 0)
    love.graphics.rectangle("fill", -5000, -10000000, 5000, 20000000)

    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(ps, 0, 0)

    x, y = ship.body:getWorldPoints(0, 150)
    love.graphics.draw(images.rudder, x, y, rudder+ship.body:getAngle(), 0.3, 0.3, images.rudder:getWidth()/2, 0)

    x, y = ship.body:getPosition()

    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(images.ship, x, y, ship.body:getAngle(), 1, 1, images.ship:getWidth()/2, images.ship:getHeight()/2.5)

	if anchor == 1 then
		love.graphics.setColor(255, 255, 255)
		 x, y = ship.body:getWorldPoints(0, 180)
		love.graphics.draw(images.anchor, x, y, ship.body:getAngle(), 1, 1, 0, 0)
	end

	
	for i,island in ipairs(islands) do
        --love.graphics.rectangle("fill", island.x, island.y, 200, 200)
        love.graphics.draw(images.island, island.x, island.y, 0, 1, 1, images.island:getWidth()/2, images.island:getHeight()/2)
    end

    --love.graphics.setColor(0, 255, 0)
    --love.graphics.line(x, y, x+forwardforce.x, y+forwardforce.y)

    --love.graphics.setColor(0, 0, 255)
    --love.graphics.line(x, y, x+force.x, y+force.y)


    --for i,p in ipairs(trail) do
    --    if trail[i+1] then
    --        love.graphics.setLineWidth(i)
    --        love.graphics.setColor(HSL(i*3,255,i))
    --        love.graphics.line(p.x, p.y, trail[i+1].x, trail[i+1].y)
    --    end
    --end

    for i,person in ipairs(people) do
        love.graphics.setColor(person.r, person.g, person.b)
        if person.boarded then
            x, y = ship.body:getWorldPoints(person.x, person.y)
            love.graphics.draw(images.person, x, y, 0, 1, 1, images.person:getWidth()/2, images.person:getWidth()/2)
        else
            love.graphics.draw(images.person, person.x, person.y, 0, 1, 1, images.person:getWidth()/2, images.person:getWidth()/2)
        end
    end
	
    x, y = ship.body:getPosition()
    love.graphics.setColor(255, 255, 255)
    --love.graphics.line(x, y, x+sailvector.x, y+sailvector.y)
    love.graphics.draw(images.sail, x, y, abssail-math.pi/2, flip*(0.5+force:len()/4000), 1, 0, 0)

    --love.graphics.setColor(0, 0, 255)
    love.graphics.draw(images.wind, x-wind.x+sailvector.x*2, y-wind.y+sailvector.y*2, abswind+math.pi/2, wind:len()/40, wind:len()/40, images.wind:getWidth()/2, images.wind:getHeight()/2)

    camera:detach()

    love.graphics.setColor(255, 255, 255)
    ch = 250
    cf = 250/500
    love.graphics.draw(images.compass, 20, 20, 0, cf, cf)

    --for i,island in ipairs(islands) do
    --    v = vector(island.x, island.y) - vector(ship.body:getPosition())
    --    p = vector(250, 250) + v:normalized()*250
    --    d = v:len()
    --    if d > 5000 then
    --        s = 10
    --    else
    --        s = 30-1/250*d
    --    end
    --    love.graphics.draw(images.island, p.x, p.y, 0, s*0.005, s*0.005, images.island:getWidth()/2, images.island:getHeight()/2)
    --end
    for i,person in ipairs(people) do
        if not person.boarded and person.x > 0 then
            v = vector(person.x, person.y) - vector(ship.body:getPosition())
            p = vector(ch/2+20, ch/2+20) + v:normalized()*ch/2
            d = v:len()
            if d > 5000 then
                s = 7
            else
                s = 20-(20-7)/5000*d
            end
            love.graphics.setColor(person.r, person.g, person.b)
            love.graphics.draw(images.person, p.x, p.y, 0, s*0.04, s*0.04, images.person:getWidth()/2, images.person:getHeight()/2)
        end
    end

    --love.graphics.setColor(0, 0, 0)
    --love.graphics.print("People saved: "..saved, 0, 600)

    if phase > 0 then
        if #lines > 0 then
            text = line.." (Click to continue)"
        else
            text = line
        end
        w, h, flags = love.window.getMode()
        border = 20
        love.graphics.setColor(0, 0, 0, 100)
        love.graphics.rectangle("fill", 0, h-2*border-fontsize, w, 2*border+fontsize)
        love.graphics.setColor(255, 255, 255)
        --love.graphics.print(line, border, h-border-fontsize)
        love.graphics.printf(text, border, h-border-fontsize, w-2*border, "center")
    end

    if phase == 0 then
        love.graphics.draw(images.title, 0, 0)
    end
end

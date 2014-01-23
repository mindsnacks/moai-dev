-- east-test.lua

require("Moai")
require("Rectangle")

local Screen = {}
Screen.width = 640
Screen.height = 960

if not MOAIEnvironment.iosRetinaDisplay then
    Screen.width = 320
    Screen.height = 480
end

Screen.stage_width = 320
Screen.stage_height = 480

local off = {}
off.x = Screen.stage_width * -0.5
off.y = Screen.stage_height * -0.5

MOAISim.openWindow("test", Screen.width, Screen.height)

local viewport = MOAIViewport.new()
viewport:setSize(Screen.width, Screen.height)
viewport:setScale(Screen.stage_width, -Screen.stage_height)

local layer = MOAILayer.new()
layer:setViewport( viewport )
MOAISim.pushRenderPass( layer )

local function registerTouchCallback(callback)
    MOAIInputMgr.device.touch:setCallback(
        function ( eventType, idx, x, y, tapCount )
            if eventType == MOAITouchSensor.TOUCH_UP then
                callback( x, y )
            end
        end
    )
end

local function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
                if type(k) ~= 'number' then k = '"'..k..'"' end
                s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

local function newMoaiLogo( width )

    width = width or 32

    local halfWidth = width / 2

    local logoImg = MOAIImage.new()
    logoImg:load( "moai.png" )
    

    local deck = MOAIGfxQuad2D.new()
    deck:setTexture(logoImg, "")
    deck:setRect ( -halfWidth, -halfWidth, halfWidth, halfWidth )
    deck:setUVRect ( 0, 0, 1, 1 )

    local logo = MOAIProp.new()
    logo:setDeck ( deck )
    
    

    return logo
end

local function testEase()
    local logo = newMoaiLogo( 64 )
    
    logo:setLoc ( 0, 0 )

    layer:insertProp( logo )
    
    
    
    ease1 = MOAIEaseType.LINEAR --MOAIEaseLinear.new()
    ease2 = MOAIEaseType.SOFT_EASE_IN --MOAIEaseSimpleIn.new()
    --ease2:setRate ( 4.0 )
    
    ease3 = MOAIEaseType.SMOOTH --MOAIEaseSimpleInOut.new()
    -- ease3:setRate ( 4.0 )
    
    ease4 = MOAIEaseType.SHARP_SMOOTH  --MOAIEaseCustom.new()
    --[[
    ease4:setFunction( 
        function( x )
            local mult = 2
            return math.sin( x * (2 * mult + 0.5 ) * math.pi )
        end
    )
    ]]
    
    local attrYLoc = MOAITransform.ATTR_Y_LOC
    local attrXLoc = MOAITransform.ATTR_X_LOC
    local attrXScl = MOAITransform.ATTR_X_SCL
    local attrZRot = MOAITransform.ATTR_Z_ROT
    
    local curveValue = MOAIAnimCurve.ATTR_VALUE
    local curveTime = MOAIAnimCurve.ATTR_TIME
    local timerTime = MOAITimer.ATTR_TIME
    
    --[[
    local driver = MOAIEaseDriver.new()
    driver:reserveLinks(3)

    driver:setLink(1, logo, attrYLoc, 96, ease1)
    driver:setLink(2, logo, attrXLoc, 128, ease2)
    driver:setLink(3, logo, attrXScl, 2, ease3)

    driver:setSpan( 5 )
    
    --driver:setMode( MOAITimer.PING_PONG )

    --driver:start()
    ]]
    
    local driver = MOAITimer.new()
    driver:setSpan (0,  5 )
    
    ---------- X Location -------------------
    local xLocCurve = MOAIAnimCurve.new()
    xLocCurve:reserveKeys(3)
    xLocCurve:setWrapMode( MOAIAnimCurve.WRAP )
    
    xLocCurve:setKey(1, 0.0, 0, ease2)
    xLocCurve:setKey(2, 1.0, -64, ease2)
    xLocCurve:setKey(3, 2.5, 81, ease2)
    
    --logo:setAttrLink ( attrXLoc, xLocCurve, curveValue )
    --xLocCurve:setAttrLink ( curveTime, driver, timerTime )
    
    
    ---------- Y Location -------------------
    local yLocCurve = MOAIAnimCurve.new()
    yLocCurve:reserveKeys(3)
    yLocCurve:setWrapMode( MOAIAnimCurve.CLAMP )
    
    yLocCurve:setKey(1, 0.63, -64, ease1)
    yLocCurve:setKey(2, 2.2, -96, ease1)
    yLocCurve:setKey(3, 4.0, 159, ease3)
    
    logo:setAttrLink ( attrYLoc, yLocCurve, curveValue )
    yLocCurve:setAttrLink ( curveTime, driver, timerTime )
    
    ---------- X Scale -------------------
    local xSclCurve = MOAIAnimCurve.new()
    xSclCurve:reserveKeys(2)
    --xSclCurve:setWrapMode( MOAIAnimCurve.APPEND )
    
    xSclCurve:setKey(1, 0.0, 1.0, ease4)
    xSclCurve:setKey(2, 5.0, 0.75, ease4)
    
    --logo:setAttrLink ( attrXScl, xSclCurve, curveValue )
    --xSclCurve:setAttrLink ( curveTime, driver, timerTime )
    
    ---------- Z Rotation -------------------
    local zRotCurve = MOAIAnimCurve.new()
    zRotCurve:reserveKeys(3)
    
    zRotCurve:setKey(1, 0.0, 0,   ease1)
    zRotCurve:setKey(2, 2.0, 340, ease3)
    zRotCurve:setKey(3, 5.0, 180, ease3)
    
    --logo:setAttrLink ( attrZRot, zRotCurve, curveValue )
    --zRotCurve:setAttrLink ( curveTime, driver, timerTime )
    
    local onBeginSpan = function(self, timesExecuted)
        print(string.format("Beginning driver's span.  Execution number == %d", timesExecuted) )
    end

    local onEndSpan = function(self, timesExecuted)
        print(string.format("Ending driver's span.  Execution number == %d", timesExecuted) )
    end

    driver:setMode( MOAITimer.LOOP )
    --driver:setListener(MOAITimer.EVENT_TIMER_BEGIN_SPAN, onBeginSpan)
    --driver:setListener(MOAITimer.EVENT_TIMER_END_SPAN, onEndSpan)
    driver:start()

    local paused = false
    local callback = function(x, y)
        if driver:isActive () then
            if paused then
                print("resuming driver")
                paused = false
            else
                print("pausing driver")
                paused = true
            end
            driver:pause ( paused )
        else
            print("starting driver")
            paused = false
            driver:start ()
        end
    end
    
    

    registerTouchCallback ( callback )

end


-- This method uses x and y coordinates from the touch location as the "time" for a MOAIAnimCurveVec 
--    and a MOAIAnimCurve.
local function curveVecTest()

    local easeLinear = MOAIEaseLinear.new()

    local ease1 = MOAIEaseSimpleIn.new()
    ease1:setRate ( 6.0 )

    local ease2 = MOAIEaseSimpleOut.new()
    ease2:setRate ( 2.0 )
    
    local ease3 = MOAIEaseElasticIn.new()
    ease3:setPeriod ( 0.2 )
    
    local ease4 = MOAIEaseBackInOut.new()
    ease4:setOvershoot ( 1.70158 ) -- 1.70158
    
    local ease5 = MOAIEaseSineInOut.new()
    

    local vecCurve = MOAIAnimCurveVec.new()
    vecCurve:setWrapMode( MOAIAnimCurveVec.CLAMP )
    vecCurve:reserveKeys(7)
    vecCurve:setKey(1,  -10,      0,    0, 0, MOAIEaseType.FLAT)
    vecCurve:setKey(2,  20,      0,    0, 0, easeLinear)
    vecCurve:setKey(3, 120,    100, -100, 0, ease1)
    vecCurve:setKey(4, 240,    150,  160, 0, ease2)
    vecCurve:setKey(5, 360,    -62,   45, 0, ease3)
    vecCurve:setKey(6, 460,   -144,  -97, 0, ease4)
    vecCurve:setKey(7, 490,   -144,  -97, 0, MOAIEaseType.FLAT)

    local prop = newMoaiLogo( 32 )
    
    layer:insertProp( prop )
    
    prop:setLoc(0, 0, 0)
    
    local rotCurve = MOAIAnimCurve.new()
    rotCurve:setWrapMode( MOAIAnimCurve.CLAMP )
    rotCurve:reserveKeys(4)
    --easeLinear = MOAIEaseLinear.new()
    
    rotCurve:setKey(1, -10,    -180, easeLinear)
    rotCurve:setKey(2, 20,    -180, easeLinear)
    rotCurve:setKey(3, 300,    180, easeLinear)
    rotCurve:setKey(4, 330,    180, easeLinear)
    
    
    
    local logCount = 0
    
    MOAIInputMgr.device.touch:setCallback(
        function( eventType, idx, x, y, tapCount )

            if (eventType == MOAITouchSensor.TOUCH_MOVE) or (eventType == MOAITouchSensor.TOUCH_DOWN)  then
                local vec = {vecCurve:getValueAtTime( y )}
                
                local rot = rotCurve:getValueAtTime( x )
                
                prop:setLoc(vec[1], vec[2], 0)
                
                prop:setRot(0, 0, rot)
                
                
                logCount = logCount + 1
                if logCount % 5 == 1 then
                    print( string.format("touch at (%.1f, %.1f); vec == {%.4f, %.4f, %.4f}, rot == %.2f", x, y, vec[1], vec[2], vec[3], rot)  )
                end
                
            end
        end
    )
    
    --[[
    MOAIInputMgr.device.touch:setCallback(
        function( eventType, idx, x, y, tapCount )
            if type(tapCount) == "number" then
                print(string.format("eventType == %d, idx == %d, x == %d, y == %d, tapCount == %d", eventType, idx, x, y, tapCount ))
            else
                print(string.format("eventType == %d, idx == %d, x == %.2f, y == %.2f", eventType, idx, x, y))
            end
            
        end
    )
    ]]
end


local function main()
    testEase()
    --curveVecTest()
end

MOAICoroutine.new():run(main)

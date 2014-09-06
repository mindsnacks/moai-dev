-- test/source/MOAIMath/main.lua
-- A Lua-based test for MOAIMath's methods.

local function evaluate ( pass, str )
	if not pass then
		MOAITestMgr.comment ( "FAILED\t" .. str )
		success = false
	end
end

function stage ()
	MOAITestMgr.comment ( 'staging MOAIFoo' )
end

function test ()
    success = true

    MOAITestMgr.beginTest ( 'MOAIMath' )
    local rand = MOAIMath.randSFMT()
    
    evaluate(rand >= 0.0 and rand <= 1.0, "randSFMT return value")

    --------
    local seed = 154
    
    MOAIMath.seedSFMT( seed )
    
    local result1 = MOAIMath.randSFMT()
    
    local result2 = MOAIMath.randSFMT()
    
    evaluate(result1 ~= result2, 'seedSFMT set seed')

    MOAIMath.seedSFMT( seed )
    
    local result2 = MOAIMath.randSFMT()
    
    evaluate(result1 == result2, 'seedSFMT reset state')

    --------
    -- pointsForBezierCurve
    local x0 = 0.0
    local y0 = 0.0
    local x1 = 1.0
    local y1 = 0.0
    local cx0 = 0.0
    local cy0 = 1.0
    local cx1 = 1.0
    local cy1 = 1.0
    local subDiv = 8
    
    local curvePoints, arraySize = MOAIMath.pointsForBezierCurve(x0, y0, x1, y1, cx0, cy0, cx1, cy1, subDiv)
    
    -- arraySize test
    local expectedSize = 18 -- 2 * 8 + 2
    evaluate(arraySize == expectedSize, 'pointsForBezierCurve array size')

    -- midpoint test
    local expectedMidpointX = 0.5 -- (1/8) * 0.0 + (3/8) * 0.0 + (3/8) * 1.0 + (3/8) * 1.0
    local expectedMidpointY = 0.75 -- (1/8) * 0.0 + (3/8) * 1.0 + (3/8) * 1.0 + (3/8) * 0.0
    
    

    local midpointX = curvePoints[9]
    local midpointY = curvePoints[10]

    evaluate(midpointX == expectedMidpointX, 'pointsForBezierCurve midpoint x-coordinate (t==0.5)')
    evaluate(midpointY == expectedMidpointY, 'pointsForBezierCurve midpoint y-coordinate (t==0.5)')
    
    -- quarter point test (t = 0.25)
    expectedMidpointX = 0.15625 -- (27/64) * 0.0 + (27/64) * 0.0 + (9/64) * 1.0 + (1/64) * 1.0
    expectedMidpointY = 0.5625 -- (27/64) * 0.0 + (27/64) * 1.0 + (9/64) * 1.0 + (1/64) * 0.0
    
    midpointX = curvePoints[5]
    midpointY = curvePoints[6]
    
    evaluate(midpointX == expectedMidpointX, 'pointsForBezierCurve midpoint x-coordinate (t==0.25)')
    evaluate(midpointY == expectedMidpointY, 'pointsForBezierCurve midpoint y-coordinate (t==0.25)')

    -- three-quarter point test (t = 0.75)
    expectedMidpointX = 0.84375 -- (1/64) * 0.0 + (9/64) * 0.0 + (27/64) * 1.0 + (27/64) * 1.0
    expectedMidpointY = 0.5625 -- (1/64) * 0.0 + (9/64) * 1.0 + (27/64) * 1.0 + (27/64) * 0.0

    midpointX = curvePoints[13]
    midpointY = curvePoints[14]
    
    evaluate(midpointX == expectedMidpointX, 'pointsForBezierCurve midpoint x-coordinate (t==0.75)')
    evaluate(midpointY == expectedMidpointY, 'pointsForBezierCurve midpoint y-coordinate (t==0.75)')


    --------
    -- pointsForCardinalSpline
    local vertices = { 0.0, 0.0, -- p0
                       0.0, 1.0, -- p1
                       1.0, 1.0, -- p2
                       1.0, 0.0 }-- p3
    subDiv = 2
    local tension = 0.0

    curvePoints, arraySize = MOAIMath.pointsForCardinalSpline(vertices, subDiv, tension)
    
    -- arraySize test
    expectedSize = 14 -- (8 - 2) * 2 + 2
    evaluate(arraySize == expectedSize, 'pointsForCardinalSpline array size')
    
    -- midpoint1 test
    expectedMidpointX = -0.0625 
                          -- P1 == p0, P2 == p0,  P3 == p1, P4 == p2
                          -- t == 0.5, s == (1 - tension) / 2 == 0.5;
                          --   s * (-t^3 + 2*t^2 - t) * P1
                          -- + s * (-t^3 + t^2) * P2
                          -- + (2 * t^3 - 3 * t^2 + 1) * P2
                          -- + s * (t^3 - 2*t^2 + t) * P3
                          -- + (-2 * t^3 + 3 * t^2) * P3
                          -- + s * (t^3 - t^2) * P4
                          
                          -- b1 == -1/16 == -0.0625
                          -- b2 == 9/16 == 0.5625
                          -- b3 == 9/16 == 0.5625
                          -- b4 == -1/16 == -0.0625
    expectedMidpointY = 0.5
                        -- b1 * p0y + b2 * p0y + b3 * p1y + b4 * p2y
                        -- -1/16 * 0 + 9/16 * 0 + 9/16 * 1 + -1/16 * 1



    midpointX = curvePoints[3]
    midpointY = curvePoints[4]
    
    evaluate(midpointX == expectedMidpointX, 'pointsForCardinalSpline midpoint 1 x-coordinate (t==0.5)')
    evaluate(midpointY == expectedMidpointY, 'pointsForCardinalSpline midpoint 1 y-coordinate (t==0.5)')
    
    -- midpoint2 test
    expectedMidpointX = 0.5
    -- P1 == p0, P2 == p1, P3 == p2, P4 == p3
    -- b1 * p0x + b2 * p1x + b3 * p2x + b4 * p3x
    -- -1/16 * 0.0 + 9/16 * 0.0 + 9/16 * 1.0 + -1/16 * 1.0

    expectedMidpointY = 1.125
    -- b1 * p0y + b2 * p1y + b3 * p2y + b4 * p3y
    -- -1/16 * 0.0 + 9/16 * 1.0 + 9/16 * 1.0 + -1/16 * 0.0


    midpointX = curvePoints[7]
    midpointY = curvePoints[8]
    
    evaluate(midpointX == expectedMidpointX, 'pointsForBezierCurve midpoint 2 x-coordinate (t==0.5)')
    evaluate(midpointY == expectedMidpointY, 'pointsForBezierCurve midpoint 2 y-coordinate (t==0.5)')
    
    -- midpoint3 test
    expectedMidpointX = 1.0625
    -- P1 == p1, P2 = p2, P3 = p3, P4 = p3
    -- b1 * p1x + b2 * p2x + b3 * p3x + b4 * p3x
    -- -1/16 * 0.0 + 9/16 * 1.0 + 9/16 * 1.0 + -1/16 * 1.0

    expectedMidpointY = 0.5
    -- b1 * p1y + b2 * p2y + b3 * p3y + b4 * p4y
    -- -1/16 * 1.0 + 9/16 * 1.0 + 9/16 * 0.0 + -1/16 * 0.0

    midpointX = curvePoints[11]
    midpointY = curvePoints[12]
    
    evaluate(midpointX == expectedMidpointX, 'pointsForBezierCurve midpoint 3 x-coordinate (t==0.5)')
    evaluate(midpointY == expectedMidpointY, 'pointsForBezierCurve midpoint 3 y-coordinate (t==0.5)')


    --------
    -- pointsForCardinalSplineLoop
    
    vertices = { 0.0, 0.0, -- p0
                 0.0, 1.0, -- p1
                 2.0, 1.0, -- p2
                 1.0, 0.0 }-- p3

    subDiv = 2
    tension = 0.0


    
    curvePoints, arraySize = MOAIMath.pointsForCardinalSplineLoop(vertices, subDiv, tension)
    
    -- array size test
    expectedSize = 16 -- 8 * 2
    evaluate(arraySize == expectedSize, 'pointsForCardinalSplineLoop array size')
    
    -- midpoint1 test
    expectedMidpointX = -0.1875
    -- P1 == p3, P2 = p0, P3 = p1, P4 = p2
    -- b1 * p3x + b2 * p0x + b3 * p1x + b4 * p2x
    -- -1/16 * 1.0 + 9/16 * 0.0 + 9/16 * 0.0 + -1/16 * 2.0


    expectedMidpointY = 0.5
    -- b1 * p3y + b2 * p0y + b3 * p1y + b4 * p2y
    -- -1/16 * 0.0 + 9/16 * 0.0 + 9/16 * 1.0 + -1/16 * 1.0


    midpointX = curvePoints[3]
    midpointY = curvePoints[4]
    
    evaluate(midpointX == expectedMidpointX, 'pointsForBezierCurveLoop midpoint 1 x-coordinate (t==0.5)')
    evaluate(midpointY == expectedMidpointY, 'pointsForBezierCurveLoop midpoint 1 y-coordinate (t==0.5)')
    
    -- midpoint2 test
    expectedMidpointX = 1.0625
    -- P1 == p0, P2 = p1, P3 = p2, P4 = p3
    -- b1 * p0x + b2 * p1x + b3 * p2x + b4 * p3x
    -- -1/16 * 0.0 + 9/16 * 0.0 + 9/16 * 2.0 + -1/16 * 1.0


    expectedMidpointY = 1.125
    -- b1 * p0y + b2 * p1y + b3 * p2y + b4 * p3y
    -- -1/16 * 0.0 + 9/16 * 1.0 + 9/16 * 1.0 + -1/16 * 0.0


    midpointX = curvePoints[7]
    midpointY = curvePoints[8]
    
    evaluate(midpointX == expectedMidpointX, 'pointsForBezierCurveLoop midpoint 2 x-coordinate (t==0.5)')
    evaluate(midpointY == expectedMidpointY, 'pointsForBezierCurveLoop midpoint 2 y-coordinate (t==0.5)')
    
    -- midpoint3 test
    expectedMidpointX = 1.6875
    -- P1 == p1, P2 = p2, P3 = p3, P4 = p0
    -- b1 * p1x + b2 * p2x + b3 * p3x + b4 * p0x
    -- -1/16 * 0.0 + 9/16 * 2.0 + 9/16 * 1.0 + -1/16 * 0.0


    expectedMidpointY = 0.5
    -- b1 * p1y + b2 * p2y + b3 * p3y + b4 * p0y
    -- -1/16 * 1.0 + 9/16 * 1.0 + 9/16 * 0.0 + -1/16 * 0.0


    midpointX = curvePoints[11]
    midpointY = curvePoints[12]
    
    evaluate(midpointX == expectedMidpointX, 'pointsForBezierCurveLoop midpoint 3 x-coordinate (t==0.5)')
    evaluate(midpointY == expectedMidpointY, 'pointsForBezierCurveLoop midpoint 3 y-coordinate (t==0.5)')
    
    -- midpoint4 test
    expectedMidpointX = 0.4375
    -- P1 == p2, P2 = p3, P3 = p0, P4 = p1
    -- b1 * p2x + b2 * p3x + b3 * p0x + b4 * p1x
    -- -1/16 * 2.0 + 9/16 * 1.0 + 9/16 * 0.0 + -1/16 * 0.0


    expectedMidpointY = -0.125
    -- b1 * p2y + b2 * p3y + b3 * p0y + b4 * p1y
    -- -1/16 * 1.0 + 9/16 * 0.0 + 9/16 * 0.0 + -1/16 * 1.0


    midpointX = curvePoints[15]
    midpointY = curvePoints[16]
    
    evaluate(midpointX == expectedMidpointX, 'pointsForBezierCurveLoop midpoint 3 x-coordinate (t==0.5)')
    evaluate(midpointY == expectedMidpointY, 'pointsForBezierCurveLoop midpoint 3 y-coordinate (t==0.5)')

    MOAITestMgr.endTest( success )
end


MOAITestMgr.setStagingFunc ( stage )
MOAITestMgr.setTestFunc ( test )
MOAITestMgr.setFilter ( MOAITestMgr.UTIL )

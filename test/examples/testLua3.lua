-- testLua3.lua

-- This example uses the success() and failure() methods of MOAITestMgr.

function stage()
    print( "In method stage().  No actions taken." )
end

function test()
    print ( "Two sub-tests.  The first one will pass, the second one will fail." )
    MOAITestMgr.beginTest( "testLua3_1" )

    MOAITestMgr.success ( "Passed" )

    MOAITestMgr.endTest( true )



    MOAITestMgr.beginTest ( "testLua3_2" )

    MOAITestMgr.failure ( "Auto-fail", "This test always fails." )

    MOAITestMgr.endTest ( false )

end

MOAITestMgr.setStagingFunc ( stage )
MOAITestMgr.setTestFunc ( test )
MOAITestMgr.setFilter ( MOAITestMgr.SAMPLE )

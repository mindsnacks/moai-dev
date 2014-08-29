-- testLua1.lua

-- Based on moai-dev/test/source/test1/main.lua
-- This test prints some info when in the staging and testing functions.  It always passes.

function stage ()
    print ( "Staging for testLua1.  No actions done." )
end

function test ()
    print ( "in method test()" )

    -- mark beginning of test in log file
    MOAITestMgr.beginTest ( 'testLua1' )
    
    -- print two comments in log file
    MOAITestMgr.comment ( 'this is a comment' )
    MOAITestMgr.comment ( 'this test passed' )
    
    -- mark end of test as having passed
    MOAITestMgr.endTest ( true )
end

print( "Running testLua1.lua" )
MOAITestMgr.setStagingFunc ( stage )
MOAITestMgr.setTestFunc ( test )
MOAITestMgr.setFilter ( MOAITestMgr.SAMPLE )

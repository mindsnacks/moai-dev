-- testLua2.lua

-- This test always fails.  It is based off of moai-dev/test/source/test2/main.lua

function stage ()
    print ( 'In method stage(). No actions taken.' )
end

function test ()
    MOAITestMgr.beginTest ( 'testLua2' )
    MOAITestMgr.comment ( 'this test failed.' )
    MOAITestMgr.endTest ( false )
end

MOAITestMgr.setStagingFunc ( stage )
MOAITestMgr.setTestFunc ( test )
MOAITestMgr.setFilter ( MOAITestMgr.SAMPLE )

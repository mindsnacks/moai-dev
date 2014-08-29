-- test/examples/main.lua
-- Written by Isaac D. Barrett 
-- Last updated 2014-08-29
-- This file features a few ways of calling test files from MOAITestMgr.


local Screen = {}
Screen.width = 640
Screen.height = 960

Screen.stage_width = 320
Screen.stage_height = 480

-- Create a window to allow the user to quit the app running Moai from the menu.
MOAISim.openWindow("test", Screen.width, Screen.height)


-----------------------------------------------------------

-- The root directory string
rootDir = MOAIFileSystem.getWorkingDirectory ()

-- Set to true to run the staging for the tests that need staging.
local doStaging = true

-- Set to true to run the method that runs an individual Lua tests.
local runSingleTest = false

-- Set to true to run the method that runs a list of Lua tests.
local runMultiTest = true

-- Set to true to run the method that runs a list of C++ tests.
local runCppTest = false



-- Change this to the directory where the result log should go.  It should already exist.  One suggestion of where to put the log files is moai-dev .. "tmp/" where moai-dev is the root directory of the Moai SDK.
resultDir = rootDir .. "tmp/"

results = resultDir .. 'results.txt'
resultsDir = resultDir


-- The file to use for filtering tests.  If it's empty, the checkFilter() method of MOAITestMgr when used with a string argument lets all tests run.  Otherwise, that method will only run tests matching at least one of the keywords in the file.  Each keyword in the filter file is on a separate line.
filterFile = resultDir .. 'filter.txt'

-- Set to true to use the filter checking. Set to false to bypass the filter checking.
useFilter = false


-- A method that call a single Lua test at testFile.  The extension must be used for any Lua tests to be run by MOAITestMgr.
function singleTestFile()
    print ("running method singleTestFile().")
    local testFile = "testLua1.lua"

    local testResultFile = resultDir .. string.format("%s_results.txt", testFile)

    if ( not useFilter ) or MOAITestMgr.checkFilter ( testFile ) then
        MOAITestMgr.setResultsFile ( testResultFile )
        print ( string.format("about to run test: %s", testFile) )
        MOAITestMgr.runScript ( testFile )
    else
        print( string.format("test file %s skipped", testFile ) )
    end

    print ("end method singleTestFile().")
end


-- A method that calls multiple Lua tests from the table named files.
function multipleTestFiles()
    print ( "running method multipleTestFiles()." )
    local files = {
        "testLua1.lua",
        "testLua2.lua",
        "testLua3.lua"
    }
    
    for i = 1, #files do
        -- the test to run
        local luaTest = files[i]
        
        -- save the results in a text file with a name that includes the test name.
        local testResultFile = resultDir .. string.format("%s_results.txt", luaTest)

        if ( not useFilter ) or MOAITestMgr.checkFilter ( luaTest ) then

            MOAITestMgr.setResultsFile ( testResultFile )
            print ( string.format("about to run test: %s", luaTest) )
            MOAITestMgr.runScript( luaTest )
        else
            print ( string.format("test skipped: %s", luaTest) )
        end
    end
    
    print ( "end method multipleTestFiles()." )
end


-- A method that calls multiple C++ tests from the table named cppList.  The extension is omitted for C++ tests.
function cppTests()
    local cppList = {
                        "sample",
                        "USQuaternion",
                    }
    
    for i = 1, #cppList do 
        local cppTest = cppList[i]
        local testResultFile = resultDir .. string.format("%s_results.txt", cppTest)
        if ( not useFilter ) or MOAITestMgr.checkFilter ( cppTest ) then

            MOAITestMgr.setResultsFile ( testResultFile )
            print( string.format("about to run test: %s", cppTest) )
            MOAITestMgr.runTest( cppTest )

        else
            print ( string.format("test skipped: %s", cppTest) )
        end

    end

end


-- the top level function
function main()
    print ("running method main().")

    MOAITestMgr.setXmlResultsFile ( resultsDir .. "xml-results.txt" )
    
    if useFilter then
        MOAITestMgr.setFilterFile ( filterFile )
    end

    if runSingleTest then 
        singleTestFile() 
    end

    if runMultiTest then 
        multipleTestFiles() 
    end

    if runCppTest then 
        cppTests() 
    end
    
    MOAITestMgr.finish()
    print ("end method main().")
end

-- The call to the top level function.
main()

-- It could also be called in a coroutine if it makes sense.
-- MOAICoroutine.new():run(main)

#Requires AutoHotkey v2.0
#SingleInstance Force

; Simple test script to check if AutoHotkey is working
try {
    ; Test basic file operations
    FileAppend("Test started: " . A_Now . "`n", "test_log.txt", "UTF-8")
    
    ; Test message box
    MsgBox("AutoHotkey v2 is working! Script will exit in 3 seconds.", "Test Success", 0)
    
    ; Test timer
    SetTimer(() => {
        FileAppend("Timer test: " . A_Now . "`n", "test_log.txt", "UTF-8")
        ExitApp
    }, 3000)
    
} catch as e {
    ; Log any errors
    FileAppend("ERROR: " . e.Message . " at line " . e.Line . "`n", "test_error.txt", "UTF-8")
    MsgBox("Error occurred: " . e.Message, "Test Failed", 4112)
    ExitApp(1)
}
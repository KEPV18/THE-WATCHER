; ============================================================
; MASTER DASHBOARD - AHK v2 (v1.1 - Combined Approach)
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; --- Bootstrap Log: A simple log to confirm the script tried to start ---
try {
    FileAppend("=== BOOTSTRAP START: " . A_Now . " ====`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    FileAppend("Loading modules...`r`n", A_ScriptDir "\last_error.log", "UTF-8")
} catch {
}

; --- Load all modules in the correct, logical order ---
try {
    FileAppend("Loading 01_CoreSettings.ahk...`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    #Include lib\01_CoreSettings.ahk
    FileAppend("Loading 02_Logging.ahk...`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    #Include lib\02_Logging.ahk
    FileAppend("Loading 07_GDIPlus.ahk...`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    #Include lib\07_GDIPlus.ahk           ; GDI+ library
    FileAppend("Loading 04_Helpers.ahk...`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    #Include lib\04_Helpers.ahk           ; Helper functions (including Telegram)
    FileAppend("Loading 08_IntelligentSystem.ahk...`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    #Include lib\08_IntelligentSystem.ahk ; Intelligent coordinate detection and smart monitoring
    FileAppend("Loading 09_ProfileSystem.ahk...`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    #Include lib\09_ProfileSystem.ahk     ; Multi-profile system for different screen configurations
    FileAppend("Loading 03_InitAndSettings.ahk...`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    #Include lib\03_InitAndSettings.ahk   ; Initialization functions that use helpers
    FileAppend("Loading 05_TimersLogic.ahk...`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    #Include lib\05_TimersLogic.ahk       ; Business logic
    FileAppend("Loading 06_DashboardHotkeys.ahk...`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    #Include lib\06_DashboardHotkeys.ahk  ; UI and Hotkeys
    FileAppend("All modules loaded successfully!`r`n", A_ScriptDir "\last_error.log", "UTF-8")
} catch as e {
    FileAppend("MODULE LOAD ERROR: " . e.Message . " at " . e.File . ":" . e.Line . "`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    MsgBox("Failed to load modules: " . e.Message, "Load Error", 4112)
    ExitApp(1)
}

; --- Global Error Handling: Catches runtime errors and sends detailed reports ---
try {
    FileAppend("Checking settings.ini...`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    ; --- Pre-flight Check ---
    if !FileExist(iniFile) {
        FileAppend("CRITICAL: settings.ini not found!`r`n", A_ScriptDir "\last_error.log", "UTF-8")
        MsgBox("CRITICAL ERROR: settings.ini file not found! The script cannot start.", "Configuration Error", 4112)
        ExitApp
    }

    FileAppend("Starting InitializeScript()...`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    ; --- Start the script ---
    InitializeScript()

    FileAppend("Script initialized successfully!`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    Info("Master script loaded and initialized successfully.")
} catch as e {
    ; --- This block runs if a RUNTIME error occurs ---
    FileAppend("RUNTIME ERROR: " . e.Message . " at " . e.File . ":" . e.Line . "`r`n", A_ScriptDir "\last_error.log", "UTF-8")
    
    ; 1. Log the error locally
    try LogError("--- UNHANDLED SCRIPT CRASH ---`n" . "Error: " . e.Message . "`nFile: " . e.File . "`nLine: " . e.Line)

    ; 2. Send a DETAILED error report to Telegram
    try SendTelegramError(e)

    ; 3. Show a message to the user and exit
    MsgBox("A critical runtime error occurred and a detailed report was sent to Telegram.`nScript will now exit.`n`nError: " . e.Message, "Script Crashed", 4112)
    ExitApp(1)
}

; ============================================================
; MASTER DASHBOARD - AHK v2 (v1.1 - Combined Approach)
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; --- Load all modules in the correct, logical order ---
#Include lib\01_CoreSettings.ahk
#Include lib\02_Logging.ahk
#Include lib\07_GDIPlus.ahk           ; GDI+ library
#Include lib\04_Helpers.ahk           ; Helper functions (including Telegram)
#Include lib\08_IntelligentSystem.ahk ; Intelligent coordinate detection and smart monitoring
#Include lib\09_ProfileSystem.ahk     ; Multi-profile system for different screen configurations
#Include lib\03_InitAndSettings.ahk   ; Initialization functions that use helpers
#Include lib\05_TimersLogic.ahk       ; Business logic
#Include lib\06_DashboardHotkeys.ahk  ; UI and Hotkeys

; --- Bootstrap Log: A simple log to confirm the script tried to start ---
try {
    FileAppend("=== BOOTSTRAP START: " . A_Now . " ====`r`n", A_ScriptDir "\last_error.log", "UTF-8")
} catch {
}

; --- Global Error Handling: Catches runtime errors and sends detailed reports ---
try {
    ; --- Pre-flight Check ---
    if !FileExist(iniFile) {
        MsgBox("CRITICAL ERROR: settings.ini file not found! The script cannot start.", "Configuration Error", 4112)
        ExitApp
    }

    ; --- Start the script ---
    InitializeScript()

    Info("Master script loaded and initialized successfully.")
} catch as e {
    ; --- This block runs if a RUNTIME error occurs ---
    ; 1. Log the error locally
    try LogError("--- UNHANDLED SCRIPT CRASH ---`n" . "Error: " . e.Message . "`nFile: " . e.File . "`nLine: " . e.Line)

    ; 2. Send a DETAILED error report to Telegram
    try SendTelegramError(e)

    ; 3. Show a message to the user and exit
    MsgBox("A critical runtime error occurred and a detailed report was sent to Telegram.`nScript will now exit.`n`nError: " . e.Message, "Script Crashed", 4112)
    ExitApp(1)
}

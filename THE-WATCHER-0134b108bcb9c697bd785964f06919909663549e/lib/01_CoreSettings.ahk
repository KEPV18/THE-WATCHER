; ============================================================
; 01_CoreSettings.ahk - Global Variables & Core Settings
; ============================================================

; --- Core AHK Settings ---
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SetDefaultMouseSpeed 0

; --- Global Variables ---
global BOT_TOKEN := "8328100113:AAEEtm8w7Em7eqSVSjq8yiG5nPu7JNBz9Nk"
global CHAT_ID := "5670001305"
global iniFile := A_ScriptDir "\settings.ini"
global SCREENSHOT_DIR := A_ScriptDir "\screenshots"
global ComSpec := A_ComSpec ; Store ComSpec path for performance

; --- Global Maps for State and Settings ---
global SETTINGS := Map()
global STATE := Map()

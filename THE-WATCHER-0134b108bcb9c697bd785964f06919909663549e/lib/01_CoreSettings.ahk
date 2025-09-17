; ============================================================
; 01_CoreSettings.ahk - Global Variables & Core Settings
; ============================================================

; --- Core AHK Settings ---
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SetDefaultMouseSpeed 0

; --- Global Variables ---
; كان هنا BOT_TOKEN/CHAT_ID بقيم صلبة — تم إزالتهما للتحميل من settings.ini/البيئة
; global BOT_TOKEN := "8328100113:AAEEtm8w7Em7eqSVSjq8yiG5nPu7JNBz9Nk"
; global CHAT_ID := "5670001305"

; تهيئة مسارات وملفات الإعدادات أولاً
global iniFile := A_ScriptDir "\settings.ini"
global SCREENSHOT_DIR := A_ScriptDir "\screenshots"
global ComSpec := A_ComSpec ; Store ComSpec path for performance

; قراءة مفاتيح تيليجرام من ملف الإعدادات أو من متغيرات البيئة (للسماح بإخفاء الأسرار)
global BOT_TOKEN := ""
global CHAT_ID := ""
try {
    BOT_TOKEN := IniRead(iniFile, "Telegram", "BotToken", EnvGet("TELEGRAM_BOT_TOKEN"))
    CHAT_ID   := IniRead(iniFile, "Telegram", "ChatId",   EnvGet("TELEGRAM_CHAT_ID"))
} catch {
}

; --- Global Maps for State and Settings ---
global SETTINGS := Map()
global STATE := Map()

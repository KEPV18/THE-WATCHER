; ============================================================
;                      Demo - Ultra-Light Watcher
;      Single File Version (v1.8 - Original Telegram Method)
; ============================================================
; - تم العودة إلى طريقة إرسال Telegram الأصلية (WinHttp المتزامن) لضمان الموثوقية.
; - تمت إضافة تسجيل لحالة استجابة Telegram في ملف السجل.
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================
; 1. الإعدادات الثابتة
; ============================================================
global SETTINGS := Map(
    "FrontlineWinTitle", "Front Line",
    "TargetPixelX", 949, "TargetPixelY", 542, "TargetPixelColor", 0xE9F7FF,
    "RefreshX", 114, "RefreshY", 73,
    "StayOnlineAreaX1", 1155, "StayOnlineAreaY1", 655, "StayOnlineAreaX2", 1300, "StayOnlineAreaY2", 707,
    "FixStep1X", 140, "FixStep1Y", 994,
    "FixStep2X", 156, "FixStep2Y", 845,
    "FixStep3X", 328, "FixStep3Y", 323,
    "TelegramBotToken", "8328100113:AAEEtm8w7Em7eqSVSjq8yiG5nPu7JNBz9Nk",
    "TelegramChatId", "5670001305",
    "UserIdleThreshold", 120000,
    "RefreshInterval", 300000,
    "StayOnlineInterval", 120000,
    "PeriodicFixInterval", 600000,
    "TelegramReportInterval", 600000,
    "PixelCheckInterval", 1000,
    "StartupGracePeriod", 10000,
    "AlarmMuteDuration", 120000
)

; ============================================================
; 2. متغيرات الحالة العامة
; ============================================================
global STATE := Map(
    "isAlarmPlaying", false,
    "frontlineWinId", 0,
    "lastAction", "None",
    "lastActionTime", "",
    "isUserIdle", false,
    "monitoringActive", false,
    "alarmMutedUntil", 0
)

; ============================================================
; 3. نقطة البداية والتهيئة
; ============================================================
Initialize()

Initialize() {
    CoordMode "Pixel", "Screen"
    CoordMode "Mouse", "Screen"
    SetDefaultMouseSpeed 0

    Log("--- Script Initializing ---")
    SendTelegram("✅ **Script Started**`n`nDemo Watcher is now running at " . FormatTime(A_Now, "HH:mm:ss dd-MM-yyyy"))
    SetTimer(FindFrontlineWindow, 1000)
    OnExit(SafeExit)
}

FindFrontlineWindow() {
    winId := WinExist(SETTINGS["FrontlineWinTitle"])
    if (winId) {
        if (STATE["frontlineWinId"] = 0) {
            Log("Front Line window found. ID: " . winId)
            STATE["frontlineWinId"] := winId
            SendTelegram("🟢 **Front Line Window Found**`n`nMonitoring will start after a " . (SETTINGS["StartupGracePeriod"]/1000) . "-second grace period.")
            SetTimer(ActivateMonitoring, -SETTINGS["StartupGracePeriod"])
        }
    } else {
        if (STATE["frontlineWinId"] != 0) {
            Log("Front Line window lost.")
            SendTelegram("🔴 **Front Line Window Lost**`n`nMonitoring paused. Will attempt to relaunch.")
            STATE["frontlineWinId"] := 0
            STATE["monitoringActive"] := false
            SetTimer(MonitorTargetPixel, 0)
            SetTimer(CheckIdleAndAct, 0)
            SetTimer(SendPeriodicReport, 0)
        }
        TryLaunchFrontline()
    }
}

ActivateMonitoring() {
    Log("Grace period ended. Activating full monitoring.")
    STATE["monitoringActive"] := true
    SetTimer(MonitorTargetPixel, SETTINGS["PixelCheckInterval"])
    SetTimer(CheckIdleAndAct, 1000)
    SetTimer(SendPeriodicReport, SETTINGS["TelegramReportInterval"])
}

TryLaunchFrontline() {
    Log("Attempting to launch Front Line shortcut.")
    shortcutPath1 := A_Desktop . "\" . "Front Line" . ".lnk"
    shortcutPath2 := A_DesktopCommon . "\" . "Front Line" . ".lnk"
    if (FileExist(shortcutPath1)) {
        Run(shortcutPath1)
    } else if (FileExist(shortcutPath2)) {
        Run(shortcutPath2)
    }
}

; ============================================================
; 4. المنطق الرئيسي والمؤقتات
; ============================================================
CheckIdleAndAct() {
    if (!STATE["monitoringActive"]) {
        return
    }
    STATE["isUserIdle"] := (A_TimeIdleKeyboard > SETTINGS["UserIdleThreshold"])
    if (!STATE["isUserIdle"]) {
        return
    }
    
    static lastRefresh := A_TickCount, lastStayOnline := A_TickCount, lastPeriodicFix := A_TickCount
    
    if (A_TickCount - lastStayOnline > SETTINGS["StayOnlineInterval"]) {
        PerformStayOnlineClick()
        lastStayOnline := A_TickCount
    }
    if (A_TickCount - lastRefresh > SETTINGS["RefreshInterval"]) {
        PerformRefresh()
        lastRefresh := A_TickCount
    }
    if (A_TickCount - lastPeriodicFix > SETTINGS["PeriodicFixInterval"]) {
        PerformPeriodicFix()
        lastPeriodicFix := A_TickCount
    }
}

MonitorTargetPixel() {
    if (!STATE["monitoringActive"] || STATE["isAlarmPlaying"]) {
        return
    }
    if (!WinActive("ahk_id " . STATE["frontlineWinId"])) {
        return
    }

    currentColor := PixelGetColor(SETTINGS["TargetPixelX"], SETTINGS["TargetPixelY"])
    if (currentColor != SETTINGS["TargetPixelColor"]) {
        Log("Target pixel color mismatch. Verifying...")
        Sleep(3000)
        PerformStayOnlineClick()
        Sleep(500)

        finalColor := PixelGetColor(SETTINGS["TargetPixelX"], SETTINGS["TargetPixelY"])
        if (finalColor != SETTINGS["TargetPixelColor"]) {
            isMuted := (A_TickCount < STATE["alarmMutedUntil"])
            if (!isMuted) {
                Log("Verification failed. Triggering ALARM.")
                STATE["isAlarmPlaying"] := true
                SetTimer(AlarmBeep, 500)
                SendTelegram("🚨 **ALARM: Target Pixel Changed!**`n`nManual intervention may be required. Press any key to mute for 2 minutes.")
                STATE["lastAction"] := "ALARM TRIGGERED"
                STATE["lastActionTime"] := FormatTime(A_Now, "HH:mm:ss")
            } else {
                Log("Verification failed, but alarm is currently muted.")
            }
        } else {
            Log("Pixel color corrected after verification. Alarm averted.")
        }
    }
}

; ============================================================
; 5. دوال الإجراءات
; ============================================================
PerformStayOnlineClick() {
    Log("Performing enhanced Stay Online click (3 attempts).")
    local randX := Random(SETTINGS["StayOnlineAreaX1"], SETTINGS["StayOnlineAreaX2"])
    local randY := Random(SETTINGS["StayOnlineAreaY1"], SETTINGS["StayOnlineAreaY2"])
    Loop 3 {
        Click(randX, randY)
        Sleep(50)
    }
    STATE["lastAction"] := "Stay Online Click"
    STATE["lastActionTime"] := FormatTime(A_Now, "HH:mm:ss")
}

PerformRefresh() {
    Log("Performing Refresh click.")
    Click(SETTINGS["RefreshX"], SETTINGS["RefreshY"])
    STATE["lastAction"] := "Refresh Click"
    STATE["lastActionTime"] := FormatTime(A_Now, "HH:mm:ss")
}

PerformPeriodicFix() {
    Log("Performing periodic 3-step fix.")
    Click(SETTINGS["FixStep1X"], SETTINGS["FixStep1Y"])
    Sleep(1500)
    Click(SETTINGS["FixStep2X"], SETTINGS["FixStep2Y"])
    Sleep(1500)
    Click(SETTINGS["FixStep3X"], SETTINGS["FixStep3Y"])
    STATE["lastAction"] := "Periodic 3-Step Fix"
    STATE["lastActionTime"] := FormatTime(A_Now, "HH:mm:ss")
    SendTelegram("🔧 **Periodic Fix Executed**`n`nThe 3-step online fix was performed as a precaution.")
}

AlarmBeep() {
    SoundBeep(800, 400)
}

; ============================================================
; 6. التقارير والتواصل
; ============================================================
SendPeriodicReport() {
    if (!STATE["monitoringActive"]) {
        return
    }
    Log("Sending periodic report to Telegram.")
    batteryPercent := "N/A", chargerStatus := "Unknown"
    try {
        powerStatus := Buffer(12, 0)
        if DllCall("GetSystemPowerStatus", "Ptr", powerStatus) {
            batteryPercent := NumGet(powerStatus, 2, "UChar") . "%"
            chargerStatus := (NumGet(powerStatus, 1, "UChar") = 1) ? "Plugged In" : "On Battery"
        }
    }
    currentStatus := "Unknown"
    if (A_TickCount < STATE["alarmMutedUntil"]) {
        currentStatus := "ALARM MUTED"
    } else if (STATE["isAlarmPlaying"]) {
        currentStatus := "ALARM ACTIVE"
    } else {
        currentStatus := STATE["isUserIdle"] ? "Monitoring (User Idle)" : "Monitoring (User Active)"
    }
    report := "📊 **Periodic Status Report**`n`n"
    report .= "🔹 **Status:** " . currentStatus . "`n"
    report .= "🔋 **Battery:** " . batteryPercent . " (" . chargerStatus . ")`n"
    report .= "⏰ **Last Action:** " . STATE["lastAction"] . " at " . STATE["lastActionTime"] . "`n"
    report .= "🕒 **Report Time:** " . FormatTime(A_Now, "HH:mm:ss")
    SendTelegram(report)
}

; --- **دالة Telegram الأصلية والموثوقة** ---
SendTelegram(message) {
    Log("Attempting to send Telegram message via WinHttp (Original Method)...")
    if (SETTINGS["TelegramBotToken"] = "YOUR_TOKEN" || SETTINGS["TelegramChatId"] = "YOUR_CHAT_ID") {
        Log("Telegram send skipped: Token/ChatID not configured.")
        return
    }

    encodedMessage := UriEncode(message)
    url := "https://api.telegram.org/bot" . SETTINGS["TelegramBotToken"] . "/sendMessage"
    postBody := "chat_id=" . SETTINGS["TelegramChatId"] . "&text=" . encodedMessage . "&parse_mode=Markdown"

    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1" )
        ; فتح الطلب بشكل متزامن (false) لضمان اكتماله
        req.Open("POST", url, false)
        req.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        req.SetTimeouts(5000, 5000, 5000, 5000)
        req.Send(postBody)

        ; تسجيل حالة الاستجابة
        statusCode := req.Status
        if (statusCode = 200) {
            Log("Telegram request successful. Status: " . statusCode)
        } else {
            Log("Telegram request FAILED. Status: " . statusCode . ". Response: " . req.ResponseText)
        }
    } catch as e {
        Log("CRITICAL Error: Failed to send Telegram request via WinHttp. " . e.Message)
    }
}

UriEncode(str, encoding := "UTF-8") {
    static chars := "0123456789ABCDEF"
    if (str = "") {
        return ""
    }
    bytes := StrPut(str, encoding) - 1
    buf := Buffer(bytes)
    StrPut(str, buf, encoding)
    result := ""
    Loop bytes {
        c := NumGet(buf, A_Index - 1, "UChar")
        if ((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c = 45 || c = 46 || c = 95 || c = 126) {
            result .= Chr(c)
        } else {
            result .= "%" . SubStr(chars, (c >> 4) + 1, 1) . SubStr(chars, (c & 15) + 1, 1)
        }
    }
    return result
}

Log(message) {
    try FileAppend("[" . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "] " . message . "`n", "Demo_Log.txt", "UTF-8")
}

; ============================================================
; 7. الاختصارات والخروج الآمن
; ============================================================
#HotIf STATE["isAlarmPlaying"]
~*::
{
    Log("User activity detected. Muting alarm for 2 minutes.")
    STATE["isAlarmPlaying"] := false
    SetTimer(AlarmBeep, 0)
    STATE["alarmMutedUntil"] := A_TickCount + SETTINGS["AlarmMuteDuration"]
    SendTelegram("🔇 **Alarm Muted**`n`nAlarm has been silenced for 2 minutes due to user activity.")
    STATE["lastAction"] := "Alarm Muted by User"
    STATE["lastActionTime"] := FormatTime(A_Now, "HH:mm:ss")
}
#HotIf

F12::SafeExit()

SafeExit(*) {
    Log("--- Script Shutting Down ---")
    SendTelegram("⛔ **Script Shutting Down**`n`nFinal report will be sent shortly.")
    Sleep(1000)
    SendPeriodicReport()
    Sleep(1000)
    ExitApp()
}

; ============================================================
; 03_InitAndSettings.ahk - Initialization and Settings Loading
; ============================================================

InitializeScript() {
    global SETTINGS, STATE, SCREENSHOT_DIR, BOT_TOKEN, CHAT_ID
    
    ; --- Load all settings from the .ini file ---
    LoadSettings()
    ; فرض القيم المطلوبة إلى دقيقة واحدة كما طُلب (بدون التأثير على زر Stay Online)
    SETTINGS["StatusCheckInterval"] := 60000       ; Last Check كل دقيقة
    SETTINGS["RefreshInterval"] := 60000           ; Last Refresh كل دقيقة
    SETTINGS["UserIdleThreshold"] := 60000         ; User Idle Threshold دقيقة واحدة
    ; لو حبيت نعدل غيرهم كمان بلغني (زي MainLoopInterval أو غيره)

    ; --- Set up the initial state of the script ---
    InitializeState()
    
    ; تحديد تفعيل تيليجرام بناءً على مفاتيئة
    STATE["telegramEnabled"] := (!!BOT_TOKEN && !!CHAT_ID)
    if (!STATE["telegramEnabled"]) {
        try Warn("Telegram is disabled: missing BOT_TOKEN/CHAT_ID. All Telegram sends will be skipped.")
    } else {
        Info("Telegram is enabled: BOT_TOKEN/CHAT_ID loaded.")
    }
    
    ; --- Create screenshots directory if it doesn't exist ---
    if !DirExist(SCREENSHOT_DIR)
        DirCreate(SCREENSHOT_DIR)

    ; --- Start GDI+ and bind the shutdown function for safe exit ---
    Gdip_Startup()

    Info("--- Script Starting ---")
    STATE["scriptStatus"] := "Running"
    
    ; --- Perform a self-test to check for required files ---
    if (SelfTest().Length > 0) {
        MsgBox("Critical files are missing. Script will not run correctly. Please check log for details.", "Startup Failed", 4112)
        ExitApp
    }

    ; --- Check for Frontline window and launch if not found ---
    if !WinExist(SETTINGS["FrontlineWinTitle"]) {
        Info("Frontline not found on start. Attempting to launch.")
        StartApp(SETTINGS["FrontlineShortcutName"], "frontlineStatus")
    } else {
        STATE["frontlineStatus"] := "Active"
    }

    ; --- Initialize all timers ---
    SetTimer(StatusCheckTimer, SETTINGS["StatusCheckInterval"])
    SetTimer(StayOnlineTimer, SETTINGS["StayOnlineInterval"]) 
    SetTimer(RefreshTimer, SETTINGS["RefreshInterval"]) 
    SetTimer(MonitorTargetTimer, SETTINGS["MainLoopInterval"]) 
    SetTimer(UpdateDashboardTimer, 1000)
    Info("Timers initialized. Running.")
    ; ScheduleNextDailyReport() ; تم إيقاف التقرير اليومي المجدول بناءً على طلبك

    ; استعادة لقطـة الحالة إن وجدت
    try LoadStateSnapshot(A_ScriptDir "\state_snapshot.ini")

    ; تايمر فحص الإنترنت حسب الإعدادات
    SetTimer(NetCheckTimer, SETTINGS.Has("NetCheckInterval") ? SETTINGS["NetCheckInterval"] : 1000)

    ; تايمر فحص البطارية (مرة كل دقيقة كفحص خفيف)
    SetTimer(BatteryCheckTimer, 60000)

    ; حفظ دوري للحالة
    SetTimer(StateSaveTimer, SETTINGS.Has("StateSaveInterval") ? SETTINGS["StateSaveInterval"] : 300000)

    ; حفظ عند الخروج
    OnExit(SaveStateOnExit)
    Info("STATE Map has been re-initialized.")
}

InitializeState() {
    global STATE
    STATE := Map()
    STATE["frontlineStatus"] := "Unknown"
    STATE["onlineStatus"] := "Unknown"
    STATE["scriptStatus"] := "Running"
    STATE["isAlarmPlaying"] := false
    STATE["lastRefreshTime"] := 0
    STATE["lastStayOnlineClickTime"] := 0
    STATE["lastStatusCheckTime"] := 0
    STATE["isMonitoringPaused"] := false
    STATE["lastUserActivity"] := A_TickCount
    STATE["lastRefreshTimestamp"] := "Never"
    STATE["lastStayOnlineTimestamp"] := "Never"
    STATE["lastStatusCheckTimestamp"] := "Never"
    STATE["lastTelegramStatus"] := "None"
    STATE["offlineFixAttempts"] := 0
    STATE["screenshotHashes"] := Map()
    STATE["savedScreenshots"] := []
    Info("STATE Map has been re-initialized.")
    ; --- إضافات للتقارير اليومية وتعقب الحالة ---
    STATE["scriptStartTime"] := A_Now
    STATE["lastReportTime"] := A_Now
    STATE["currentStatus"] := "Unknown"
    STATE["lastStatusChangeTick"] := A_TickCount
    STATE["statusDurations"] := Map(  ; المدد بالمللي ثانية
        "Online", 0,
        "WorkOnMyTicket", 0,
        "Break", 0,
        "Launch", 0,
        "Offline", 0,
        "Unknown", 0
    )
    ; --- مفاتيح مراقبة الإنترنت وقائمة انتظار تيليجرام ---
    STATE["netOnline"] := true
    STATE["netOutageOngoing"] := false
    STATE["netLastChangeTick"] := A_TickCount
    STATE["netDowntimeMs"] := 0
    STATE["telegramQueue"] := []  ; رسائل مؤجلة عند انقطاع النت
    STATE["telegramEnabled"] := false
    STATE["isNetAlarmPlaying"] := false
    Info("STATE Map has been re-initialized.")
}

LoadSettings() {
    global SETTINGS, iniFile
    try {
        local imageFolder := A_ScriptDir "\images\"
        SETTINGS["FrontlineWinTitle"] := IniRead(iniFile, "Citrix", "WinTitle", "Front Line")
        SETTINGS["FrontlineShortcutName"] := IniRead(iniFile, "Citrix", "ShortcutName", "Front Line")
        SETTINGS["OfflineImage"] := imageFolder . IniRead(iniFile, "Citrix", "OfflineImageName", "offline.png")
        SETTINGS["StayOnlineImage"] := imageFolder . IniRead(iniFile, "Citrix", "StayOnlineImageName", "stay_online.png")
        SETTINGS["OnlineImage"] := imageFolder . IniRead(iniFile, "Citrix", "OnlineImageName", "online.png")
        ; دعم صور أونلاين إضافية اختيارية (ستُعامل مثل Online العادية)
        SETTINGS["OnlineImage2"] := imageFolder . IniRead(iniFile, "Citrix", "OnlineImageName2", "online2.png")
        SETTINGS["OnlineImage3"] := imageFolder . IniRead(iniFile, "Citrix", "OnlineImageName3", "online3.png")
        SETTINGS["OnlineImage4"] := imageFolder . IniRead(iniFile, "Citrix", "OnlineImageName4", "online4.png")
        ; ابنِ قائمة الصور المتاحة فعليًا
        SETTINGS["OnlineImageList"] := []
        try {
            if (FileExist(SETTINGS["OnlineImage"]))
                SETTINGS["OnlineImageList"].Push(SETTINGS["OnlineImage"])
            for k in ["OnlineImage2","OnlineImage3","OnlineImage4"] {
                if (SETTINGS.Has(k) && FileExist(SETTINGS[k]))
                    SETTINGS["OnlineImageList"].Push(SETTINGS[k])
            }
        }
        ; التوقيتات (القيم الافتراضية كما هي، سنفرض دقيقة بعد التحميل في InitializeScript)
        SETTINGS["WorkOnMyTicketImage"] := imageFolder . IniRead(iniFile, "Citrix", "WorkOnMyTicketImageName", "work_on_my_ticket.png")
        SETTINGS["LaunchImage"] := imageFolder . IniRead(iniFile, "Citrix", "LaunchImageName", "launch.png")
        SETTINGS["BreakImage"] := imageFolder . IniRead(iniFile, "Citrix", "BreakImageName", "break.png")
        SETTINGS["TargetImage"] := imageFolder . IniRead(iniFile, "WordMonitor", "TargetImageName", "target_word.PNG")
        SETTINGS["BeepFrequency"] := IniRead(iniFile, "WordMonitor", "BeepFrequency", 800)
        SETTINGS["BeepDuration"] := IniRead(iniFile, "WordMonitor", "BeepDuration", 400)
        SETTINGS["StatusAreaTopLeftX"] := IniRead(iniFile, "Coordinates", "StatusAreaTopLeftX", 59)
        SETTINGS["StatusAreaTopLeftY"] := IniRead(iniFile, "Coordinates", "StatusAreaTopLeftY", 981)
        SETTINGS["StatusAreaBottomRightX"] := IniRead(iniFile, "Coordinates", "StatusAreaBottomRightX", 220)
        SETTINGS["StatusAreaBottomRightY"] := IniRead(iniFile, "Coordinates", "StatusAreaBottomRightY", 1007)
        SETTINGS["TargetAreaTopLeftX"] := IniRead(iniFile, "Coordinates", "TargetAreaTopLeftX", 873)
        SETTINGS["TargetAreaTopLeftY"] := IniRead(iniFile, "Coordinates", "TargetAreaTopLeftY", 516)
        SETTINGS["TargetAreaBottomRightX"] := IniRead(iniFile, "Coordinates", "TargetAreaBottomRightX", 1275)
        SETTINGS["TargetAreaBottomRightY"] := IniRead(iniFile, "Coordinates", "TargetAreaBottomRightY", 607)
        SETTINGS["StayOnlineAreaTopLeftX"] := IniRead(iniFile, "Coordinates", "StayOnlineAreaTopLeftX", 1155)
        SETTINGS["StayOnlineAreaTopLeftY"] := IniRead(iniFile, "Coordinates", "StayOnlineAreaTopLeftY", 655)
        SETTINGS["StayOnlineAreaBottomRightX"] := IniRead(iniFile, "Coordinates", "StayOnlineAreaBottomRightX", 1300)
        SETTINGS["StayOnlineAreaBottomRightY"] := IniRead(iniFile, "Coordinates", "StayOnlineAreaBottomRightY", 707)
        SETTINGS["FixStep1X"] := IniRead(iniFile, "Coordinates", "FixStep1X", 140)
        SETTINGS["FixStep1Y"] := IniRead(iniFile, "Coordinates", "FixStep1Y", 994)
        SETTINGS["FixStep2X"] := IniRead(iniFile, "Coordinates", "FixStep2X", 140)
        SETTINGS["FixStep2Y"] := IniRead(iniFile, "Coordinates", "FixStep2Y", 994)
        SETTINGS["FixStep3X"] := IniRead(iniFile, "Coordinates", "FixStep3X", 328)
        SETTINGS["FixStep3Y"] := IniRead(iniFile, "Coordinates", "FixStep3Y", 323)
        SETTINGS["RefreshX"] := IniRead(iniFile, "Coordinates", "RefreshX", 114)
        SETTINGS["RefreshY"] := IniRead(iniFile, "Coordinates", "RefreshY", 73)
        SETTINGS["UserIdleThreshold"] := IniRead(iniFile, "Timings", "UserIdleThreshold", 120000)
        SETTINGS["StayOnlineInterval"] := IniRead(iniFile, "Timings", "StayOnlineInterval", 180000)
        SETTINGS["RefreshInterval"] := IniRead(iniFile, "Timings", "RefreshInterval", 420000)
        SETTINGS["MainLoopInterval"] := IniRead(iniFile, "Timings", "MainLoopInterval", 5000)
        SETTINGS["StatusCheckInterval"] := IniRead(iniFile, "Timings", "StatusCheckInterval", 90000)
        SETTINGS["WordMonitorUserIdleReset"] := IniRead(iniFile, "Timings", "WordMonitorUserIdleReset", 60000)
        SETTINGS["ManualPauseDuration"] := IniRead(iniFile, "Timings", "ManualPauseDuration", 180000)
        SETTINGS["ImageSearchTolerance"] := IniRead(iniFile, "Search", "Tolerance", 30)

        ; --- إعدادات إضافية ---
        SETTINGS["NetCheckInterval"] := IniRead(iniFile, "Timings", "NetCheckInterval", 1000)
        SETTINGS["NetCheckTimeoutMs"] := IniRead(iniFile, "Network", "CheckTimeoutMs", 800)
         SETTINGS["StateSaveInterval"] := IniRead(iniFile, "Persistence", "StateSaveInterval", 300000)
         SETTINGS["BatteryAlertThreshold"] := IniRead(iniFile, "Battery", "AlertThreshold", 20)
         SETTINGS["BatteryAlertCooldown"] := IniRead(iniFile, "Battery", "AlertCooldownMs", 1800000) ; 30 دقيقة
    } catch as ex {
        MsgBox("Error reading settings.ini:`n" . ex.Message, "Configuration Error", 4112)
        ExitApp
    }
}

SaveStateOnExit(*) {
    ; حفظ الحالة عند الخروج + إرسال تقرير الجلسة عند الإنهاء
    try SaveStateSnapshot(A_ScriptDir "\state_snapshot.ini")
    
    ; إرسال تقرير مختصر بالجلسة عند الخروج
    try {
        global STATE
        ; جمع آخر مدة للحالة الحالية
        UpdateStatusDurations(STATE.Has("onlineStatus") ? STATE["onlineStatus"] : "Unknown")
        startedAt := STATE.Has("scriptStartTime") ? STATE["scriptStartTime"] : A_Now
        periodFrom := STATE.Has("lastReportTime") ? STATE["lastReportTime"] : startedAt
        periodTo := A_Now

        details := Map(
            "Script Started", FormatTime(startedAt, "yyyy-MM-dd HH:mm:ss"),
            "Period", FormatTime(periodFrom, "yyyy-MM-dd HH:mm") . " → " . FormatTime(periodTo, "yyyy-MM-dd HH:mm"),
            "Online", FormatMs(STATE["statusDurations"]["Online"]),
            "WorkOnMyTicket", FormatMs(STATE["statusDurations"]["WorkOnMyTicket"]),
            "Launch", FormatMs(STATE["statusDurations"]["Launch"]),
            "Offline", FormatMs(STATE["statusDurations"]["Offline"]),
            "Unknown", FormatMs(STATE["statusDurations"]["Unknown"]),
            "Net Downtime", STATE.Has("netDowntimeMs") ? FormatMs(STATE["netDowntimeMs"]) : "00h 00m 00s"
        )
        SendRichTelegramNotification("📊 Session Report (on exit)", details)
        if IsObject(STATE)
            STATE["lastTelegramStatus"] := "Exit report sent at " . FormatTime(A_Now, "HH:mm:ss")
    } catch {
        ; ignore
    }
}

StateSaveTimer(*) {
    try SaveStateSnapshot(A_ScriptDir "\state_snapshot.ini")
}

SelfTest() {
    global SETTINGS
    missing := []
    desk1 := A_Desktop "\" SETTINGS["FrontlineShortcutName"] ".lnk"
    desk2 := A_DesktopCommon "\" SETTINGS["FrontlineShortcutName"] ".lnk"
    if !(FileExist(desk1) || FileExist(desk2))
        missing.Push("Frontline shortcut (" . SETTINGS["FrontlineShortcutName"] . ")")
    
    images := [ "OfflineImage", "StayOnlineImage", "OnlineImage", "WorkOnMyTicketImage", "LaunchImage", "BreakImage", "TargetImage" ]
    for key in images {
        if (SETTINGS.Has(key)) {
            if !FileExist(SETTINGS[key])
                missing.Push("Missing image file: " . key . " -> " . SETTINGS[key])
        } else {
            missing.Push("Missing setting: " . key)
        }
    }
    
    If (missing.Length = 0) {
        Info("SelfTest: All required files/shortcuts found.")
    } else {
        report := "SelfTest - Missing items:`n"
        for item in missing
            report .= "- " . item . "`n"
        LogError(report)
    }
    return missing
}

StartApp(shortcutName, statusKey) {
    global STATE
    shortcutPath := A_Desktop "\" shortcutName ".lnk"
    if !FileExist(shortcutPath)
        shortcutPath := A_DesktopCommon "\" shortcutName ".lnk"
    
    if (FileExist(shortcutPath)) {
        Run(shortcutPath)
        if (STATE.Has(statusKey))
            STATE[statusKey] := "Launching"
        Info(shortcutName . " launched from shortcut.")
        Sleep 15000
        return true
    } else {
        Warn("CRITICAL: Shortcut not found: " . shortcutName)
        if (STATE.Has(statusKey))
            STATE[statusKey] := "Shortcut Missing"
        return false
    }
}

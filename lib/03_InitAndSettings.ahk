; ============================================================
; 03_InitAndSettings.ahk - Initialization and Settings Loading
; ============================================================

InitializeScript() {
    global SETTINGS, STATE, SCREENSHOT_DIR, BOT_TOKEN, CHAT_ID
    
    ; --- Load all settings from the .ini file ---
    LoadSettings()
    ; فرض القيم المطلوبة: فحص الحالة كل 5 ثوانٍ بعد بوابة الخمول، ورفع عتبة الخمول إلى دقيقتين
    SETTINGS["StatusCheckInterval"] := 5000        ; فحص الحالة كل 5 ثوانٍ
    SETTINGS["RefreshInterval"] := 60000           ; يظل كل دقيقة (نُبقيه كما هو حالياً)
    SETTINGS["UserIdleThreshold"] := 120000        ; عتبة خمول المستخدم = 120 ثانية
    SETTINGS["StayOnlineInterval"] := 120000       ; تحقق زر Stay Online كل دقيقتين
    ; إضافة إعدادات جديدة للنظام الذكي
    SETTINGS["InitialIdleWait"] := 120000          ; انتظار دقيقتين قبل بدء أي مراقبة
    SETTINGS["SmartDashboard"] := true             ; تفعيل الداشبورد الذكي
    SETTINGS["IntelligentCoordinates"] := true     ; تفعيل اكتشاف الإحداثيات الذكي
    SETTINGS["MultiScreenSupport"] := true        ; دعم الشاشات المتعددة
    ; لو حبيت نعدل غيرهم كمان بلغني (زي MainLoopInterval أو غيره)

    ; --- Set up the initial state of the script ---
    InitializeState()
    
    ; تحديد تفعيل تيليجرام بناءً على مفاتيئة
    STATE["telegramEnabled"] := (!!BOT_TOKEN && !!CHAT_ID)
    if (!STATE["telegramEnabled"]) {
        try {
            Warn("Telegram is disabled: missing BOT_TOKEN/CHAT_ID. All Telegram sends will be skipped.")
        } catch {
        }
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

    ; --- Initialize all timers with initial delay ---
    ; تأخير بدء المراقبة لمدة دقيقتين
    Info("Waiting 2 minutes before starting monitoring...")
    SetTimer(DelayedTimerStart, -SETTINGS["InitialIdleWait"])
    
    ; بدء مراقبة النشاط فوراً لتتبع حالة المستخدم
    SetTimer(ActivityMonitorTimer, SETTINGS.Has("ActivityPollIntervalMs") ? SETTINGS["ActivityPollIntervalMs"] : 150)
    
    ; بدء الداشبورد فوراً
    SetTimer(UpdateDashboardTimer, SETTINGS.Has("DashboardUpdateIntervalMs") ? SETTINGS["DashboardUpdateIntervalMs"] : 1000)
    
    Info("Initial timers set. Monitoring will start after 2-minute delay.")

    ; استعادة لقطـة الحالة إن وجدت
    try {
        LoadStateSnapshot(A_ScriptDir "\state_snapshot.ini")
    } catch {
    }

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

; دالة جديدة لبدء التايمرز بعد التأخير
DelayedTimerStart(*) {
    global SETTINGS, STATE
    Info("2-minute wait completed. Starting monitoring timers...")
    
    ; محاولة تحميل البروفايل المناسب تلقائياً
    try {
        autoProfile := AutoDetectProfile()
        if (autoProfile != "") {
            if (SwitchProfile(autoProfile)) {
                Info("Auto-loaded profile: " . autoProfile)
            }
        } else {
            ; إنشاء بروفايل تلقائي جديد إذا لم يوجد مطابق
            newAutoProfile := CreateAutoProfile()
            if (newAutoProfile != "") {
                STATE["currentProfile"] := newAutoProfile
                Info("Created and using new auto-profile: " . newAutoProfile)
            }
        }
    } catch as e {
        Warn("Auto-profile detection failed: " . e.Message)
    }
    
    ; تشغيل النظام الذكي لاكتشاف الإحداثيات
    if (SETTINGS.Has("IntelligentCoordinates") && SETTINGS["IntelligentCoordinates"]) {
        Info("Starting intelligent coordinate detection...")
        try {
            IntelligentCoordinateDetection()
        } catch as e {
            Warn("Intelligent coordinate detection failed: " . e.Message)
        }
    }
    
    ; بدء جميع تايمرز المراقبة
    SetTimer(StatusCheckTimer, SETTINGS["StatusCheckInterval"])
    SetTimer(StayOnlineTimer, SETTINGS["StayOnlineInterval"]) 
    SetTimer(RefreshTimer, SETTINGS["RefreshInterval"]) 
    SetTimer(MonitorTargetTimer, SETTINGS["MainLoopInterval"]) 
    
    ; أول فحص حالة بعد 10 ثواني من بدء المراقبة
    SetTimer(StatusCheckTimer, -10000)
    
    STATE["monitoringActive"] := true
    Info("All monitoring timers are now active.")
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
    STATE["lastActivityType"] := "none"
    STATE["synthInputUntil"] := 0
    STATE["lastRefreshTimestamp"] := "Never"
    STATE["lastStayOnlineTimestamp"] := "Never"
    STATE["lastStatusCheckTimestamp"] := "Never"
    STATE["lastTelegramStatus"] := "None"
    STATE["offlineFixAttempts"] := 0
    STATE["screenshotHashes"] := Map()
    STATE["savedScreenshots"] := []
    
    ; إضافة متغيرات جديدة للنظام الذكي
    STATE["monitoringActive"] := false              ; حالة المراقبة النشطة
    STATE["smartCoordinates"] := Map()              ; إحداثيات ذكية محفوظة
    STATE["currentProfile"] := "default"           ; البروفايل الحالي
    STATE["detectedScreens"] := []                 ; الشاشات المكتشفة
    STATE["dashboardPosition"] := "left"           ; موقع الداشبورد الحالي
    STATE["mouseLastX"] := 0                       ; آخر موقع للماوس X
    STATE["mouseLastY"] := 0                       ; آخر موقع للماوس Y
    STATE["intelligentMode"] := true               ; تفعيل الوضع الذكي
    
    Info("STATE Map has been re-initialized.")
    ; --- إضافات للتقارير اليومية وتعقب الحالة ---
    STATE["scriptStartTime"] := A_Now
    STATE["lastReportTime"] := A_Now
    STATE["currentStatus"] := "Unknown"
    STATE["lastStatusChangeTick"] := A_TickCount
    STATE["statusDurations"] := Map(  ; المدد بالمللي ثانية
        "Online", 0,
        "WorkOnMyTicket", 0,
        "Coaching", 0,
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
        ; دعم صورة ثانية لزر Stay Online
        SETTINGS["StayOnlineImage2"] := imageFolder . IniRead(iniFile, "Citrix", "StayOnlineImageName2", "stay_online2.png")
        SETTINGS["OnlineImage"] := imageFolder . IniRead(iniFile, "Citrix", "OnlineImageName", "online.png")
        ; دعم صور أونلاين إضافية اختيارية (ستُعامل مثل Online العادية)
        SETTINGS["OnlineImage2"] := imageFolder . IniRead(iniFile, "Citrix", "OnlineImageName2", "online2.png")
        SETTINGS["OnlineImage3"] := imageFolder . IniRead(iniFile, "Citrix", "OnlineImageName3", "online3.png")
        SETTINGS["OnlineImage4"] := imageFolder . IniRead(iniFile, "Citrix", "OnlineImageName4", "online4.png")
        ; دعم حالة Coaching بصورتين
        SETTINGS["CoachingImage"] := imageFolder . IniRead(iniFile, "Citrix", "CoachingImageName", "coaching.png")
        SETTINGS["CoachingImage2"] := imageFolder . IniRead(iniFile, "Citrix", "CoachingImageName2", "coaching2.png")
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
        ; قوائم لزر Stay Online و Coaching (إن وُجدت الملفات)
        SETTINGS["StayOnlineImageList"] := []
        if (FileExist(SETTINGS["StayOnlineImage"]))
            SETTINGS["StayOnlineImageList"].Push(SETTINGS["StayOnlineImage"])
        if (SETTINGS.Has("StayOnlineImage2") && FileExist(SETTINGS["StayOnlineImage2"]))
            SETTINGS["StayOnlineImageList"].Push(SETTINGS["StayOnlineImage2"]) 
        
        ; تحميل عينات إضافية محفوظة تلقائياً لزر Stay Online
        try {
            Loop Files, A_ScriptDir "\screenshots\stay_online_samples\*.png", "F" {
                SETTINGS["StayOnlineImageList"].Push(A_LoopFileFullPath)
            }
        } catch {
        }
        SETTINGS["CoachingImageList"] := []
        if (SETTINGS.Has("CoachingImage") && FileExist(SETTINGS["CoachingImage"]))
            SETTINGS["CoachingImageList"].Push(SETTINGS["CoachingImage"])
        if (SETTINGS.Has("CoachingImage2") && FileExist(SETTINGS["CoachingImage2"]))
            SETTINGS["CoachingImageList"].Push(SETTINGS["CoachingImage2"])        
        ; التوقيتات (القيم الافتراضية كما هي، سنفرض دقيقة بعد التحميل في InitializeScript)
        SETTINGS["WorkOnMyTicketImage"] := imageFolder . IniRead(iniFile, "Citrix", "WorkOnMyTicketImageName", "work_on_my_ticket.png")
        SETTINGS["LaunchImage"] := imageFolder . IniRead(iniFile, "Citrix", "LaunchImageName", "launch.png")
        SETTINGS["BreakImage"] := imageFolder . IniRead(iniFile, "Citrix", "BreakImageName", "break.png")
        SETTINGS["TargetImage"] := imageFolder . IniRead(iniFile, "WordMonitor", "TargetImageName", "target_word.PNG")
        ; دعم صورة ثانية لتارجت ورد
        SETTINGS["TargetImage2"] := imageFolder . IniRead(iniFile, "WordMonitor", "TargetImageName2", "target_word2.PNG")
        ; قائمة صور التارجت (واحدة أو اثنتان)
        SETTINGS["TargetImageList"] := []
        if (FileExist(SETTINGS["TargetImage"]))
            SETTINGS["TargetImageList"].Push(SETTINGS["TargetImage"]) 
        if (SETTINGS.Has("TargetImage2") && FileExist(SETTINGS["TargetImage2"]))
            SETTINGS["TargetImageList"].Push(SETTINGS["TargetImage2"])        
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
        SETTINGS["PostRefreshDelayMs"] := IniRead(iniFile, "Timings", "PostRefreshDelayMs", 2500)
        ; New: independent idle threshold for target missing alarm (0 = disabled)
        SETTINGS["TargetIdleThresholdMs"] := IniRead(iniFile, "Timings", "TargetIdleThresholdMs", 0)
        SETTINGS["ImageSearchTolerance"] := IniRead(iniFile, "Search", "Tolerance", 30)
        
        ; ImageSearch multi-scale list (CSV -> Array of positive numbers)
        local scalesCsv := IniRead(iniFile, "Search", "Scales", "1.0")
        SETTINGS["ImageSearchScales"] := []
        for p in StrSplit(scalesCsv, ",") {
            v := Trim(p)
            if (v = "")
                continue
            s := v + 0
            if (s > 0)
                SETTINGS["ImageSearchScales"].Push(s)
        }
        if (SETTINGS["ImageSearchScales"].Length = 0)
            SETTINGS["ImageSearchScales"].Push(1.0)

        ; --- إعدادات إضافية ---
        SETTINGS["NetCheckInterval"] := IniRead(iniFile, "Timings", "NetCheckInterval", 1000)
        SETTINGS["NetCheckTimeoutMs"] := IniRead(iniFile, "Network", "CheckTimeoutMs", 800)
        SETTINGS["StateSaveInterval"] := IniRead(iniFile, "Persistence", "StateSaveInterval", 300000)
        SETTINGS["BatteryAlertThreshold"] := IniRead(iniFile, "Battery", "AlertThreshold", 20)
        SETTINGS["BatteryAlertCooldown"] := IniRead(iniFile, "Battery", "AlertCooldownMs", 1800000) ; 30 دقيقة

        ; --- إعدادات واجهة الداشبورد (اختيارية) ---
        SETTINGS["DashboardX"] := IniRead(iniFile, "Dashboard", "X", 10)
        SETTINGS["DashboardY"] := IniRead(iniFile, "Dashboard", "Y", 120)
        SETTINGS["DashboardHideOnHover"] := IniRead(iniFile, "Dashboard", "HideOnHover", 0)
        SETTINGS["DashboardUpdateIntervalMs"] := IniRead(iniFile, "Dashboard", "UpdateIntervalMs", 1500)
        SETTINGS["DashboardX2"] := IniRead(iniFile, "Dashboard", "X2", SETTINGS["DashboardX"]) 
        SETTINGS["DashboardY2"] := IniRead(iniFile, "Dashboard", "Y2", SETTINGS["DashboardY"])

        ; --- حالات مُصرح بها لمراقبة الكلمة (CSV) ---
        local statusesCsv := IniRead(iniFile, "WordMonitor", "AllowedStatuses", "Online")
        SETTINGS["TargetMonitorStatuses"] := []
        for part in StrSplit(statusesCsv, ",") {
            SETTINGS["TargetMonitorStatuses"].Push(Trim(part))
        }

        ; --- إعدادات مراقبة النشاط ---
        SETTINGS["ActivityPollIntervalMs"] := IniRead(iniFile, "Activity", "PollIntervalMs", 150)
        SETTINGS["ActivityMoveThresholdPx"] := IniRead(iniFile, "Activity", "MoveThresholdPx", 2)
        SETTINGS["ActivityKeyboardResetMs"] := IniRead(iniFile, "Activity", "KeyboardResetMs", 120)
        SETTINGS["ActivityIdleGateMs"] := IniRead(iniFile, "Activity", "ActivityIdleGateMs", 3000)
        SETTINGS["ActivitySynthIgnoreMs"] := IniRead(iniFile, "Activity", "SynthIgnoreMs", 2000)
        SETTINGS["ActivityKeyboardOnly"] := IniRead(iniFile, "Activity", "KeyboardOnly", 0)
        SETTINGS["ActivityDebug"] := IniRead(iniFile, "Activity", "Debug", 0)
    } catch as ex {
        MsgBox("Error reading settings.ini:`n" . ex.Message, "Configuration Error", 4112)
        ExitApp
    }
}

SaveStateOnExit(*) {
    ; حفظ الحالة عند الخروج + إرسال تقرير الجلسة عند الإنهاء
    try {
        SaveStateSnapshot(A_ScriptDir "\state_snapshot.ini")
    } catch {
    }

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
    try {
        SaveStateSnapshot(A_ScriptDir "\state_snapshot.ini")
    } catch {
    }
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

; ============================================================
; 05_TimersLogic.ahk (v3 - Using Rich Notifications & Photos)
; ============================================================

StatusCheckTimer(*) {
    global SETTINGS, STATE
    if !IsObject(STATE) {
        LogError("STATE object lost in StatusCheckTimer.")
        return
    }
    STATE["lastStatusCheckTime"] := A_TickCount
    STATE["lastStatusCheckTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
    if !WinExist(SETTINGS["FrontlineWinTitle"]) {
        if (STATE["frontlineStatus"] != "Missing") {
            STATE["frontlineStatus"] := "Missing"
            Info("Front Line window not found. Attempting to restart app.")
            StartApp(SETTINGS["FrontlineShortcutName"], "frontlineStatus")
        }
        return
    }
    STATE["frontlineStatus"] := "Active"
    local statusArea := Map("x1", SETTINGS["StatusAreaTopLeftX"], "y1", SETTINGS["StatusAreaTopLeftY"], "x2", SETTINGS["StatusAreaBottomRightX"], "y2", SETTINGS["StatusAreaBottomRightY"])
    local knownStatusFound := false, foundX, foundY

    ; أولًا: تحقق من أي صورة ضمن صور Online المتعددة
    if (SETTINGS.Has("OnlineImageList") && SETTINGS["OnlineImageList"].Length > 0) {
        for imgPath in SETTINGS["OnlineImageList"] {
            if (ReliableImageSearch(&foundX, &foundY, imgPath, statusArea)) {
                if (STATE["onlineStatus"] != "Online") {
                    Info("Status changed to: Online")
                    UpdateStatusDurations("Online")
                    STATE["onlineStatus"] := "Online"
                    STATE["offlineFixAttempts"] := 0
                }
                knownStatusFound := true
                break
            }
        }
        if (knownStatusFound)
            return
    } else {
        ; رجوع للخيار القديم لو القائمة غير متاحة
        if (ReliableImageSearch(&foundX, &foundY, SETTINGS["OnlineImage"], statusArea)) {
            if (STATE["onlineStatus"] != "Online") {
                Info("Status changed to: Online")
                UpdateStatusDurations("Online")
                STATE["onlineStatus"] := "Online"
                STATE["offlineFixAttempts"] := 0
            }
            return
        }
    }

    ; بقية الحالات الجيدة
    local goodStates := ["WorkOnMyTicket", "Break", "Launch"]
    for stateName in goodStates {
        if (ReliableImageSearch(&foundX, &foundY, SETTINGS[stateName . "Image"], statusArea)) {
            if (STATE["onlineStatus"] != stateName) {
                Info("Status changed to: " . stateName)
                UpdateStatusDurations(stateName)
                STATE["onlineStatus"] := stateName
                STATE["offlineFixAttempts"] := 0
            }
            knownStatusFound := true
            break
        }
    }
    if (knownStatusFound) {
        return
    }

    ; Offline detection and fixes as-is
    if (ReliableImageSearch(&foundX, &foundY, SETTINGS["OfflineImage"], statusArea)) {
        if (STATE["onlineStatus"] != "Offline") {
            Info("OFFLINE status detected.")
            UpdateStatusDurations("Offline") ; تجميع مدة الحالة السابقة وتحديث الحالية
            STATE["onlineStatus"] := "Offline"
            STATE["offlineFixAttempts"] := 1
            ShowLocalNotification("❗ Status is OFFLINE! Attempting fix...")
            SendRichTelegramNotification("❗ Offline Detected", Map("Attempting Fix", "Yes", "Attempt #", 1))
            EnsureOnlineStatus()
        } else {
            STATE["offlineFixAttempts"]++
            Info("Still OFFLINE. Attempting fix, attempt #" . STATE["offlineFixAttempts"])
            EnsureOnlineStatus()
            if (STATE["offlineFixAttempts"] >= 3 && !STATE["isAlarmPlaying"]) {
                Info("CRITICAL: Offline fix failed 3 times. Triggering alarm.")
                STATE["isAlarmPlaying"] := true
                ShowLocalNotification("🚨 ALARM: Offline fix FAILED!")
                SendRichTelegramNotification("🚨 ALARM: Offline Fix Failed", Map("Attempts", STATE["offlineFixAttempts"], "Action", "Manual intervention required!"))
                SetTimer(AlarmBeep, 300)
            }
        }
        knownStatusFound := true
    }
    if (knownStatusFound) {
        return
    }

    if (STATE["onlineStatus"] != "Unknown") {
        Info("Online status is now definitively UNKNOWN.")
        UpdateStatusDurations("Unknown") ; تجميع مدة الحالة السابقة وتحديث الحالية
        STATE["onlineStatus"] := "Unknown"
        STATE["offlineFixAttempts"] := 0
    }
    Info("Attempting to save and send a screenshot for the 'Unknown' state...")
    screenshotResult := SaveStatusScreenshotEnhanced("unknown_status")
    if (IsObject(screenshotResult) && screenshotResult.ok) {
        Info("Successfully saved screenshot: " . screenshotResult.file)
        caption := "🤔 Unknown Status Detected`nI couldn't recognize the status. Here is what I see in the status area."
        SendTelegramPhoto(screenshotResult.file, caption)
    } else {
        Warn("Failed to save screenshot for unknown status. Check coordinates and permissions.")
    }
}

EnsureOnlineStatus() {
    global SETTINGS
    Info("Executing 3-step fix for offline status...")
    Click(SETTINGS["FixStep1X"], SETTINGS["FixStep1Y"])
    Sleep(1500)
    Click(SETTINGS["FixStep2X"], SETTINGS["FixStep2Y"])
    Sleep(1500)
    Click(SETTINGS["FixStep3X"], SETTINGS["FixStep3Y"])
    Sleep(1500)
    Info("Fix clicks performed.")
}

StayOnlineTimer(*) {
    global SETTINGS, STATE
    if (!WinExist(SETTINGS["FrontlineWinTitle"]) || (A_TickCount - STATE["lastUserActivity"] < SETTINGS["UserIdleThreshold"]))
        return
    res := ClickStayOnlineButton()
    if (res) {
        STATE["lastStayOnlineClickTime"] := A_TickCount
        STATE["lastStayOnlineTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
        Info("Stay Online click performed - timestamp updated.")
        ; تهدئة قصيرة لتفادي التداخل مع الريفريش
        STATE["actionBusyUntil"] := A_TickCount + 3000
    } else {
        Info("Stay Online: no button detected, no click performed.")
    }
}

RefreshTimer(*) {
    global SETTINGS, STATE
    if (!WinExist(SETTINGS["FrontlineWinTitle"]))
        return
    ; تخطي الريفريش أثناء التهدئة بعد إجراء (مثل Stay Online)
    if (STATE.Has("actionBusyUntil") && A_TickCount < STATE["actionBusyUntil"]) {
        Info("Refresh skipped (cooldown after action).")
        return
    }
    ; لو نافذة Stay Online ظاهرة، اسكب الريفريش لتفادي الخناقة
    stayOnlineArea := Map("x1", SETTINGS["StayOnlineAreaTopLeftX"], "y1", SETTINGS["StayOnlineAreaTopLeftY"], "x2", SETTINGS["StayOnlineAreaBottomRightX"], "y2", SETTINGS["StayOnlineAreaBottomRightY"])
    local sX, sY
    if (ReliableImageSearch(&sX, &sY, SETTINGS["StayOnlineImage"], stayOnlineArea)) {
        Info("Refresh skipped: Stay Online window visible.")
        return
    }
    Click(SETTINGS["RefreshX"], SETTINGS["RefreshY"])
    Info("Refresh performed - Time-based")
    STATE["lastRefreshTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
}

MonitorTargetTimer(*) {
    global SETTINGS, STATE
    static lastIdleCheck := 0
    
    ; تحقق من الخمول كل 10 ثواني فقط
    if (A_TickCount - lastIdleCheck < 10000)
        return
    lastIdleCheck := A_TickCount
    
    if (STATE["onlineStatus"] != "Online" || STATE["isMonitoringPaused"]) {
        if (STATE["isAlarmPlaying"] && STATE["onlineStatus"] != "Online") {
            STATE["isAlarmPlaying"] := false
            SetTimer(AlarmBeep, 0)
            Info("Alarm stopped because status is no longer 'Online'.")
        }
        return
    }
    targetArea := Map("x1", SETTINGS["TargetAreaTopLeftX"], "y1", SETTINGS["TargetAreaTopLeftY"], "x2", SETTINGS["TargetAreaBottomRightX"], "y2", SETTINGS["TargetAreaBottomRightY"])
    local foundX, foundY
    if (!ReliableImageSearch(&foundX, &foundY, SETTINGS["TargetImage"], targetArea)) {
        ; تأكد من الغياب 3 مرات خلال 3 ثواني (مرة كل ثانية)
        confirmedMissing := true
        Loop 3 {
            Sleep(1000)
            if (ReliableImageSearch(&foundX, &foundY, SETTINGS["TargetImage"], targetArea)) {
                confirmedMissing := false
                Info("Target word re-appeared during triple-check. No alarm.")
                break
            }
        }
        if (!confirmedMissing) {
            ; لا إنذار
            return
        }

        idlePhysical := A_TimeIdlePhysical
        idleCombined := Max(idlePhysical, A_TickCount - (STATE.Has("lastUserActivity") ? STATE["lastUserActivity"] : A_TickCount))
        idleOk := idleCombined >= SETTINGS["UserIdleThreshold"]
        if !idleOk {
            if (STATE["isAlarmPlaying"]) {
                STATE["isAlarmPlaying"] := false
                SetTimer(AlarmBeep, 0)
                Info("Alarm stopped due to user activity.")
            }
            return
        }

        ; --- منطق التحقق من زر Stay Online قبل الإنذار ---
        stayOnlineArea := Map("x1", SETTINGS["StayOnlineAreaTopLeftX"], "y1", SETTINGS["StayOnlineAreaTopLeftY"], "x2", SETTINGS["StayOnlineAreaBottomRightX"], "y2", SETTINGS["StayOnlineAreaBottomRightY"])
        local sX, sY
        stayVisible := ReliableImageSearch(&sX, &sY, SETTINGS["StayOnlineImage"], stayOnlineArea)
        if (stayVisible) {
            Info("Target missing BUT Stay Online window is visible. Will attempt to dismiss it and re-check target.")
            ClickStayOnlineButton()
            attempts := 0
            Loop 5 {
                Sleep(1000)
                attempts++
                stillStay := ReliableImageSearch(&sX, &sY, SETTINGS["StayOnlineImage"], stayOnlineArea)
                targetBack := ReliableImageSearch(&foundX, &foundY, SETTINGS["TargetImage"], targetArea)
                if (!stillStay && targetBack) {
                    Info("Target is back after dismissing Stay Online. No alarm.")
                    return
                }
                if (!stillStay && !targetBack) {
                    Info("Stay Online dismissed but Target still missing after " . attempts . "s.")
                    break
                }
                if (stillStay && attempts >= 5) {
                    Info("Stay Online still visible after retries. Will raise alarm.")
                    break
                }
            }
            ; احفظ لقطة للمنطقة الحالية في مجلد target word قبل الإشعار
            try SaveTargetWordScreenshot("target_missing")

            cause := "Unknown"
            if (ReliableImageSearch(&sX, &sY, SETTINGS["StayOnlineImage"], stayOnlineArea))
                cause := "StayOnlineStillVisible"
            else
                cause := "TargetStillMissingAfterDismiss"

            if !STATE["isAlarmPlaying"] {
                STATE["isAlarmPlaying"] := true
                ShowLocalNotification("🚨 ALARM: Target Word NOT FOUND!")
                details := Map(
                    "Cause", cause,
                    "Status", STATE.Has("onlineStatus") ? STATE["onlineStatus"] : "N/A",
                    "User Idle", (Floor(idleCombined / 60000)) . "m",
                    "Battery", GetBatteryPercent() . "%"
                )
                SendRichTelegramNotification("🚨 ALARM: Target Word Missing!", details)
                SetTimer(AlarmBeep, 300)
            }
            return
        }

        ; لو مفيش Stay Online: احفظ لقطة ثم أنذر
        try SaveTargetWordScreenshot("target_missing")
        if !STATE["isAlarmPlaying"] {
            STATE["isAlarmPlaying"] := true
            ShowLocalNotification("🚨 ALARM: Target Word NOT FOUND!")
            details := Map(
                "Cause", "TargetMissingNoStayOnline",
                "Status", STATE.Has("onlineStatus") ? STATE["onlineStatus"] : "N/A",
                "User Idle", (Floor(idleCombined / 60000)) . "m",
                "Battery", GetBatteryPercent() . "%"
            )
            SendRichTelegramNotification("🚨 ALARM: Target Word Missing!", details)
            SetTimer(AlarmBeep, 300)
        }
    } else {
        if (STATE["isAlarmPlaying"]) {
            STATE["isAlarmPlaying"] := false
            SetTimer(AlarmBeep, 0)
            STATE["lastUserActivity"] := A_TickCount + SETTINGS["WordMonitorUserIdleReset"]
            Info("Alarm stopped - Target word found.")
        }
    }
}

; Removed duplicate AlarmBeep - consolidated implementation exists later in file

ClickStayOnlineButton() {
    global SETTINGS, STATE
    static clickingBusy := false
    
    ; منع التداخل في عمليات النقر
    if (clickingBusy)
        return false
    clickingBusy := true

    try {
        if (!WinExist(SETTINGS["FrontlineWinTitle"]))
            return false

        ; توحيد نظام الإحداثيات
        CoordMode "Mouse", "Screen"
        
        stayOnlineArea := Map("x1", SETTINGS["StayOnlineAreaTopLeftX"], "y1", SETTINGS["StayOnlineAreaTopLeftY"], 
                             "x2", SETTINGS["StayOnlineAreaBottomRightX"], "y2", SETTINGS["StayOnlineAreaBottomRightY"])
        local foundX, foundY

        if (ReliableImageSearch(&foundX, &foundY, SETTINGS["StayOnlineImage"], stayOnlineArea)) {
            Info("Stay Online button found. Attempting to click.")
            ShowLocalNotification("❗ Stay Online window appeared!")
            QueueTelegram(Map("type", "text", "title", "❗ Stay Online Window Detected", 
                           "details", Map("Action", "Attempting to click the button automatically.")))

            ; استخدام الصورة المخزنة مؤقتاً من ReliableImageSearch
            clickX := foundX + 10
            clickY := foundY + 10

            ; محاولات النقر مع تأخير مناسب
            Loop 3 {
                BlockInput true
                try {
                    MouseMove clickX, clickY
                    Sleep 100
                    Click
                    Sleep 500
                } finally {
                    BlockInput false
                }

                ; التحقق من اختفاء الزر
                Sleep 1000
                if (!ReliableImageSearch(&foundX, &foundY, SETTINGS["StayOnlineImage"], stayOnlineArea)) {
                    Info("Stay Online button successfully clicked and disappeared.")
                    return true
                }
                Sleep 500
            }

            ; تنبيه في حالة الفشل
            if !STATE["isAlarmPlaying"] {
                STATE["isAlarmPlaying"] := true
                ShowLocalNotification("🚨 ALARM: Stay Online button is STUCK!")
                QueueTelegram(Map("type", "text", "title", "🚨 ALARM: Stay Online Button Stuck",
                               "details", Map("Attempts", 3, "Action", "Manual intervention required!")))
                SetTimer(AlarmBeep, 300)
            }
        }
    } finally {
        clickingBusy := false
    }
    return false
}

; --- Helpers for status duration tracking and daily report ---

UpdateStatusDurations(newStatus) {
    global STATE
    try {
        if !IsObject(STATE) || !STATE.Has("statusDurations")
            return
        nowTick := A_TickCount
        prev := STATE.Has("currentStatus") ? STATE["currentStatus"] : "Unknown"
        delta := nowTick - (STATE.Has("lastStatusChangeTick") ? STATE["lastStatusChangeTick"] : nowTick)
        if (delta < 0)
            delta := 0
        if (STATE["statusDurations"].Has(prev))
            STATE["statusDurations"][prev] += delta
        else
            STATE["statusDurations"][prev] := delta
        STATE["lastStatusChangeTick"] := nowTick
        STATE["currentStatus"] := newStatus
    } catch {
        ; ignore
    }
}

FormatMs(ms) {
    totalSec := ms // 1000
    h := totalSec // 3600
    m := (totalSec // 60) - (h * 60)
    s := Mod(totalSec, 60)
    return Format("{:02}h {:02}m {:02}s", h, m, s)
}

ScheduleNextDailyReport(hour := 9, minute := 0) {
    ; احسب الوقت حتى 9 صباحًا القادم
    today0900 := FormatTime(A_Now, "yyyyMMdd") . Format("{:02}{:02}00", hour, minute)
    nextRun := (A_Now >= today0900) ? DateAdd(today0900, 1, "Days") : today0900
    ; كان هنا استخدام DateDiff بوحدة "ms" مما يعيد 0 دائماً في v2
    ; نستخدم الثواني ثم نحولها إلى ميلي ثانية، ونلغي أي مؤقّت سابق قبل إعادة الجدولة
    SetTimer(DailyReportTimer, 0)
    secUntil := DateDiff(nextRun, A_Now, "Seconds")
    if (secUntil < 1) {
        secUntil := 1
    }
    msUntil := secUntil * 1000
    SetTimer(DailyReportTimer, -msUntil)
    Info("Daily report scheduled at: " . FormatTime(nextRun, "yyyy-MM-dd HH:mm:ss"))
}

DailyReportTimer(*) {
    static running := false
    if (running) {
        Warn("DailyReportTimer skipped because a previous run is still in progress.")
        return
    }
    running := true
    try {
        global STATE
        ; اجمع آخر جزء حتى لحظة التقرير
        ; كان يتم الرجوع إلى STATE[\"currentStatus\"] وهو غير موجود، نستخدم onlineStatus
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
        SendRichTelegramNotification("📊 Daily Report (since last 09:00)", details)
        STATE["lastTelegramStatus"] := "Daily report sent at " . FormatTime(A_Now, "HH:mm:ss")

        ; صفّر العدادات لبداية دورة جديدة
        for k, _ in STATE["statusDurations"]
            STATE["statusDurations"][k] := 0
        STATE["lastStatusChangeTick"] := A_TickCount
        STATE["lastReportTime"] := A_Now

        ; أعد الجدولة ليوم الغد (بعد إصلاح الحساب سيُضبط لوقت صحيح)
        ScheduleNextDailyReport()
    } finally {
        running := false
    }
}

; --- Internet Check Timer ---
NetCheckTimer(*) {
    global STATE, SETTINGS
    online := HttpCheckInternet(SETTINGS.Has("NetCheckTimeoutMs") ? SETTINGS["NetCheckTimeoutMs"] : 800)
    if (online) {
        if (!STATE["netOnline"]) {
            STATE["netOnline"] := true
            if (STATE["netOutageOngoing"]) {
                outage := A_TickCount - STATE["netLastChangeTick"]
                if (outage < 0)
                    outage := 0
                STATE["netDowntimeMs"] += outage
                STATE["netOutageOngoing"] := false
                STATE["netLastChangeTick"] := A_TickCount
                SendRichTelegramNotification("✅ Internet Restored", Map(
                    "Outage Duration", FormatMs(outage),
                    "Total Downtime", FormatMs(STATE["netDowntimeMs"])
                ))
            }
            FlushTelegramQueue()
            ; لو كان إنذار الشبكة شغال، أوقفه الآن (وأبقِ أي إنذار آخر كما هو)
            if (STATE.Has("isNetAlarmPlaying") && STATE["isNetAlarmPlaying"]) {
                STATE["isNetAlarmPlaying"] := false
                if !(STATE.Has("isAlarmPlaying") && STATE["isAlarmPlaying"])
                    SetTimer(AlarmBeep, 0)
            }
        }
    } else {
        if (STATE["netOnline"]) {
            STATE["netOnline"] := false
            STATE["netOutageOngoing"] := true
            STATE["netLastChangeTick"] := A_TickCount
            ShowLocalNotification("❌ Internet DISCONNECTED")
            QueueTelegram(Map(
                "type", "text",
                "title", "❌ Internet Disconnected",
                "details", Map("Time", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"))
            ))
            STATE["lastTelegramStatus"] := FormatTime(A_Now, "HH:mm:ss") . " - QUEUED: Internet Disconnected"
            ; شغِّل إنذار الشبكة فورًا حتى لو الانقطاع ثانية واحدة
            STATE["isNetAlarmPlaying"] := true
            if !(STATE.Has("isAlarmPlaying") && STATE["isAlarmPlaying"]) {
                SetTimer(AlarmBeep, 300)
            }
        }
    }
}

; --- Battery Check Timer ---
BatteryCheckTimer(*) {
    global SETTINGS, STATE
    static lastBatteryCheck := 0
    
    ; تحقق من البطارية كل 10 دقائق (600000 مللي ثانية)
    if (A_TickCount - lastBatteryCheck < 600000)
        return
    lastBatteryCheck := A_TickCount
    
    thr := SETTINGS.Has("BatteryAlertThreshold") ? SETTINGS["BatteryAlertThreshold"] : 20
    cdMs := SETTINGS.Has("BatteryAlertCooldown") ? SETTINGS["BatteryAlertCooldown"] : 1800000
    pct := GetBatteryPercent()
    
    if (pct >= 0 && pct <= thr) {
        now := A_TickCount
        last := STATE.Has("lastBatteryAlertTick") ? STATE["lastBatteryAlertTick"] : 0
        if (now - last >= cdMs) {
            STATE["lastBatteryAlertTick"] := now
            ShowLocalNotification("⚠ Low Battery: " . pct . "%")
            SendRichTelegramNotification("⚠ Low Battery", Map("Battery", pct . "%", "Time", FormatTime(A_Now, "HH:mm:ss")))
        }
    }
}

AlarmBeep(*) {
    global SETTINGS, STATE
    ; استمر بالتصفير إذا كان هناك أي نوع من الإنذارات: عام أو شبكة
    activeAlarm := (STATE.Has("isAlarmPlaying") && STATE["isAlarmPlaying"]) || (STATE.Has("isNetAlarmPlaying") && STATE["isNetAlarmPlaying"])
    if (!activeAlarm) {
        SetTimer(AlarmBeep, 0)
        return
    }
    SoundBeep(SETTINGS["BeepFrequency"], SETTINGS["BeepDuration"])
}

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
    local goodStates := ["Online", "WorkOnMyTicket", "Break", "Launch"]
    for stateName in goodStates {
        if (ReliableImageSearch(&foundX, &foundY, SETTINGS[stateName . "Image"], statusArea)) {
            if (STATE["onlineStatus"] != stateName) {
                Info("Status changed to: " . stateName)
                UpdateStatusDurations(stateName) ; تجميع مدة الحالة السابقة وتحديث الحالية
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
    ClickStayOnlineButton()
    STATE["lastStayOnlineClickTime"] := A_TickCount
    STATE["lastStayOnlineTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
}

RefreshTimer(*) {
    global SETTINGS, STATE
    if (!WinExist(SETTINGS["FrontlineWinTitle"]))
        return
    Click(SETTINGS["RefreshX"], SETTINGS["RefreshY"])
    Info("Refresh performed - Time-based")
    STATE["lastRefreshTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
}

MonitorTargetTimer(*) {
    global SETTINGS, STATE
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
        idlePhysical := A_TimeIdlePhysical  ; خمول فعلي من النظام
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
            ; انتظر حتى 5 ثواني لإختفاء الزر وعودة التارجت
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
            ; هنا حالتان: الزر اختفى والهدف لسه مش موجود، أو الزر لسه ظاهر
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

        ; لو مفيش Stay Online ظهر، نتبع سلوك الإنذار المعتاد
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

AlarmBeep(*) {
    global SETTINGS, STATE
    if !STATE.Has("isAlarmPlaying") || !STATE["isAlarmPlaying"] {
        SetTimer(AlarmBeep, 0)
        return
    }
    SoundBeep(SETTINGS["BeepFrequency"], SETTINGS["BeepDuration"])
}

ClickStayOnlineButton() {
    global SETTINGS, STATE
    if (!WinExist(SETTINGS["FrontlineWinTitle"]))
        return
    stayOnlineArea := Map("x1", SETTINGS["StayOnlineAreaTopLeftX"], "y1", SETTINGS["StayOnlineAreaTopLeftY"], "x2", SETTINGS["StayOnlineAreaBottomRightX"], "y2", SETTINGS["StayOnlineAreaBottomRightY"])
    local foundX, foundY
    if (ReliableImageSearch(&foundX, &foundY, SETTINGS["StayOnlineImage"], stayOnlineArea)) {
        Info("Stay Online button found. Attempting to click.")
        ShowLocalNotification("❗ Stay Online window appeared!")
        ; كان هنا إرسال متزامن لـ Telegram — سبب محتمل للتهنيج
        ; SendRichTelegramNotification("❗ Stay Online Window Detected", Map("Action", "Attempting to click the button automatically."))
        ; نضيف الرسالة للطابور بدلاً من الحجب
        QueueTelegram(Map("type", "text", "title", "❗ Stay Online Window Detected", "details", Map("Action", "Attempting to click the button automatically.")))
        pBitmap := Gdip_CreateBitmapFromFile(SETTINGS["StayOnlineImage"])
        if !pBitmap {
            Warn("Could not load StayOnlineImage to get its dimensions.")
            Click(foundX + 10, foundY + 10)
            return
        }
        imageWidth := Gdip_GetImageWidth(pBitmap)
        imageHeight := Gdip_GetImageHeight(pBitmap)
        Gdip_DisposeImage(pBitmap)
        clickX := foundX + (imageWidth / 2)
        clickY := foundY + (imageHeight / 2)
        Loop 5 {
            Info("Clicking Stay Online button, attempt " . A_Index)
            Click(clickX, clickY)
            Sleep(1000)
            if (!ReliableImageSearch(&foundX, &foundY, SETTINGS["StayOnlineImage"], stayOnlineArea)) {
                Info("Stay Online button successfully clicked and disappeared.")
                return
            }
            Info("Verification failed, button still visible. Retrying...")
        }
        Info("CRITICAL: Failed to dismiss Stay Online button after 5 attempts.")
        if !STATE["isAlarmPlaying"] {
            STATE["isAlarmPlaying"] := true
            ShowLocalNotification("🚨 ALARM: Stay Online button is STUCK!")
            ; برضه نخلي التنبيه يتصف في الطابور لتفادي الحجب
            ; SendRichTelegramNotification("🚨 ALARM: Stay Online Button Stuck", Map("Attempts", 5, "Action", "Manual intervention required!"))
            QueueTelegram(Map("type", "text", "title", "🚨 ALARM: Stay Online Button Stuck", "details", Map("Attempts", 5, "Action", "Manual intervention required!")))
            SetTimer(AlarmBeep, 300)
        }
    }
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
    global STATE
    online := HttpCheckInternet(2500)
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
        }
    }
}

; --- Battery Check Timer ---
BatteryCheckTimer(*) {
    global SETTINGS, STATE
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

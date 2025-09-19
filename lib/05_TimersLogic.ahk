; ============================================================
; 05_TimersLogic.ahk (v3 - Using Rich Notifications & Photos)
; ============================================================

; ============================================================
; StatusCheckTimer - updated to detect Coaching and use image lists
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

    ; ثانياً: اكتشاف حالة Coaching (لا نقوم بأي إجراء، فقط تحديث الحالة)
    if (SETTINGS.Has("CoachingImageList") && SETTINGS["CoachingImageList"].Length > 0) {
        for cimg in SETTINGS["CoachingImageList"] {
            if (ReliableImageSearch(&foundX, &foundY, cimg, statusArea)) {
                if (STATE["onlineStatus"] != "Coaching") {
                    Info("Status changed to: Coaching")
                    UpdateStatusDurations("Coaching")
                    STATE["onlineStatus"] := "Coaching"
                    STATE["offlineFixAttempts"] := 0
                }
                knownStatusFound := true
                break
            }
        }
        if (knownStatusFound)
            return
    } else if (SETTINGS.Has("CoachingImage") && FileExist(SETTINGS["CoachingImage"])) {
        if (ReliableImageSearch(&foundX, &foundY, SETTINGS["CoachingImage"], statusArea)) {
            if (STATE["onlineStatus"] != "Coaching") {
                Info("Status changed to: Coaching")
                UpdateStatusDurations("Coaching")
                STATE["onlineStatus"] := "Coaching"
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
            UpdateStatusDurations("Offline")
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
        UpdateStatusDurations("Unknown")
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
    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
    Sleep(1500)
    Click(SETTINGS["FixStep2X"], SETTINGS["FixStep2Y"])
    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
    Sleep(1500)
    Click(SETTINGS["FixStep3X"], SETTINGS["FixStep3Y"])
    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
    Sleep(1500)
    Info("Fix clicks performed.")
}

; يحرك الماوس بعيدًا عن منطقة الداشبورد إذا كانت تختفي عند المرور عليها
NudgeMouseAwayFromDashboard() {
    global SETTINGS, STATE
    try {
        if (SETTINGS.Has("DashboardHideOnHover") && SETTINGS["DashboardHideOnHover"]) {
            CoordMode "Mouse", "Screen"
            MouseMove A_ScreenWidth - 5, A_ScreenHeight - 5, 0
            STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
            Sleep(100)
        }
    } catch {
    }
}

; ============================================================
; Helper: ImageListSearch - search across multiple images
; ============================================================
ImageListSearch(&outX, &outY, images, area) {
    try {
        if (IsObject(images) && images.Length > 0) {
            for img in images {
                if (ReliableImageSearch(&outX, &outY, img, area))
                    return true
            }
        }
    } catch {
    }
    return false
}

; --- Activity Monitor Timer ---
ActivityMonitorTimer(*) {
    global STATE, SETTINGS
    static lastMouseX := 0, lastMouseY := 0
    static lastIdlePhysical := A_TimeIdlePhysical

    idlePhysical := A_TimeIdlePhysical
    idleSinceInternal := A_TickCount - (STATE.Has("lastUserActivity") ? STATE["lastUserActivity"] : A_TickCount)
    keyboardOnly := (SETTINGS.Has("ActivityKeyboardOnly") && SETTINGS["ActivityKeyboardOnly"]) ? true : false
    idleCombined := keyboardOnly ? idleSinceInternal : Min(idlePhysical, idleSinceInternal)

    local mx := 0, my := 0
    MouseGetPos &mx, &my
    dx := Abs(mx - lastMouseX)
    dy := Abs(my - lastMouseY)
    moveThr := SETTINGS.Has("ActivityMoveThresholdPx") ? SETTINGS["ActivityMoveThresholdPx"] : 2
    moved := (dx >= moveThr || dy >= moveThr)

    evType := "none"
    if (!keyboardOnly && moved) {
        if (STATE.Has("synthInputUntil") && A_TickCount < STATE["synthInputUntil"]) {
            evType := "none"
        } else {
            evType := "mouse"
        }
    } else {
        keyResetMs := SETTINGS.Has("ActivityKeyboardResetMs") ? SETTINGS["ActivityKeyboardResetMs"] : 120
        ; التقط نشاط الكيبورد عندما يقل A_TimeIdlePhysical بشكل ملحوظ بين دورتين
        if (idlePhysical < keyResetMs || (lastIdlePhysical - idlePhysical) >= keyResetMs) {
            evType := "keyboard"
        }
    }

    gateMs := SETTINGS.Has("ActivityIdleGateMs") ? SETTINGS["ActivityIdleGateMs"] : 3000
    wasIdleLong := (lastIdlePhysical >= gateMs) || (idleSinceInternal >= gateMs)

    if (evType != "none") {
        STATE["lastActivityType"] := evType
        ; إعادة ضبط مباشرة إذا كان هناك نشاط، أو كان المستخدم خامل لفترة طويلة ثم تحرك
        if (wasIdleLong || evType = "mouse" || evType = "keyboard") {
            STATE["lastUserActivity"] := A_TickCount
            if (SETTINGS.Has("ActivityDebug") && SETTINGS["ActivityDebug"]) {
                Info("Activity: " . evType . " (dx=" . dx . ", dy=" . dy . ", idle=" . idlePhysical . ")")
            }
        }
    }

    lastMouseX := mx
    lastMouseY := my
    lastIdlePhysical := idlePhysical
}

; --- تحديث StayOnlineTimer لاستخدام idleCombined ---
StayOnlineTimer(*) {
    global SETTINGS, STATE
    if (!WinExist(SETTINGS["FrontlineWinTitle"]))
        return
    idlePhysical := A_TimeIdlePhysical
    idleSinceInternal := A_TickCount - (STATE.Has("lastUserActivity") ? STATE["lastUserActivity"] : A_TickCount)
    keyboardOnly := (SETTINGS.Has("ActivityKeyboardOnly") && SETTINGS["ActivityKeyboardOnly"]) ? true : false
    idleCombined := keyboardOnly ? idleSinceInternal : Min(idlePhysical, idleSinceInternal)
    if (idleCombined < SETTINGS["UserIdleThreshold"]) ; لا ينفّذ أثناء النشاط الحقيقي
        return
    current := STATE.Has("onlineStatus") ? STATE["onlineStatus"] : "Unknown"
    if (current != "Online")
        return
    res := ClickStayOnlineButton()
    if (res) {
        STATE["lastStayOnlineClickTime"] := A_TickCount
        STATE["lastStayOnlineTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
        Info("Stay Online click performed - timestamp updated.")
        STATE["actionBusyUntil"] := A_TickCount + 3000
        STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
    } else {
        stayOnlineArea := Map("x1", SETTINGS["StayOnlineAreaTopLeftX"], "y1", SETTINGS["StayOnlineAreaTopLeftY"], "x2", SETTINGS["StayOnlineAreaBottomRightX"], "y2", SETTINGS["StayOnlineAreaBottomRightY"])
        cx := (stayOnlineArea["x1"] + stayOnlineArea["x2"]) // 2
        cy := (stayOnlineArea["y1"] + stayOnlineArea["y2"]) // 2
        CoordMode "Mouse", "Screen"
        MouseMove cx, cy, 0
        Click
        STATE["lastStayOnlineClickTime"] := A_TickCount
        STATE["lastStayOnlineTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
        STATE["actionBusyUntil"] := A_TickCount + 3000
        STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
        Info("Stay Online: button not detected, performed fallback center click.")
        Sleep 1000
        if (ClickStayOnlineButton()) {
            STATE["lastStayOnlineClickTime"] := A_TickCount
            STATE["lastStayOnlineTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
            STATE["actionBusyUntil"] := A_TickCount + 3000
            STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
        }
    }
}

; --- تحديث RefreshTimer لاستخدام idleCombined ومنع التحريك أثناء النشاط ---
RefreshTimer(*) {
    global SETTINGS, STATE
    if (!WinExist(SETTINGS["FrontlineWinTitle"]))
        return
    current := STATE.Has("onlineStatus") ? STATE["onlineStatus"] : "Unknown"
    if (current != "Online") {
        Info("Refresh skipped: status is " . current)
        return
    }
    idlePhysical := A_TimeIdlePhysical
    idleSinceInternal := A_TickCount - (STATE.Has("lastUserActivity") ? STATE["lastUserActivity"] : A_TickCount)
    keyboardOnly := (SETTINGS.Has("ActivityKeyboardOnly") && SETTINGS["ActivityKeyboardOnly"]) ? true : false
    idleCombined := keyboardOnly ? idleSinceInternal : Min(idlePhysical, idleSinceInternal)
    if (idleCombined < SETTINGS["UserIdleThreshold"]) {
        Info("Refresh skipped: user active (idleCombined=" . idleCombined . ", thr=" . SETTINGS["UserIdleThreshold"] . ").")
        return
    }
    if (STATE.Has("actionBusyUntil") && A_TickCount < STATE["actionBusyUntil"]) {
        Info("Refresh skipped (cooldown after action).")
        return
    }

    stayOnlineArea := Map("x1", SETTINGS["StayOnlineAreaTopLeftX"], "y1", SETTINGS["StayOnlineAreaTopLeftY"], "x2", SETTINGS["StayOnlineAreaBottomRightX"], "y2", SETTINGS["StayOnlineAreaBottomRightY"])
    local sX, sY
    stayVisible := (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0)
        ? ImageListSearch(&sX, &sY, SETTINGS["StayOnlineImageList"], stayOnlineArea)
        : ReliableImageSearch(&sX, &sY, SETTINGS["StayOnlineImage"], stayOnlineArea)
    if (stayVisible) {
        Info("Stay Online button found before refresh - clicking it first")
        Click(sX, sY)
        STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
        Sleep(1000)
        stillVisible := (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0)
            ? ImageListSearch(&sX, &sY, SETTINGS["StayOnlineImageList"], stayOnlineArea)
            : ReliableImageSearch(&sX, &sY, SETTINGS["StayOnlineImage"], stayOnlineArea)
        if (stillVisible) {
            Info("Stay Online window still visible after click - skipping refresh")
            return
        }
    }

    Info("Refresh proceeding: idleCombined=" . idleCombined . " >= thr=" . SETTINGS["UserIdleThreshold"] . ".")
    Click(SETTINGS["RefreshX"], SETTINGS["RefreshY"])
    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
    CoordMode "Mouse", "Screen"
    tx := Min(A_ScreenWidth - 5, SETTINGS["RefreshX"] + 150)
    ty := Min(A_ScreenHeight - 5, SETTINGS["RefreshY"] + 150)
    MouseMove tx, ty, 0
    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
    Info("Refresh performed - Time-based")
    STATE["lastRefreshTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
    delayMs := SETTINGS.Has("PostRefreshDelayMs") ? SETTINGS["PostRefreshDelayMs"] : 2500
    STATE["actionBusyUntil"] := A_TickCount + delayMs
}

MonitorTargetTimer(*) {
    global SETTINGS, STATE
    static lastIdleCheck := 0
    ; تجنّب الفحص أثناء نافذة الانشغال بعد أي إجراء (مثل Refresh أو Stay Online)
    if (STATE.Has("actionBusyUntil") && A_TickCount < STATE["actionBusyUntil"]) {
        ; Info("MonitorTarget skipped (post action delay)")
        return
    }
    if (A_TickCount - lastIdleCheck < 10000)
        return
    lastIdleCheck := A_TickCount
    ; إزالة تحريك الماوس الدوري لتجنّب إزعاج المستخدم
    ; NudgeMouseAwayFromDashboard()

    allowed := SETTINGS.Has("TargetMonitorStatuses") ? SETTINGS["TargetMonitorStatuses"] : ["Online"]
    current := STATE.Has("onlineStatus") ? STATE["onlineStatus"] : "Unknown"
    isAllowed := false
    for st in allowed {
        if (current = st) {
            isAllowed := true
            break
        }
    }
    if (!isAllowed || STATE["isMonitoringPaused"]) {
        if (STATE["isAlarmPlaying"]) {
            STATE["isAlarmPlaying"] := false
            SetTimer(AlarmBeep, 0)
            Info("Alarm stopped because status is not in allowed monitor statuses.")
        }
        return
    }

    ; تعريف منطقة البحث عن التارجت
    targetArea := Map("x1", SETTINGS["TargetAreaTopLeftX"], "y1", SETTINGS["TargetAreaTopLeftY"], "x2", SETTINGS["TargetAreaBottomRightX"], "y2", SETTINGS["TargetAreaBottomRightY"])
    local foundX, foundY
    hasTarget := (SETTINGS.Has("TargetImageList") && SETTINGS["TargetImageList"].Length > 0)
        ? ImageListSearch(&foundX, &foundY, SETTINGS["TargetImageList"], targetArea)
        : ReliableImageSearch(&foundX, &foundY, SETTINGS["TargetImage"], targetArea)
    if (!hasTarget) {
        confirmedMissing := true
        Loop 3 {
            Sleep(1000)
            if ((SETTINGS.Has("TargetImageList") && ImageListSearch(&foundX, &foundY, SETTINGS["TargetImageList"], targetArea))
                || ReliableImageSearch(&foundX, &foundY, SETTINGS["TargetImage"], targetArea)) {
                confirmedMissing := false
                Info("Target word re-appeared during triple-check. No alarm.")
                break
            }
        }
        if (!confirmedMissing) {
            return
        }

        idlePhysical := A_TimeIdlePhysical
        idleSinceInternal := A_TickCount - (STATE.Has("lastUserActivity") ? STATE["lastUserActivity"] : A_TickCount)
        keyboardOnly := (SETTINGS.Has("ActivityKeyboardOnly") && SETTINGS["ActivityKeyboardOnly"]) ? true : false
        idleCombined := keyboardOnly ? idleSinceInternal : Min(idlePhysical, idleSinceInternal)
        idleOk := idleCombined >= SETTINGS["UserIdleThreshold"]
        if !idleOk {
            if (STATE["isAlarmPlaying"]) {
                STATE["isAlarmPlaying"] := false
                SetTimer(AlarmBeep, 0)
                Info("Alarm stopped due to user activity.")
            }
            return
        }

        stayOnlineArea := Map("x1", SETTINGS["StayOnlineAreaTopLeftX"], "y1", SETTINGS["StayOnlineAreaTopLeftY"], "x2", SETTINGS["StayOnlineAreaBottomRightX"], "y2", SETTINGS["StayOnlineAreaBottomRightY"])
        local sX, sY
        stayVisible := (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0)
            ? ImageListSearch(&sX, &sY, SETTINGS["StayOnlineImageList"], stayOnlineArea)
            : ReliableImageSearch(&sX, &sY, SETTINGS["StayOnlineImage"], stayOnlineArea)
        if (stayVisible) {
            Info("Target missing BUT Stay Online window is visible. Will attempt to dismiss it and re-check target.")
            ClickStayOnlineButton()
            attempts := 0
            Loop 5 {
                Sleep(1000)
                attempts++
                stillStay := (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0)
                    ? ImageListSearch(&sX, &sY, SETTINGS["StayOnlineImageList"], stayOnlineArea)
                    : ReliableImageSearch(&sX, &sY, SETTINGS["StayOnlineImage"], stayOnlineArea)
                targetBack := (SETTINGS.Has("TargetImageList") && ImageListSearch(&foundX, &foundY, SETTINGS["TargetImageList"], targetArea))
                    || ReliableImageSearch(&foundX, &foundY, SETTINGS["TargetImage"], targetArea)
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
            try SaveTargetWordScreenshot("target_missing")

            cause := "Unknown"
            if ((SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0 && ImageListSearch(&sX, &sY, SETTINGS["StayOnlineImageList"], stayOnlineArea))
                || ReliableImageSearch(&sX, &sY, SETTINGS["StayOnlineImage"], stayOnlineArea))
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
                    "Battery", (STATE.Has("batteryPercent") ? STATE["batteryPercent"] : GetBatteryPercent()) . "%"
                )
                SendRichTelegramNotification("🚨 ALARM: Target Word Missing!", details)
                SetTimer(AlarmBeep, 300)
            }
            return
        }

        try SaveTargetWordScreenshot("target_missing")
        if !STATE["isAlarmPlaying"] {
            STATE["isAlarmPlaying"] := true
            ShowLocalNotification("🚨 ALARM: Target Word NOT FOUND!")
            details := Map(
                "Cause", "TargetMissingNoStayOnline",
                "Status", STATE.Has("onlineStatus") ? STATE["onlineStatus"] : "N/A",
                "User Idle", (Floor(idleCombined / 60000)) . "m",
                "Battery", (STATE.Has("batteryPercent") ? STATE["batteryPercent"] : GetBatteryPercent()) . "%"
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
    if (clickingBusy)
        return false
    clickingBusy := true

    try {
        if (!WinExist(SETTINGS["FrontlineWinTitle"]))
            return false

        NudgeMouseAwayFromDashboard()
        CoordMode "Mouse", "Screen"
        stayOnlineArea := Map("x1", SETTINGS["StayOnlineAreaTopLeftX"], "y1", SETTINGS["StayOnlineAreaTopLeftY"], 
                             "x2", SETTINGS["StayOnlineAreaBottomRightX"], "y2", SETTINGS["StayOnlineAreaBottomRightY"])
        local foundX, foundY

        found := (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0)
            ? ImageListSearch(&foundX, &foundY, SETTINGS["StayOnlineImageList"], stayOnlineArea)
            : ReliableImageSearch(&foundX, &foundY, SETTINGS["StayOnlineImage"], stayOnlineArea)
        if (found) {
            Info("Stay Online button found. Attempting to click.")
            ShowLocalNotification("❗ Stay Online window appeared!")
            QueueTelegram(Map("type", "text", "title", "❗ Stay Online Window Detected", 
                           "details", Map("Action", "Attempting to click the button automatically.")))
            clickX := foundX + 10
            clickY := foundY + 10
            Loop 3 {
                BlockInput true
                try {
                    MouseMove clickX, clickY
                    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
                    Sleep(100)
                    Click
                    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
                    Sleep(500)
                } finally {
                    BlockInput false
                }
                local sx, sy
                still := (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0)
                    ? ImageListSearch(&sx, &sy, SETTINGS["StayOnlineImageList"], stayOnlineArea)
                    : ReliableImageSearch(&sx, &sy, SETTINGS["StayOnlineImage"], stayOnlineArea)
                if (!still) {
                    STATE["lastStayOnlineClickTime"] := A_TickCount
                    STATE["lastStayOnlineTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
                    Info("Stay Online button clicked successfully.")
                    return true
                }
            }
            Warn("Failed to dismiss Stay Online after multiple attempts.")
            return false
        } else {
            return false
        }
    } finally {
        clickingBusy := false
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
    global STATE, SETTINGS
    online := HttpCheckInternet(SETTINGS.Has("NetCheckTimeoutMs") ? SETTINGS["NetCheckTimeoutMs"] : 800)
    muted := STATE.Has("netAlarmMuteUntil") && (A_TickCount < STATE["netAlarmMuteUntil"])

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
            ; أوقف إنذار النت عند عودة الاتصال
            if (STATE.Has("isNetAlarmPlaying") && STATE["isNetAlarmPlaying"]) {
                STATE["isNetAlarmPlaying"] := false
                if !(STATE.Has("isAlarmPlaying") && STATE["isAlarmPlaying"]) {
                    SetTimer(AlarmBeep, 0)
                }
            }
        }
        ; صفّر مرجع بدء مؤهل إنذار الشبكة إذا كان موجوداً
        if (STATE.Has("netAlarmCandidateSince")) {
            STATE.Delete("netAlarmCandidateSince")
        }
    } else {
        if (STATE["netOnline"]) {
            ; انتقال إلى حالة غير متصل
            STATE["netOnline"] := false
            STATE["netOutageOngoing"] := true
            STATE["netLastChangeTick"] := A_TickCount
            STATE["netAlarmCandidateSince"] := A_TickCount
            ShowLocalNotification("❌ Internet DISCONNECTED")
            QueueTelegram(Map(
                "type", "text",
                "title", "❌ Internet Disconnected",
                "details", Map("Time", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"))
            ))
            STATE["lastTelegramStatus"] := FormatTime(A_Now, "HH:mm:ss") . " - QUEUED: Internet Disconnected"
            ; لا نبدأ الإنذار الصوتي الآن — ننتظر 60 ثانية أو حتى انتهاء الكتم
            if (STATE.Has("isNetAlarmPlaying") && STATE["isNetAlarmPlaying"]) {
                STATE["isNetAlarmPlaying"] := false
                if !(STATE.Has("isAlarmPlaying") && STATE["isAlarmPlaying"]) {
                    SetTimer(AlarmBeep, 0)
                }
            }
        } else {
            ; ما زلنا غير متصلين — افحص شروط بدء الإنذار
            startTick := STATE.Has("netAlarmCandidateSince") ? STATE["netAlarmCandidateSince"] : STATE["netLastChangeTick"]
            elapsed := A_TickCount - startTick
            if (elapsed >= 60000) { ; دقيقة واحدة
                if (muted) {
                    ; أثناء الكتم، تأكد من إيقاف إنذار النت
                    if (STATE.Has("isNetAlarmPlaying") && STATE["isNetAlarmPlaying"]) {
                        STATE["isNetAlarmPlaying"] := false
                        if !(STATE.Has("isAlarmPlaying") && STATE["isAlarmPlaying"]) {
                            SetTimer(AlarmBeep, 0)
                        }
                    }
                } else {
                    if !(STATE.Has("isNetAlarmPlaying") && STATE["isNetAlarmPlaying"]) {
                        STATE["isNetAlarmPlaying"] := true
                        if !(STATE.Has("isAlarmPlaying") && STATE["isAlarmPlaying"]) {
                            SetTimer(AlarmBeep, 300)
                        }
                    }
                }
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
    
    ; خزنها للاستخدام في الداشبورد لتقليل الاستعلامات المتكررة
    STATE["batteryPercent"] := pct
    STATE["batteryLastCheckTick"] := A_TickCount
    
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

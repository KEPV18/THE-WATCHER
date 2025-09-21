; ============================================================
; 05_TimersLogic.ahk (v3 - Using Rich Notifications & Photos)
; ============================================================

; ============================================================
; StatusCheckTimer - updated to use intelligent coordinate detection
; ============================================================
StatusCheckTimer(*) {
    global SETTINGS, STATE
    if !IsObject(STATE) {
        LogError("STATE object lost in StatusCheckTimer.")
        return
    }
    
    ; فحص إذا كانت المراقبة نشطة (بعد انتهاء فترة الانتظار دقيقتين)
    if (!STATE.Has("monitoringActive") || !STATE["monitoringActive"]) {
        ; Info("StatusCheck skipped - monitoring not yet active")
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
    
    ; استخدام النظام الذكي للبحث عن الحالة
    local statusArea := GetSmartCoordinates("StatusArea")
    local knownStatusFound := false, foundX, foundY

    ; أولًا: تحقق من أي صورة ضمن صور Online المتعددة
    if (SETTINGS.Has("OnlineImageList") && SETTINGS["OnlineImageList"].Length > 0) {
        searchResult := SmartElementSearch(SETTINGS["OnlineImageList"], "StatusArea")
        if (searchResult["found"]) {
            if (STATE["onlineStatus"] != "Online") {
                Info("Status changed to: Online (Smart Detection)")
                UpdateStatusDurations("Online")
                STATE["onlineStatus"] := "Online"
                STATE["offlineFixAttempts"] := 0
            }
            knownStatusFound := true
        }
    } else {
        if (ReliableImageSearch(&foundX, &foundY, SETTINGS["OnlineImage"], statusArea)) {
            if (STATE["onlineStatus"] != "Online") {
                Info("Status changed to: Online")
                UpdateStatusDurations("Online")
                STATE["onlineStatus"] := "Online"
                STATE["offlineFixAttempts"] := 0
            }
            knownStatusFound := true
        }
    }
    
    if (knownStatusFound)
        return

    ; ثانياً: اكتشاف حالة Coaching (لا نقوم بأي إجراء، فقط تحديث الحالة)
    if (SETTINGS.Has("CoachingImageList") && SETTINGS["CoachingImageList"].Length > 0) {
        searchResult := SmartElementSearch(SETTINGS["CoachingImageList"], "StatusArea")
        if (searchResult["found"]) {
            if (STATE["onlineStatus"] != "Coaching") {
                Info("Status changed to: Coaching (Smart Detection)")
                UpdateStatusDurations("Coaching")
                STATE["onlineStatus"] := "Coaching"
                STATE["offlineFixAttempts"] := 0
            }
            knownStatusFound := true
        }
    } else if (SETTINGS.Has("CoachingImage") && FileExist(SETTINGS["CoachingImage"])) {
        if (ReliableImageSearch(&foundX, &foundY, SETTINGS["CoachingImage"], statusArea)) {
            if (STATE["onlineStatus"] != "Coaching") {
                Info("Status changed to: Coaching")
                UpdateStatusDurations("Coaching")
                STATE["onlineStatus"] := "Coaching"
                STATE["offlineFixAttempts"] := 0
            }
            knownStatusFound := true
        }
    }
    
    if (knownStatusFound)
        return

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
    global SETTINGS, STATE
    Info("Executing 3-step fix for offline status...")
    
    ; إنشاء مجلد لحفظ لقطات الشاشة للضغطات الثلاث
    screenshotDir := A_ScriptDir "\screenshots\online_fix_steps"
    if (!DirExist(screenshotDir)) {
        DirCreate(screenshotDir)
    }
    
    ; الضغطة الأولى
    Info("Online Fix Step 1: Clicking at (" . SETTINGS["FixStep1X"] . "," . SETTINGS["FixStep1Y"] . ")")
    Click(SETTINGS["FixStep1X"], SETTINGS["FixStep1Y"])
    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
    
    ; حفظ الإحداثيات والتقاط لقطة شاشة
    try {
        ; حفظ الإحداثيات
        coordsFile := screenshotDir "\step1_coordinates.txt"
        coordsText := "Step 1 Coordinates: X=" . SETTINGS["FixStep1X"] . ", Y=" . SETTINGS["FixStep1Y"] . "`n"
        coordsText .= "Timestamp: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "`n"
        coordsText .= "Screen Resolution: " . A_ScreenWidth . "x" . A_ScreenHeight . "`n"
        FileAppend(coordsText, coordsFile, "UTF-8")
        
        ; التقاط لقطة شاشة
        screenshotFile := screenshotDir "\step1_" . FormatTime(A_Now, "yyyyMMdd_HHmmss") . ".png"
        CaptureScreenArea(screenshotFile, SETTINGS["FixStep1X"] - 100, SETTINGS["FixStep1Y"] - 100, 200, 200)
        Info("Step 1: Screenshot saved to " . screenshotFile)
    } catch as e {
        Warn("Failed to save Step 1 screenshot: " . e.Message)
    }
    
    Sleep(1500)
    
    ; الضغطة الثانية
    Info("Online Fix Step 2: Clicking at (" . SETTINGS["FixStep2X"] . "," . SETTINGS["FixStep2Y"] . ")")
    Click(SETTINGS["FixStep2X"], SETTINGS["FixStep2Y"])
    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
    
    ; حفظ الإحداثيات والتقاط لقطة شاشة
    try {
        ; حفظ الإحداثيات
        coordsFile := screenshotDir "\step2_coordinates.txt"
        coordsText := "Step 2 Coordinates: X=" . SETTINGS["FixStep2X"] . ", Y=" . SETTINGS["FixStep2Y"] . "`n"
        coordsText .= "Timestamp: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "`n"
        coordsText .= "Screen Resolution: " . A_ScreenWidth . "x" . A_ScreenHeight . "`n"
        FileAppend(coordsText, coordsFile, "UTF-8")
        
        ; التقاط لقطة شاشة
        screenshotFile := screenshotDir "\step2_" . FormatTime(A_Now, "yyyyMMdd_HHmmss") . ".png"
        CaptureScreenArea(screenshotFile, SETTINGS["FixStep2X"] - 100, SETTINGS["FixStep2Y"] - 100, 200, 200)
        Info("Step 2: Screenshot saved to " . screenshotFile)
    } catch as e {
        Warn("Failed to save Step 2 screenshot: " . e.Message)
    }
    
    Sleep(1500)
    
    ; الضغطة الثالثة
    Info("Online Fix Step 3: Clicking at (" . SETTINGS["FixStep3X"] . "," . SETTINGS["FixStep3Y"] . ")")
    Click(SETTINGS["FixStep3X"], SETTINGS["FixStep3Y"])
    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
    
    ; حفظ الإحداثيات والتقاط لقطة شاشة
    try {
        ; حفظ الإحداثيات
        coordsFile := screenshotDir "\step3_coordinates.txt"
        coordsText := "Step 3 Coordinates: X=" . SETTINGS["FixStep3X"] . ", Y=" . SETTINGS["FixStep3Y"] . "`n"
        coordsText .= "Timestamp: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "`n"
        coordsText .= "Screen Resolution: " . A_ScreenWidth . "x" . A_ScreenHeight . "`n"
        FileAppend(coordsText, coordsFile, "UTF-8")
        
        ; التقاط لقطة شاشة
        screenshotFile := screenshotDir "\step3_" . FormatTime(A_Now, "yyyyMMdd_HHmmss") . ".png"
        CaptureScreenArea(screenshotFile, SETTINGS["FixStep3X"] - 100, SETTINGS["FixStep3Y"] - 100, 200, 200)
        Info("Step 3: Screenshot saved to " . screenshotFile)
        
        ; حفظ ملخص العملية
        summaryFile := screenshotDir "\fix_summary_" . FormatTime(A_Now, "yyyyMMdd_HHmmss") . ".txt"
        summaryText := "Online Fix Operation Summary`n"
        summaryText .= "================================`n"
        summaryText .= "Timestamp: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "`n"
        summaryText .= "Offline Fix Attempts: " . (STATE.Has("offlineFixAttempts") ? STATE["offlineFixAttempts"] : 1) . "`n"
        summaryText .= "Screen Resolution: " . A_ScreenWidth . "x" . A_ScreenHeight . "`n"
        summaryText .= "`nStep 1: (" . SETTINGS["FixStep1X"] . "," . SETTINGS["FixStep1Y"] . ")`n"
        summaryText .= "Step 2: (" . SETTINGS["FixStep2X"] . "," . SETTINGS["FixStep2Y"] . ")`n"
        summaryText .= "Step 3: (" . SETTINGS["FixStep3X"] . "," . SETTINGS["FixStep3Y"] . ")`n"
        FileAppend(summaryText, summaryFile, "UTF-8")
        
    } catch as e {
        Warn("Failed to save Step 3 screenshot: " . e.Message)
    }
    
    Sleep(1500)
    Info("Fix clicks performed with screenshots and coordinate logging.")
}

; دالة مساعدة لالتقاط منطقة من الشاشة
CaptureScreenArea(filePath, x, y, width, height) {
    try {
        ; التأكد من أن الإحداثيات ضمن حدود الشاشة
        x := Max(0, Min(x, A_ScreenWidth - width))
        y := Max(0, Min(y, A_ScreenHeight - height))
        width := Min(width, A_ScreenWidth - x)
        height := Min(height, A_ScreenHeight - y)
        
        ; التقاط الشاشة باستخدام GDI+
        pBitmap := Gdip_BitmapFromScreen(x . "|" . y . "|" . width . "|" . height)
        if (pBitmap) {
            Gdip_SaveBitmapToFile(pBitmap, filePath)
            Gdip_DisposeImage(pBitmap)
            return true
        }
    } catch as e {
        Warn("CaptureScreenArea failed: " . e.Message)
    }
    return false
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
    
    ; فحص إذا كانت المراقبة نشطة
    if (!STATE.Has("monitoringActive") || !STATE["monitoringActive"]) {
        return
    }
    
    if (!WinExist(SETTINGS["FrontlineWinTitle"]))
        return
    idlePhysical := A_TimeIdlePhysical
    idleSinceInternal := A_TickCount - (STATE.Has("lastUserActivity") ? STATE["lastUserActivity"] : A_TickCount)
    keyboardOnly := (SETTINGS.Has("ActivityKeyboardOnly") && SETTINGS["ActivityKeyboardOnly"]) ? true : false
    idleCombined := keyboardOnly ? idleSinceInternal : Min(idlePhysical, idleSinceInternal)
    if (idleCombined < SETTINGS["UserIdleThreshold"]) ; لا ينفّذ أثناط النشاط الحقيقي
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
        ; تحسين fallback click لتجنب التداخل مع الداشبورد
        stayOnlineArea := Map("x1", SETTINGS["StayOnlineAreaTopLeftX"], "y1", SETTINGS["StayOnlineAreaTopLeftY"], "x2", SETTINGS["StayOnlineAreaBottomRightX"], "y2", SETTINGS["StayOnlineAreaBottomRightY"])
        cx := (stayOnlineArea["x1"] + stayOnlineArea["x2"]) // 2
        cy := (stayOnlineArea["y1"] + stayOnlineArea["y2"]) // 2
        
        ; حفظ موقع الماوس الحالي
        MouseGetPos(&currentX, &currentY)
        
        CoordMode "Mouse", "Screen"
        MouseMove cx, cy, 2  ; حركة سريعة
        Click
        
        ; العودة لموقع الماوس الأصلي
        MouseMove currentX, currentY, 2
        
        STATE["lastStayOnlineClickTime"] := A_TickCount
        STATE["lastStayOnlineTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
        STATE["actionBusyUntil"] := A_TickCount + 3000
        STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
        Info("Stay Online: button not detected, performed fallback center click.")
        Sleep 500  ; تقليل وقت الانتظار
        
        ; محاولة ثانية بعد fallback click
        if (ClickStayOnlineButton()) {
            STATE["lastStayOnlineClickTime"] := A_TickCount
            STATE["lastStayOnlineTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
            STATE["actionBusyUntil"] := A_TickCount + 3000
            STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
        }
    }
}

; --- تحديث RefreshTimer لاستخدام idleCombined ومنع التحريق أثناط ---
RefreshTimer(*) {
    global SETTINGS, STATE
    
    ; فحص إذا كانت المراقبة نشطة
    if (!STATE.Has("monitoringActive") || !STATE["monitoringActive"]) {
        return
    }
    
    if (!WinExist(SETTINGS["FrontlineWinTitle"]))
        return
    current := STATE.Has("onlineStatus") ? STATE["onlineStatus"] : "Unknown"
    if (current != "Online") {
        Info("Refresh skipped: status is " . current)
        return
    }
    
    ; التحقق من شروط الريفريش: الخمول دقيقتين+ ووجود Target Word والحالة أونلاين
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
    
    ; التحقق من وجود Target Word - إذا لم يوجد، نحتاج للريفريش!
    targetResult := Map("found", false)
    if (SETTINGS.Has("TargetImageList") && SETTINGS["TargetImageList"].Length > 0) {
        targetResult := SmartElementSearch(SETTINGS["TargetImageList"], "TargetArea")
    } else if (SETTINGS.Has("TargetImage") && FileExist(SETTINGS["TargetImage"])) {
        targetResult := SmartElementSearch(SETTINGS["TargetImage"], "TargetArea")
    }
    
    ; إذا كان Target Word موجود، لا نحتاج للريفريش
    if (targetResult["found"]) {
        ; تحديث آخر مرة تم العثور على Target Word
        STATE["lastTargetFound"] := FormatTime(A_Now, "HH:mm:ss")
        Info("Refresh skipped: Target Word found - no refresh needed")
        return
    }
    
    ; إذا لم يوجد Target Word، نحتاج للريفريش لمحاولة إعادة تحميل الصفحة
    Info("Target Word not found - proceeding with refresh to reload page")
    
    ; البحث الذكي عن Stay Online
    stayOnlineResult := Map("found", false)
    if (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0) {
        stayOnlineResult := SmartElementSearch(SETTINGS["StayOnlineImageList"], "StayOnlineArea")
    } else if (SETTINGS.Has("StayOnlineImage") && FileExist(SETTINGS["StayOnlineImage"])) {
        stayOnlineResult := SmartElementSearch(SETTINGS["StayOnlineImage"], "StayOnlineArea")
    }
    
    if (stayOnlineResult["found"]) {
        Info("Stay Online button found before refresh - clicking it first")
        Click(stayOnlineResult["x"], stayOnlineResult["y"])
        STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
        Sleep(1000)
        
        ; إعادة فحص Stay Online بعد النقر
        stillVisibleResult := Map("found", false)
        if (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0) {
            stillVisibleResult := SmartElementSearch(SETTINGS["StayOnlineImageList"], "StayOnlineArea")
        } else if (SETTINGS.Has("StayOnlineImage") && FileExist(SETTINGS["StayOnlineImage"])) {
            stillVisibleResult := SmartElementSearch(SETTINGS["StayOnlineImage"], "StayOnlineArea")
        }
        
        if (stillVisibleResult["found"]) {
            Info("Stay Online window still visible after click - skipping refresh")
            return
        }
    }

    ; استخدام الإحداثيات الذكية للريفريش
    refreshCoords := GetSmartCoordinates("RefreshButton")
    refreshX := refreshCoords.Has("x") ? refreshCoords["x"] : SETTINGS["RefreshX"]
    refreshY := refreshCoords.Has("y") ? refreshCoords["y"] : SETTINGS["RefreshY"]

    Info("Refresh proceeding: idleCombined=" . idleCombined . " >= thr=" . SETTINGS["UserIdleThreshold"] . ", Target missing, Status=Online - refreshing to reload page.")
    
    ; حفظ موقع الماوس الحالي لتجنب التداخل مع الداشبورد
    MouseGetPos(&currentX, &currentY)
    
    Click(refreshX, refreshY)
    
    ; العودة لموقع الماوس الأصلي
    MouseMove currentX, currentY, 2
    
    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
    STATE["lastRefreshTime"] := A_TickCount
    STATE["lastRefreshTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
    Info("Refresh button clicked - page should reload")
    CoordMode "Mouse", "Screen"
    tx := Min(A_ScreenWidth - 5, refreshX + 150)
    ty := Min(A_ScreenHeight - 5, refreshY + 150)
    MouseMove tx, ty, 0
    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
    Info("Refresh performed - Time-based (Smart Coordinates)")
    STATE["lastRefreshTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
    delayMs := SETTINGS.Has("PostRefreshDelayMs") ? SETTINGS["PostRefreshDelayMs"] : 2500
    STATE["actionBusyUntil"] := A_TickCount + delayMs
}

MonitorTargetTimer(*) {
    global SETTINGS, STATE
    static lastIdleCheck := 0
    
    ; فحص إذا كانت المراقبة نشطة
    if (!STATE.Has("monitoringActive") || !STATE["monitoringActive"]) {
        return
    }
    
    ; تجنّب الفحص أثناء نافذة الانشغال بعد أي إجراء (مثل Refresh أو Stay Online)
    if (STATE.Has("actionBusyUntil") && A_TickCount < STATE["actionBusyUntil"]) {
        ; Info("MonitorTarget skipped (post action delay)")
        return
    }
    if (A_TickCount - lastIdleCheck < SETTINGS["MainLoopInterval"]) {
        return
    }
    lastIdleCheck := A_TickCount

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

    ; استخدام النظام الذكي للبحث عن Target Word
    local foundX, foundY
    searchResult := Map("found", false)
    
    if (SETTINGS.Has("TargetImageList") && SETTINGS["TargetImageList"].Length > 0) {
        searchResult := SmartElementSearch(SETTINGS["TargetImageList"], "TargetArea")
    } else if (SETTINGS.Has("TargetImage") && FileExist(SETTINGS["TargetImage"])) {
        searchResult := SmartElementSearch(SETTINGS["TargetImage"], "TargetArea")
    }
    
    hasTarget := searchResult["found"]
    
    ; تحديث آخر مرة تم التحقق من Target Word
    STATE["lastTargetCheck"] := FormatTime(A_Now, "HH:mm:ss")
    if (hasTarget) {
        STATE["lastTargetFound"] := FormatTime(A_Now, "HH:mm:ss")
        STATE["targetMissingStartTime"] := 0  ; إعادة تعيين عداد الاختفاء
    }
    
    if (!hasTarget) {
        ; تتبع بداية اختفاء Target Word
        if (!STATE.Has("targetMissingStartTime") || STATE["targetMissingStartTime"] == 0) {
            STATE["targetMissingStartTime"] := A_TickCount
            Info("Target Word disappeared - starting missing timer")
        }
        
        ; حساب مدة الاختفاء
        missingDuration := A_TickCount - STATE["targetMissingStartTime"]
        missingMinutes := missingDuration / 60000  ; تحويل لدقائق
        
        ; إنذار إذا اختفى Target Word لأكثر من 5 دقائق
        if (missingMinutes >= 5 && !STATE.Has("targetMissingAlarmSent")) {
            STATE["targetMissingAlarmSent"] := true
            ShowLocalNotification("⚠️ Target Word missing for " . Round(missingMinutes, 1) . " minutes!")
            QueueTelegram(Map("type", "text", "title", "⚠️ Target Word Missing Alert", 
                           "details", Map("Duration", Round(missingMinutes, 1) . " minutes", 
                                        "Last Found", STATE.Has("lastTargetFound") ? STATE["lastTargetFound"] : "Unknown",
                                        "Action", "System will continue monitoring and refreshing")))
            Warn("Target Word has been missing for " . Round(missingMinutes, 1) . " minutes")
        }
        
        ; إنذار إضافي كل 10 دقائق
        if (missingMinutes >= 10 && Mod(Floor(missingMinutes), 10) == 0 && !STATE.Has("targetMissing" . Floor(missingMinutes) . "minAlarm")) {
            STATE["targetMissing" . Floor(missingMinutes) . "minAlarm"] := true
            ShowLocalNotification("🚨 Target Word still missing after " . Floor(missingMinutes) . " minutes!")
            QueueTelegram(Map("type", "text", "title", "🚨 Extended Target Word Absence", 
                           "details", Map("Duration", Floor(missingMinutes) . " minutes", 
                                        "Status", "Critical - Target Word not found for extended period")))
        }
         
         confirmedMissing := true
        Loop 3 {
            Sleep(1000)
            ; إعادة البحث الذكي
            if (SETTINGS.Has("TargetImageList") && SETTINGS["TargetImageList"].Length > 0) {
                retryResult := SmartElementSearch(SETTINGS["TargetImageList"], "TargetArea")
            } else {
                retryResult := SmartElementSearch(SETTINGS["TargetImage"], "TargetArea")
            }
            
            if (retryResult["found"]) {
                confirmedMissing := false
                STATE["lastTargetFound"] := FormatTime(A_Now, "HH:mm:ss")  ; تحديث آخر مرة وُجد
                STATE["targetMissingStartTime"] := 0  ; إعادة تعيين عداد الاختفاء
                ; إعادة تعيين إنذارات الاختفاء
                STATE.Delete("targetMissingAlarmSent")
                for key in STATE {
                    if (InStr(key, "targetMissing") && InStr(key, "minAlarm")) {
                        STATE.Delete(key)
                    }
                }
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

        ; البحث الذكي عن Stay Online
        stayOnlineResult := Map("found", false)
        if (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0) {
            stayOnlineResult := SmartElementSearch(SETTINGS["StayOnlineImageList"], "StayOnlineArea")
        } else if (SETTINGS.Has("StayOnlineImage") && FileExist(SETTINGS["StayOnlineImage"])) {
            stayOnlineResult := SmartElementSearch(SETTINGS["StayOnlineImage"], "StayOnlineArea")
        }
        
        if (stayOnlineResult["found"]) {
            Info("Target missing BUT Stay Online window is visible. Will attempt to dismiss it and re-check target.")
            ClickStayOnlineButton()
            attempts := 0
            Loop 5 {
                Sleep(1000)
                attempts++
                
                ; إعادة البحث الذكي
                stillStayResult := Map("found", false)
                if (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0) {
                    stillStayResult := SmartElementSearch(SETTINGS["StayOnlineImageList"], "StayOnlineArea")
                } else if (SETTINGS.Has("StayOnlineImage") && FileExist(SETTINGS["StayOnlineImage"])) {
                    stillStayResult := SmartElementSearch(SETTINGS["StayOnlineImage"], "StayOnlineArea")
                }
                
                targetBackResult := Map("found", false)
                if (SETTINGS.Has("TargetImageList") && SETTINGS["TargetImageList"].Length > 0) {
                    targetBackResult := SmartElementSearch(SETTINGS["TargetImageList"], "TargetArea")
                } else {
                    targetBackResult := SmartElementSearch(SETTINGS["TargetImage"], "TargetArea")
                }
                
                if (!stillStayResult["found"] && targetBackResult["found"]) {
                    Info("Target is back after dismissing Stay Online. No alarm.")
                    return
                }
                if (!stillStayResult["found"] && !targetBackResult["found"]) {
                    Info("Stay Online dismissed but Target still missing after " . attempts . "s.")
                    break
                }
                if (stillStayResult["found"] && attempts >= 5) {
                    Info("Stay Online still visible after retries. Will raise alarm.")
                    break
                }
            }
            try {
                SaveTargetWordScreenshot("target_missing")
            } catch {
            }

            cause := "Unknown"
            finalStayCheck := Map("found", false)
            if (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0) {
                finalStayCheck := SmartElementSearch(SETTINGS["StayOnlineImageList"], "StayOnlineArea")
            } else if (SETTINGS.Has("StayOnlineImage") && FileExist(SETTINGS["StayOnlineImage"])) {
                finalStayCheck := SmartElementSearch(SETTINGS["StayOnlineImage"], "StayOnlineArea")
            }
            
            if (finalStayCheck["found"])
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

        try {
            SaveTargetWordScreenshot("target_missing")
        } catch {
        }
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
                ; إزالة BlockInput لتجنب تجميد الداشبورد
                try {
                    ; حفظ موقع الماوس الحالي
                    MouseGetPos(&currentX, &currentY)
                    
                    MouseMove clickX, clickY, 2  ; حركة سريعة للزر
                    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
                    Sleep(50)
                    Click
                    
                    ; العودة لموقع الماوس الأصلي بسرعة
                    MouseMove currentX, currentY, 2
                    
                    ; تصوير بعد كل نقرة
                    try {
                        SaveStayOnlineScreenshot("after_click_" . A_Index)
                    } catch {
                    }
                    STATE["synthInputUntil"] := A_TickCount + (SETTINGS.Has("ActivitySynthIgnoreMs") ? SETTINGS["ActivitySynthIgnoreMs"] : 2000)
                    Sleep(300)  ; تقليل وقت الانتظار
                } catch as e {
                    Warn("Error during Stay Online click: " . e.Message)
                }
                local sx, sy
                still := (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0)
                    ? ImageListSearch(&sx, &sy, SETTINGS["StayOnlineImageList"], stayOnlineArea)
                    : ReliableImageSearch(&sx, &sy, SETTINGS["StayOnlineImage"], stayOnlineArea)
                if (!still) {
                    STATE["lastStayOnlineClickTime"] := A_TickCount
                    STATE["lastStayOnlineTimestamp"] := FormatTime(A_Now, "HH:mm:ss")
                    Info("Stay Online button clicked successfully.")
                    ; صورة عند النجاح
                    try {
                        SaveStayOnlineScreenshot("success")
                    } catch {
                    }
                    return true
                }
            }
            Warn("Failed to dismiss Stay Online after multiple attempts.")
            ; صورة عند الفشل بعد كل المحاولات
            try {
                SaveStayOnlineScreenshot("failed")
            } catch {
            }
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

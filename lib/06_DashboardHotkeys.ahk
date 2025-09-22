; ============================================================
; 06_DashboardHotkeys.ahk - Dashboard UI and Hotkeys
; ============================================================

UpdateDashboardTimer(*) {
    UpdateDashboard()
}

UpdateDashboard() {
    global STATE, SETTINGS
    
    ; تأكد من تهيئة STATE إذا لم يكن موجوداً
    if !IsSet(STATE) || !IsObject(STATE) {
        STATE := Map()
        Info("STATE object was not initialized in UpdateDashboard - reinitializing.")
    }
    
    if !IsObject(STATE) {
        Info("STATE object not ready for dashboard update.")
        return
    }

    ; --- حساب القيم مرة واحدة ---
    battery := (STATE.Has("batteryPercent") ? STATE["batteryPercent"] : GetBatteryPercent())
    batteryPercentText := (battery = -1) ? "N/A" : battery . "%"

    idlePhysical := A_TimeIdlePhysical
    keyboardOnly := (IsObject(SETTINGS) && SETTINGS.Has("ActivityKeyboardOnly") && SETTINGS["ActivityKeyboardOnly"]) ? true : false
    idleCombined := keyboardOnly 
        ? (A_TickCount - (STATE.Has("lastUserActivity") ? STATE["lastUserActivity"] : A_TickCount)) 
        : Min(idlePhysical, A_TickCount - (STATE.Has("lastUserActivity") ? STATE["lastUserActivity"] : A_TickCount))
    idleText := (idleCombined // 60000) . "m " . Mod(idleCombined // 1000, 60) . "s"

    alarmStatus := "N/A"
    if STATE.Has("isAlarmPlaying") {
        if STATE["isAlarmPlaying"]
            alarmStatus := "ACTIVE (press CapsLock)"
        else if STATE.Has("isMonitoringPaused") && STATE["isMonitoringPaused"]
            alarmStatus := "PAUSED"
        else
            alarmStatus := "OFF"
    }

    netLine := "Network: N/A"
    if (STATE.Has("netOnline")) {
        if (STATE["netOnline"]) {
            netLine := "Network: ✅ Online"
        } else {
            offlineElapsed := A_TickCount - (STATE.Has("netLastChangeTick") ? STATE["netLastChangeTick"] : A_TickCount)
            netLine := "Network: ❌ Offline (" . (offlineElapsed // 60000) . "m " . Mod(offlineElapsed // 1000, 60) . "s)"
        }
    }

    lastCheck := STATE.Has("lastStatusCheckTimestamp") ? STATE["lastStatusCheckTimestamp"] : "Never"
    lastRefresh := STATE.Has("lastRefreshTimestamp") ? STATE["lastRefreshTimestamp"] : "Never"
    lastStay := STATE.Has("lastStayOnlineTimestamp") ? STATE["lastStayOnlineTimestamp"] : "Never"

    isExpanded := GetKeyState("Alt", "P") || (STATE.Has("dashboardExpanded") ? STATE["dashboardExpanded"] : false)

    batteryText := batteryPercentText

    statusText := (STATE.Has("onlineStatus") ? STATE["onlineStatus"] : "N/A")
    alarmText := alarmStatus
    netShort := "Network N/A"
    if (STATE.Has("netOnline"))
        netShort := STATE["netOnline"] ? "Network ✅" : "Network ❌"

    ; إضافة معلومات الوضع الذكي
    monitoringStatus := STATE.Has("monitoringActive") && STATE["monitoringActive"] ? "Active" : "Waiting"
    intelligentMode := STATE.Has("intelligentMode") && STATE["intelligentMode"] ? "ON" : "OFF"
    
    ; معلومات Target Word
    lastTargetCheck := STATE.Has("lastTargetCheck") ? STATE["lastTargetCheck"] : "Never"
    lastTargetFound := STATE.Has("lastTargetFound") ? STATE["lastTargetFound"] : "Never"

    if !isExpanded {
        text := "S: " . statusText . " | " . netShort . " | Battery " . batteryPercentText . " | Idle " . idleText . "`n"
        text .= "Monitor: " . monitoringStatus . " | Smart: " . intelligentMode . " | Target: " . lastTargetCheck . " | (Ctrl+Alt+D للتفاصيل)"
    } else {
        text := "The Watcher by A.k (Smart Mode)`n"
        text .= "Status: " . statusText . " | Alarm: " . alarmText . "`n"
        text .= netLine . "`n"
        text .= "Battery: " . batteryText . " | User Idle: " . idleText . "`n"
        text .= "Monitoring: " . monitoringStatus . " | Intelligent Mode: " . intelligentMode . "`n"
        text .= "Last Check: " . lastCheck . " | Last Refresh: " . lastRefresh . "`n"
        text .= "Last Stay Online: " . lastStay . "`n"
        text .= "Target Check: " . lastTargetCheck . " | Target Found: " . lastTargetFound
    }

    ; --- النظام الذكي للداشبورد: تقسيم الشاشة وتجنب الماوس ---
    MouseGetPos &mx, &my
    
    ; تحديث موقع الماوس في الحالة
    STATE["mouseLastX"] := mx
    STATE["mouseLastY"] := my
    
    ; احسب أبعاد التولتيب
    lines := StrSplit(text, "`n")
    maxLen := 0
    for _, ln in lines {
        l := StrLen(ln)
        if (l > maxLen)
            maxLen := l
    }
    widthPx := Min(650, Max(200, maxLen * 7))
    heightPx := Max(18, lines.Length * 18)
    margin := 10

    ; --- النظام الذكي: تحديد موقع الداشبورد بناءً على موقع الماوس ---
    SmartDashboardPositioning(text, mx, my, widthPx, heightPx, margin)
}

; دالة جديدة للتحكم الذكي في موقع الداشبورد
SmartDashboardPositioning(text, mouseX, mouseY, width, height, margin) {
    global STATE, SETTINGS
    
    ; فحص إذا كان النظام الذكي مفعل
    if (!SETTINGS.Has("SmartDashboard") || !SETTINGS["SmartDashboard"]) {
        ; استخدام النظام القديم
        ShowTooltipForScreen(text, 19, SETTINGS.Has("DashboardX") ? SETTINGS["DashboardX"] : 10, SETTINGS.Has("DashboardY") ? SETTINGS["DashboardY"] : 120)
        return
    }
    
    ; إخفاء جميع الداشبوردات أولاً
    Loop 10 {
        ToolTip(, , , 10 + A_Index)
    }
    
    ; معالجة كل شاشة على حدة للعثور على الشاشة التي بها الماوس
    monitorCount := MonitorGetCount()
    mouseScreen := 0
    
    Loop monitorCount {
        monitorIndex := A_Index
        
        try {
            MonitorGet(monitorIndex, &left, &top, &right, &bottom)
            
            ; فحص إذا كان الماوس في هذه الشاشة
            if (mouseX >= left && mouseX <= right && mouseY >= top && mouseY <= bottom) {
                mouseScreen := monitorIndex
                
                ; تقسيم الشاشة إلى نصفين
                screenWidth := right - left
                screenHeight := bottom - top
                midX := left + (screenWidth // 2)
                
                ; تحديد موقع الداشبورد بناءً على موقع الماوس
                local dashX, dashY
                
                if (mouseX < midX) {
                    ; الماوس في النصف الأيسر، ضع الداشبورد في النصف الأيمن
                    dashX := midX + margin
                    STATE["dashboardPosition"] := "right"
                } else {
                    ; الماوس في النصف الأيمن، ضع الداشبورد في النصف الأيسر
                    dashX := left + margin
                    STATE["dashboardPosition"] := "left"
                }
                
                ; تحديد الموقع العمودي (تجنب الحواف)
                dashY := top + 120
                if (dashY + height > bottom - margin) {
                    dashY := Max(top + margin, bottom - margin - height)
                }
                
                ; التأكد من أن الداشبورد لا يخرج من حدود الشاشة
                if (dashX + width > right - margin) {
                    dashX := right - margin - width
                }
                
                ; عرض الداشبورد في الموقع المحسوب (داشبورد واحدة فقط)
                ShowTooltipForScreen(text, 19, dashX, dashY)
                
                ; حفظ الموقع الجديد للاستخدام المستقبلي
                if (monitorIndex == 1) {
                    STATE["dashboardX1"] := dashX
                    STATE["dashboardY1"] := dashY
                } else if (monitorIndex == 2) {
                    STATE["dashboardX2"] := dashX
                    STATE["dashboardY2"] := dashY
                }
                
                ; إنهاء الحلقة بعد العثور على الشاشة الصحيحة
                break
            }
            
        } catch as e {
            ; في حالة حدوث خطأ، استخدم الموقع الافتراضي
            local fallbackX := 10
            local fallbackY := 120
            ShowTooltipForScreen(text, 19, fallbackX, fallbackY)
        }
    }
    
    ; إذا لم يتم العثور على الماوس في أي شاشة، استخدم الشاشة الأولى
    if (mouseScreen == 0) {
        try {
            MonitorGet(1, &left, &top, &right, &bottom)
            local defaultX := left + 10
            local defaultY := top + 120
            ShowTooltipForScreen(text, 19, defaultX, defaultY)
        } catch {
            ShowTooltipForScreen(text, 19, 10, 120)
        }
    }
}

ShowTooltipForScreen(text, tooltipId, tooltipX, tooltipY) {
    ; لا تُخفِ الداشبورد عند المرور عليها، وأعد رسمها حتى لو لم يتغير النص لتحديث الموضع
    lines := StrSplit(text, "`n")
    maxLen := 0
    for _, ln in lines {
        l := StrLen(ln)
        if (l > maxLen)
            maxLen := l
    }
    widthPx := Min(650, Max(200, maxLen * 7))
    heightPx := Max(18, lines.Length * 18)

    ; عرض دائم بدون منطق الإخفاء/الذاكرة السابقة
    ToolTip(text, tooltipX, tooltipY, tooltipId)
}

; --- Hotkeys ---
; تبديل وضع الداشبورد: مضغوط/موسّع
^!d:: {
    global STATE
    
    ; تأكد من تهيئة STATE إذا لم يكن موجوداً
    if !IsSet(STATE) || !IsObject(STATE) {
        STATE := Map()
        InitializeState()
    }
    
    if !IsObject(STATE) {
        InitializeState()
    }
    STATE["dashboardExpanded"] := !(STATE.Has("dashboardExpanded") ? STATE["dashboardExpanded"] : false)
}

~*CapsLock:: {
    global STATE, SETTINGS
    
    ; تأكد من تهيئة STATE إذا لم يكن موجوداً
    if !IsSet(STATE) || !IsObject(STATE) {
        STATE := Map()
        InitializeState() ; Safety net
        return
    }
    
    if !IsObject(STATE) {
        InitializeState() ; Safety net
        return
    }

    ; اسكت أي إنذار يعمل (عام أو شبكة) فورًا، وامنح مهلة كتم لإنذار الشبكة
    if (STATE.Has("isAlarmPlaying") && STATE["isAlarmPlaying"]) {
        STATE["isAlarmPlaying"] := false
    }
    if (STATE.Has("isNetAlarmPlaying") && STATE["isNetAlarmPlaying"]) {
        STATE["isNetAlarmPlaying"] := false
    }
    SetTimer(AlarmBeep, 0)
    STATE["offlineFixAttempts"] := 0
    STATE["isMonitoringPaused"] := true
    STATE["netAlarmMuteUntil"] := A_TickCount + (SETTINGS.Has("ManualPauseDuration") ? SETTINGS["ManualPauseDuration"] : 180000)
    Info("Alarm(s) stopped by CapsLock. Monitoring paused for " . (SETTINGS["ManualPauseDuration"]/1000) . " seconds.")
    SetTimer(ResumeMonitoring, -SETTINGS["ManualPauseDuration"])

    STATE["lastUserActivity"] := A_TickCount
}

ResumeMonitoring(*) {
    global STATE
    if (IsObject(STATE)) {
        STATE["isMonitoringPaused"] := false
    }
    Info("Monitoring automatically resumed after pause.")
}

; --- Safe Exit and Reload Hotkeys ---

SafeExit() {
    Info("--- Script Exiting Safely ---")
    Gdip_Shutdown() ; Call shutdown manually
    ExitApp()
}

^F5:: {
    Info("--- Script Reloading ---")
    Gdip_Shutdown() ; Call shutdown manually before reloading
    Reload()
}

F12::SafeExit() ; Use the safe exit function

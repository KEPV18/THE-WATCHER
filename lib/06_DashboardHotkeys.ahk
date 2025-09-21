; ============================================================
; 06_DashboardHotkeys.ahk - Dashboard UI and Hotkeys
; ============================================================

UpdateDashboardTimer(*) {
    UpdateDashboard()
}

UpdateDashboard() {
    global STATE, SETTINGS
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
    
    ; معالجة كل شاشة على حدة
    monitorCount := MonitorGetCount()
    
    Loop monitorCount {
        monitorIndex := A_Index
        
        try {
            MonitorGet(monitorIndex, &left, &top, &right, &bottom)
            
            ; فحص إذا كان الماوس في هذه الشاشة
            if (mouseX >= left && mouseX <= right && mouseY >= top && mouseY <= bottom) {
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
                
                ; عرض الداشبورد في الموقع المحسوب
                ShowTooltipForScreen(text, 18 + monitorIndex, dashX, dashY)
                
                ; حفظ الموقع الجديد للاستخدام المستقبلي
                if (monitorIndex == 1) {
                    STATE["dashboardX1"] := dashX
                    STATE["dashboardY1"] := dashY
                } else if (monitorIndex == 2) {
                    STATE["dashboardX2"] := dashX
                    STATE["dashboardY2"] := dashY
                }
                
            } else {
                ; الماوس ليس في هذه الشاشة، استخدم الموقع الافتراضي أو المحفوظ
                local defaultX, defaultY
                
                if (monitorIndex == 1) {
                    defaultX := STATE.Has("dashboardX1") ? STATE["dashboardX1"] : (SETTINGS.Has("DashboardX") ? SETTINGS["DashboardX"] : left + 10)
                    defaultY := STATE.Has("dashboardY1") ? STATE["dashboardY1"] : (SETTINGS.Has("DashboardY") ? SETTINGS["DashboardY"] : top + 120)
                } else if (monitorIndex == 2) {
                    defaultX := STATE.Has("dashboardX2") ? STATE["dashboardX2"] : (SETTINGS.Has("DashboardX2") ? SETTINGS["DashboardX2"] : left + 10)
                    defaultY := STATE.Has("dashboardY2") ? STATE["dashboardY2"] : (SETTINGS.Has("DashboardY2") ? SETTINGS["DashboardY2"] : top + 120)
                } else {
                    defaultX := left + 10
                    defaultY := top + 120
                }
                
                ShowTooltipForScreen(text, 18 + monitorIndex, defaultX, defaultY)
            }
            
        } catch as e {
            ; في حالة حدوث خطأ، استخدم الموقع الافتراضي
            local fallbackX := (monitorIndex == 1) ? 10 : 1930
            local fallbackY := 120
            ShowTooltipForScreen(text, 18 + monitorIndex, fallbackX, fallbackY)
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
    if !IsObject(STATE) {
        InitializeState()
    }
    STATE["dashboardExpanded"] := !(STATE.Has("dashboardExpanded") ? STATE["dashboardExpanded"] : false)
}

~*CapsLock:: {
    global STATE, SETTINGS
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

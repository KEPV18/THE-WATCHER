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

    if !isExpanded {
        text := "S: " . statusText . " | " . netShort . " | Battery " . batteryPercentText . " | Idle " . idleText . "`n"
        text .= "(Ctrl+Alt+D للتفاصيل)"
    } else {
        text := "The Watcher by A.k`n"
        text .= "Status: " . statusText . " | Alarm: " . alarmText . "`n"
        text .= netLine . "`n"
        text .= "Battery: " . batteryText . " | User Idle: " . idleText . "`n"
        text .= "Last Check: " . lastCheck . " | Last Refresh: " . lastRefresh . "`n"
        text .= "Last Stay Online: " . lastStay
    }

    ; --- عرض على شاشتين باستخدام TooltipId مختلف (ضمن 1..20) ---
    ShowTooltipForScreen(text, 19, SETTINGS.Has("DashboardX") ? SETTINGS["DashboardX"] : 10, SETTINGS.Has("DashboardY") ? SETTINGS["DashboardY"] : 120)

    ; حساب موضع افتراضي للشاشة الثانية إذا لم تُحدَّد DashboardX2/Y2
    defX2 := SETTINGS.Has("DashboardX2") ? SETTINGS["DashboardX2"] : ""
    defY2 := SETTINGS.Has("DashboardY2") ? SETTINGS["DashboardY2"] : ""
    if (!defX2 || !defY2) {
        try {
            if (MonitorGetCount() >= 2) {
                MonitorGet(2, &L, &T, &R, &B)
                if (!defX2)
                    defX2 := L + 10
                if (!defY2)
                    defY2 := T + 120
            }
        } catch {
        }
    }
    if (!defX2)
        defX2 := (SETTINGS.Has("DashboardX") ? SETTINGS["DashboardX"] : 10)
    if (!defY2)
        defY2 := (SETTINGS.Has("DashboardY") ? SETTINGS["DashboardY"] : 120)

    ShowTooltipForScreen(text, 20, defX2, defY2)
}

ShowTooltipForScreen(text, tooltipId, tooltipX, tooltipY) {
    global SETTINGS
    static prevTextMap := Map()
    static hideUntilMap := Map()
    static wasHiddenMap := Map()

    lines := StrSplit(text, "`n")
    maxLen := 0
    for _, ln in lines {
        l := StrLen(ln)
        if (l > maxLen)
            maxLen := l
    }
    widthPx := Min(650, Max(200, maxLen * 7))
    heightPx := Max(18, lines.Length * 18)

    hideUntilTick := hideUntilMap.Has(tooltipId) ? hideUntilMap[tooltipId] : 0
    if (A_TickCount < hideUntilTick) {
        ToolTip(, , , tooltipId)
        wasHiddenMap[tooltipId] := true
        return
    }

    if (IsObject(SETTINGS) && SETTINGS.Has("DashboardHideOnHover") && SETTINGS["DashboardHideOnHover"]) {
        MouseGetPos &mx, &my
        if (mx >= tooltipX && mx <= tooltipX + widthPx && my >= tooltipY && my <= tooltipY + heightPx) {
            ToolTip(, , , tooltipId)
            hideUntilMap[tooltipId] := A_TickCount + 1500
            wasHiddenMap[tooltipId] := true
            return
        }
    }

    prevText := prevTextMap.Has(tooltipId) ? prevTextMap[tooltipId] : ""
    wasHidden := wasHiddenMap.Has(tooltipId) ? wasHiddenMap[tooltipId] : false
    if (text = prevText && !wasHidden)
        return

    prevTextMap[tooltipId] := text
    ToolTip(text, tooltipX, tooltipY, tooltipId)
    wasHiddenMap[tooltipId] := false
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

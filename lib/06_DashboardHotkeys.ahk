; ============================================================
; 06_DashboardHotkeys.ahk - Dashboard UI and Hotkeys
; ============================================================

UpdateDashboardTimer(*) {
    UpdateDashboard()
}

UpdateDashboard() {
    global STATE
    if !IsObject(STATE) {
        Info("STATE object not ready for dashboard update.")
        return
    }

    battery := GetBatteryPercent()
    ; لا نستخدم أي رموز أو تزيينات للبطارية، نسبة فقط
    batteryPercentText := (battery = -1) ? "N/A" : battery . "%"
    ; أزلنا رمز التحذير ⚠ للحفاظ على بساطة العرض
    ; if (battery != -1 && battery <= 20)
    ;     batteryPercentText := "⚠ " . batteryPercentText

    ; خمول فعلي من النظام + آخر نشاط داخلي
    idlePhysical := A_TimeIdlePhysical
    idleCombined := Max(idlePhysical, A_TickCount - (STATE.Has("lastUserActivity") ? STATE["lastUserActivity"] : A_TickCount))
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

    ; --- مؤشر الإنترنت ---
    netLine := "Network: N/A"
    if (STATE.Has("netOnline")) {
    if (STATE["netOnline"]) {
    netLine := "Network: ✅ Online"
    } else {
    offlineElapsed := A_TickCount - (STATE.Has("netLastChangeTick") ? STATE["netLastChangeTick"] : A_TickCount)
    netLine := "Network: ❌ Offline (" . (offlineElapsed // 60000) . "m " . Mod(offlineElapsed // 1000, 60) . "s)"
    }
    }

    ; --- آخر حالة تيليجرام (تم إخفاؤها من العرض حسب طلبك) ---
    ; lastTG := STATE.Has("lastTelegramStatus") ? STATE["lastTelegramStatus"] : "N/A"

    ; --- الطوابع الزمنية: آخر تشيك/ريفريش/ستاي أونلاين ---
    lastCheck := STATE.Has("lastStatusCheckTimestamp") ? STATE["lastStatusCheckTimestamp"] : "Never"
    lastRefresh := STATE.Has("lastRefreshTimestamp") ? STATE["lastRefreshTimestamp"] : "Never"
    lastStay := STATE.Has("lastStayOnlineTimestamp") ? STATE["lastStayOnlineTimestamp"] : "Never"

    ; --- وضع العرض: مضغوط Alt أو مُثبّت عبر Ctrl+Alt+D ---
    isExpanded := GetKeyState("Alt", "P") || (STATE.Has("dashboardExpanded") ? STATE["dashboardExpanded"] : false)

    ; لو موسّع: لا نعرض مربعات البطارية، فقط النسبة
    batteryText := batteryPercentText
    if (isExpanded && battery >= 0) {
        ; إزالة رسم المربعات والرموز
        batteryText := batteryPercentText
    }
    ; إزالة بناء البلوكات تمامًا
    ; batteryBlocks := ""
    ; filled := Floor(battery / 10)
    ; Loop 10
    ;     batteryBlocks .= (A_Index <= filled) ? "■" : "□"
    ; batteryText := "🔋 [" . batteryBlocks . "] " . batteryPercentText

    statusText := (STATE.Has("onlineStatus") ? STATE["onlineStatus"] : "N/A")
    alarmText := alarmStatus
    netShort := "Network N/A"
    if (STATE.Has("netOnline"))
        netShort := STATE["netOnline"] ? "Network ✅" : "Network ❌"

    if !isExpanded {
        ; نسخة مضغوطة: سطران فقط + تلميح للاختصار (بدون عرض TG)
        text := "S: " . statusText . " | " . netShort . " | Battery " . batteryPercentText . " | Idle " . idleText . "`n"
         text .= "(Ctrl+Alt+D للتفاصيل)"
    } else {
        ; نسخة موسّعة بكامل التفاصيل (بدون عرض Last TG)
        text := "Script: " . (STATE.Has("scriptStatus") ? STATE["scriptStatus"] : "N/A") . "`n"
        text .= "Status: " . statusText . " | Alarm: " . alarmText . "`n"
        text .= netLine . "`n"
        text .= "Battery: " . batteryText . " | User Idle: " . idleText . "`n"
        text .= "Last Check: " . lastCheck . " | Last Refresh: " . lastRefresh . "`n"
        text .= "Last Stay Online: " . lastStay
    }

    ; كاش لتقليل الفليكر
    static prevText := ""
    if (text = prevText)
        return
    prevText := text

    tooltipId := 20
    tooltipX := 10, tooltipY := 40

    ; تحسين الإخفاء: عند وقوف الماوس داخل منطقة التولتيب، أخفِ وتعطيل العرض 1.5 ثانية لمنع الوميض/التهنيج
    static hideUntilTick := 0

    lines := StrSplit(text, "`n")
    maxLen := 0
    for _, ln in lines {
        l := StrLen(ln)
        if (l > maxLen)
            maxLen := l
    }
    widthPx := Min(650, Max(200, maxLen * 7))
    heightPx := Max(18, lines.Length * 18)

    if (A_TickCount < hideUntilTick) {
        ToolTip(, , , tooltipId)
        return
    }

    MouseGetPos &mx, &my
    if (mx >= tooltipX && mx <= tooltipX + widthPx && my >= tooltipY && my <= tooltipY + heightPx) {
        ToolTip(, , , tooltipId)
        hideUntilTick := A_TickCount + 1500
        return
    }

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

    if (STATE.Has("isAlarmPlaying") && STATE["isAlarmPlaying"]) {
        STATE["isAlarmPlaying"] := false
        SetTimer(AlarmBeep, 0)
        STATE["offlineFixAttempts"] := 0
        STATE["isMonitoringPaused"] := true
        Info("Alarm stopped by CapsLock. Monitoring paused for " . (SETTINGS["ManualPauseDuration"]/1000) . " seconds.")
        SetTimer(ResumeMonitoring, -SETTINGS["ManualPauseDuration"])
    }
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

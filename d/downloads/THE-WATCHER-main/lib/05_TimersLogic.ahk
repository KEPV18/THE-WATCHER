ClickStayOnlineButton() {
    global SETTINGS, STATE
    static clickingBusy := false
    static clickTimeout := 10000  ; timeout بعد 10 ثواني
    static lastClickTime := 0
    
    ; منع التداخل مع timeout
    if (clickingBusy) {
        if (A_TickCount - lastClickTime > clickTimeout) {
            clickingBusy := false
            LogError("Click operation timed out - resetting lock")
        } else {
            return
        }
    }
    
    clickingBusy := true
    lastClickTime := A_TickCount
    
    try {
        // ... existing code ...
    } catch as err {
        LogError("Click operation failed: " . err.Message)
    } finally {
        clickingBusy := false
    }
}

MonitorTargetTimer(*) {
    global SETTINGS, STATE
    static lastIdleCheck := 0
    
    ; تحقق من الخمول كل 10 ثواني فقط
    if (A_TickCount - lastIdleCheck < 10000) {
        return
    }
    lastIdleCheck := A_TickCount
    
    try {
        StatusCheckTimer(*) {
            local knownStatusFound := false, foundX, foundY
            local goodStates := ["Online", "WorkOnMyTicket", "Break", "Launch"]
            
            ; فحص صور حالة أونلاين المتعددة أولاً
            if (!knownStatusFound) {
                local onlineImages := ["OnlineImage", "OnlineImage2"]
                for imageName in onlineImages {
                    if (SETTINGS.Has(imageName) && ReliableImageSearch(&foundX, &foundY, SETTINGS[imageName], statusArea)) {
                        if (STATE["onlineStatus"] != "Online") {
                            Info("Status changed to: Online (using " . imageName . ")")
                            UpdateStatusDurations("Online")
                            STATE["onlineStatus"] := "Online"
                            STATE["offlineFixAttempts"] := 0
                        }
                        knownStatusFound := true
                        break
                    }
                }
            }
            
            ; فحص باقي الحالات
            if (!knownStatusFound) {
                for stateName in goodStates {
                    if (stateName = "Online") {
                        continue  ; تم فحصها بالفعل
                    }
                    // ... existing code ...
                }
            }
        }
    } catch as err {
        LogError("Click operation failed: " . err.Message)
    } finally {
        clickingBusy := false
    }
}
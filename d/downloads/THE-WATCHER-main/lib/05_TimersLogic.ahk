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
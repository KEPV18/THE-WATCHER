; ============================================================
; 04_Helpers.ahk - Final (AHK v2)
; Reliable helpers: Telegram, screenshots, image search, utils
; ============================================================
#Requires AutoHotkey v2

; ---------------- Reliable Image Search ----------------
ReliableImageSearch(&foundX, &foundY, ImageFile, SearchArea := "") {
    static imageCache := Map()
    foundX := -1
    foundY := -1

    if (!FileExist(ImageFile)) {
        try {
            Warn("Image file not found: " . ImageFile)
        }
        return false
    }

    ; تحسين التخزين المؤقت للصور وإدارة الذاكرة
    if (!imageCache.Has(ImageFile)) {
        try {
            pBitmap := Gdip_CreateBitmapFromFile(ImageFile)
            if (pBitmap) {
                imageCache[ImageFile] := pBitmap
            }
        }
    }

    ; استخدام الصورة المخزنة مؤقتاً
    pBitmap := imageCache[ImageFile]
    if (!pBitmap) {
        return false
    }

    ; تحسين دقة البحث
    tol := 30  ; تقليل التسامح للحصول على نتائج أدق
    try {
        if (IsObject(SETTINGS) && SETTINGS.Has("ImageSearchTolerance"))
            tol := SETTINGS["ImageSearchTolerance"]
    }

    ; تحسين منطقة البحث
    local searchX1 := 0, searchY1 := 0, searchX2 := A_ScreenWidth, searchY2 := A_ScreenHeight
    try {
        if (IsObject(SearchArea) && SearchArea.Has("x1")) {
            searchX1 := SearchArea.x1
            searchY1 := SearchArea.y1
            searchX2 := SearchArea.x2
            searchY2 := SearchArea.y2
        }
    }

    ; تحسين أداء البحث
    try {
        CoordMode "Pixel", "Screen"
        searchParam := "*" . tol . " *TransBlack " . ImageFile
        if (ImageSearch(&foundX, &foundY, searchX1, searchY1, searchX2, searchY2, searchParam)) {
            return true
        }
    } catch as err {
        try {
            LogError("ImageSearch failed: " . err.Message)
        }
        return false
    }

    return false
}

; ---------------- Save Status Screenshot ----------------
SaveStatusScreenshotEnhanced(statusName := "unknown") {
    global SETTINGS
    local result := Map("ok", false, "reason", "unknown error", "file", "")

    x := 0
    y := 0
    brx := 0
    bry := 0

    try {
        if IsObject(SETTINGS) {
            if (SETTINGS.Has("StatusAreaTopLeftX"))
                x := SETTINGS["StatusAreaTopLeftX"]
            if (SETTINGS.Has("StatusAreaTopLeftY"))
                y := SETTINGS["StatusAreaTopLeftY"]
            if (SETTINGS.Has("StatusAreaBottomRightX"))
                brx := SETTINGS["StatusAreaBottomRightX"]
            if (SETTINGS.Has("StatusAreaBottomRightY"))
                bry := SETTINGS["StatusAreaBottomRightY"]
        }
    } catch {
        ; Do nothing
    }

    w := brx - x
    h := bry - y

    if (w <= 0 || h <= 0) {
        try {
            Warn("SaveStatusScreenshotEnhanced: invalid capture area (w:" . w . ", h:" . h . "). Check settings.")
        } catch {
            ; Do nothing
        }
        result.reason := "invalid area"
        return result
    }

    ts := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    ; احفظ داخل مجلد screenshots دائماً
    baseDir := A_ScriptDir . "\screenshots"
    try {
        if !DirExist(baseDir)
            DirCreate(baseDir)
    } catch {
        ; لو فشل إنشاء المجلد استخدم الدليل الحالي كاحتياط
        baseDir := A_ScriptDir
    }
    finalName := baseDir . "\" . statusName . "_" . ts . ".png"

    try {
        hBmp := CaptureAreaBitmap(x, y, w, h)
        if (!hBmp) {
            try {
                Warn("SaveStatusScreenshotEnhanced: CaptureAreaBitmap returned 0.")
            } catch {
                ; Do nothing
            }
            result.reason := "capture_failed"
            return result
        }

        saved := false
        try {
            saved := Gdip_SaveBitmapToFile(hBmp, finalName)
        } catch {
            saved := false
        }

        if (hBmp)
            DllCall("DeleteObject", "Ptr", hBmp)

        if (!saved) {
            try {
                Warn("SaveStatusScreenshotEnhanced: Gdip save failed.")
            } catch {
                ; Do nothing
            }
            result.reason := "save_failed"
            return result
        }

        try {
            Info("Saved screenshot: " . finalName)
        } catch {
            ; Do nothing
        }
        result.ok := true
        result.reason := "success"
        result.file := finalName
        return result
    } catch {
        try {
            LogError("SaveStatusScreenshotEnhanced CRITICAL (no details).")
        } catch {
            ; Do nothing
        }
        result.reason := "exception"
        return result
    }
}

; ---------------- Send Telegram Error (code block) ----------------
; (function) SendTelegramError
SendTelegramError(errorObject) {
    global BOT_TOKEN, CHAT_ID, STATE
    ; عند انقطاع الإنترنت خزّن تقرير الخطأ
    try {
        if (IsObject(STATE) && STATE.Has("netOnline") && !STATE["netOnline"]) {
            ; نحول التقرير لرسالة نصية مختصرة في الطابور
            msg := "🚨 Script Error (queued while offline)"
            QueueTelegram(Map("type","text", "title", msg, "details", Map("Time", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"))))
            STATE["lastTelegramStatus"] := FormatTime(A_Now, "HH:mm:ss") . " - QUEUED: Error Report"
            return false
        }
    } catch {
        ; تجاهل
    }

    bt := Chr(96) ; backtick char

    ErrorMessage := bt . bt . bt . "`n"
    ErrorMessage .= "SCRIPT CRASH REPORT`n"
    ErrorMessage .= "--------------------`n"

    errMsg := ""
    file := ""
    line := ""
    src := ""
    try {
        if IsObject(errorObject) {
            ; Message
            try {
                errMsg := errorObject.Message
            } catch {
                try {
                    errMsg := errorObject.message
                } catch {
                    ; leave default
                }
            }
            ; File
            try {
                file := errorObject.File
            } catch {
                try {
                    file := errorObject.file
                } catch {
                    ; leave default
                }
            }
            ; Line
            try {
                line := errorObject.Line
            } catch {
                try {
                    line := errorObject.line
                } catch {
                    ; leave default
                }
            }
            ; Extra / Source
            try {
                src := errorObject.Extra
            } catch {
                try {
                    src := errorObject.extra
                } catch {
                    ; leave default
                }
            }
        }
    } catch {
        ; Do nothing
    }

    ErrorMessage .= "Message: " . (errMsg != "" ? errMsg : "N/A") . "`n"
    ErrorMessage .= "File: " . (file != "" ? file : "N/A") . "`n"
    ErrorMessage .= "Line: " . (line != "" ? line : "N/A") . "`n"
    ErrorMessage .= "Source: " . (src != "" ? src : "N/A") . "`n"
    ErrorMessage .= bt . bt . bt

    ErrorMessage .= "Error: " . (errMsg ? errMsg : "[no message]") . "`n"
    if (file)
        ErrorMessage .= "File: " . file . "`n"
    if (line)
        ErrorMessage .= "Line: " . line . "`n"
    if (src)
        ErrorMessage .= "Source: " . src . "`n"
    ErrorMessage .= "Time: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "`n"
    ErrorMessage .= bt . bt . bt

    ; Guard: skip Telegram send if credentials missing
    if (!BOT_TOKEN || !CHAT_ID) {
        Warn("SendTelegramError skipped: missing BOT_TOKEN/CHAT_ID")
        return
    }

    TelegramURL := "https://api.telegram.org/bot" . BOT_TOKEN . "/sendMessage"
    postBody := "chat_id=" . CHAT_ID . "&text=" . UriEncode(ErrorMessage) . "&parse_mode=Markdown"

    try {
        Req := ComObject("WinHttp.WinHttpRequest.5.1")
        Req.Open("POST", TelegramURL, false)
        Req.SetTimeouts(2000, 2000, 2000, 2000)
        Req.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        Req.Send(postBody)
    } catch {
        try {
            FileAppend(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - SendTelegramError failed.`n" . ErrorMessage . "`n`n", A_ScriptDir "\watcher_send_error.log", "UTF-8")
        } catch {
            ; Do nothing
        }
    }
}

; ---------------- Send Rich Telegram Notification ----------------
; (function) SendRichTelegramNotification
SendRichTelegramNotification(title, detailsMap) {
    global BOT_TOKEN, CHAT_ID, STATE
    ; عند انقطاع الإنترنت خزّن الرسالة في الطابور
    try {
        if (IsObject(STATE) && STATE.Has("netOnline") && !STATE["netOnline"]) {
            QueueTelegram(Map("type","text", "title", title, "details", detailsMap))
            STATE["lastTelegramStatus"] := FormatTime(A_Now, "HH:mm:ss") . " - QUEUED: " . title
            return false
        }
    } catch {
        ; تجاهل
    }

    MessageText := "*" . title . "*`n"
    MessageText .= "--------------------`n"

    try {
        if IsObject(detailsMap) {
            for key, value in detailsMap
                MessageText .= "*" . key . ":* " . value . "`n"
        }
    } catch {
        ; Do nothing
    }

    ; Guard: skip Telegram send if credentials missing
    if (!BOT_TOKEN || !CHAT_ID) {
        Warn("SendRichTelegramNotification skipped: missing BOT_TOKEN/CHAT_ID")
        return false
    }

    TelegramURL := "https://api.telegram.org/bot" . BOT_TOKEN . "/sendMessage"
    postBody := "chat_id=" . CHAT_ID . "&text=" . UriEncode(MessageText) . "&parse_mode=Markdown"

    sendStatus := "UNKNOWN"
    try {
        Req := ComObject("WinHttp.WinHttpRequest.5.1")
        Req.Open("POST", TelegramURL, false)
        ; أضف مهلات زمنية صريحة لتفادي الانتظار الطويل (2 ثانية لكل مرحلة)
        Req.SetTimeouts(2000, 2000, 2000, 2000)
        Req.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        Req.Send(postBody)

        statusCode := ""
        respText := ""
        try {
            statusCode := Req.Status
            respText := Req.ResponseText
        } catch {
            ; Do nothing
        }

        if (statusCode && (statusCode >= 200 && statusCode < 300)) {
            try {
                Info("Telegram Rich Message SUCCESS: " . title)
            } catch {
                ; Do nothing
            }
            sendStatus := FormatTime(A_Now, "HH:mm:ss") . " - " . title . " (Success)"
        } else {
            try {
                Warn("Telegram Rich Message FAILED: " . title . ". Status: " . statusCode)
            } catch {
                ; Do nothing
            }
            sendStatus := FormatTime(A_Now, "HH:mm:ss") . " - " . title . " (FAIL: " . statusCode . ")"
            try {
                FileAppend(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - Telegram returned status " . statusCode . " for " . title . "`nResponse: " . SubStr(respText, 1, 1000) . "`n`n", A_ScriptDir "\watcher_send_error.log", "UTF-8")
            } catch {
            }
        }
    } catch {
        try {
            LogError("Telegram Rich Message CRITICAL FAIL: " . title . " (no details).")
        } catch {
            ; Do nothing
        }
        sendStatus := FormatTime(A_Now, "HH:mm:ss") . " - " . title . " (CRITICAL FAIL)"
    }

    try {
        if IsObject(STATE)
            STATE["lastTelegramStatus"] := sendStatus
    } catch {
        ; Do nothing
    }
}

; ---------------- Send Telegram Photo (multipart) ----------------
; (function) SendTelegramPhoto
SendTelegramPhoto(photoPath, caption) {
    global BOT_TOKEN, CHAT_ID, STATE
    ; عند انقطاع الإنترنت خزّن الصورة للإرسال لاحقاً
    try {
        if (IsObject(STATE) && STATE.Has("netOnline") && !STATE["netOnline"]) {
            QueueTelegram(Map("type","photo", "path", photoPath, "caption", caption))
            STATE["lastTelegramStatus"] := FormatTime(A_Now, "HH:mm:ss") . " - QUEUED PHOTO"
            return false
        }
    } catch {
        ; تجاهل
    }

    ; Guard: skip Telegram send if credentials missing
    ; Guard: skip Telegram send if credentials missing
    if (!BOT_TOKEN || !CHAT_ID) {
        Warn("SendTelegramPhoto skipped: missing BOT_TOKEN/CHAT_ID")
        if IsObject(STATE)
            STATE["lastTelegramStatus"] := FormatTime(A_Now, "HH:mm:ss") . " - Photo Skipped (NO CREDS)"
        return false
    }
    if !FileExist(photoPath) {
        try {
            Warn("SendTelegramPhoto: File not found -> " . photoPath)
        } catch {
            ; Do nothing
        }
        return
    }

    boundary := "----" . A_TickCount . A_Now
    payload := ""
    qq := Chr(34)  ; safe quote character

    payload .= "--" . boundary . "`r`n"
    payload .= "Content-Disposition: form-data; name=" . qq . "chat_id" . qq . "`r`n`r`n"
    payload .= CHAT_ID . "`r`n"
    payload .= "--" . boundary . "`r`n"
    payload .= "Content-Disposition: form-data; name=" . qq . "caption" . qq . "`r`n`r`n"
    payload .= caption . "`r`n"
    payload .= "--" . boundary . "`r`n"

    ; build filename safely using single-quoted literal to avoid escaping double-quotes
    fileNameOnly := StrSplit(photoPath, "\\").Pop()
    payload .= "Content-Disposition: form-data; name=" . qq . "photo" . qq . "; filename=" . qq . fileNameOnly . qq . "`r`n"
    payload .= "Content-Type: image/png`r`n`r`n"

    file := FileOpen(photoPath, "r")
    if (!IsObject(file)) {
        try {
            Warn("SendTelegramPhoto: failed to open file -> " . photoPath)
        } catch {
            ; Do nothing
        }
        return
    }

    ; اقرأ محتوى الملف إلى Buffer بدلاً من استخدام مؤشر غير مهيأ
    try {
        buf := Buffer(file.Size)
        file.RawRead(buf, file.Size)
        file.Close()
    } catch {
        try {
            Warn("SendTelegramPhoto: failed to read file -> " . photoPath)
        } catch {
            ; Do nothing
        }
        return
    }

    ; احسب الأطوال بالبايت (CP0) بدون تضمين محرف النهاية null
    bytesPrefix := StrPut(payload, 0, "CP0") - 1
    trailer := "`r`n--" . boundary . "--`r`n"
    bytesTrailer := StrPut(trailer, 0, "CP0") - 1
    finalPayload := Buffer(bytesPrefix + buf.Size + bytesTrailer)

    ; اكتب المقدمة الثنائية، ثم الصورة، ثم الذيل
    StrPut(payload, finalPayload, "CP0")
    DllCall("RtlMoveMemory", "Ptr", finalPayload.Ptr + bytesPrefix, "Ptr", buf.Ptr, "Ptr", buf.Size)
    StrPut(trailer, finalPayload.Ptr + bytesPrefix + buf.Size, "CP0")

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", "https://api.telegram.org/bot" . BOT_TOKEN . "/sendPhoto", false)
        whr.SetRequestHeader("Content-Type", "multipart/form-data; boundary=" . boundary)
        ; مهلات صريحة لتفادي التعليق الطويل
        whr.SetTimeouts(2000, 2000, 2000, 2000)
        whr.Send(finalPayload)

        if (whr.Status = 200) {
            try {
                Info("Telegram Photo SUCCESS: " . caption)
            } catch {
                ; Do nothing
            }
            try {
                if IsObject(STATE)
                    STATE["lastTelegramStatus"] := FormatTime(A_Now, "HH:mm:ss") . " - Photo Sent (Success)"
            } catch {
                ; Do nothing
            }
        } else {
            try {
                Warn("Telegram Photo FAILED: " . caption . ". Status: " . whr.Status . " | Response: " . whr.ResponseText)
            } catch {
                ; Do nothing
            }
            try {
                if IsObject(STATE)
                    STATE["lastTelegramStatus"] := FormatTime(A_Now, "HH:mm:ss") . " - Photo Sent (FAIL: " . whr.Status . ")"
            } catch {
                ; Do nothing
            }
        }
    } catch {
        try {
            Warn("Telegram Photo CRITICAL FAIL: " . caption)
        } catch {
            ; Do nothing
        }
        try {
            if IsObject(STATE)
                STATE["lastTelegramStatus"] := FormatTime(A_Now, "HH:mm:ss") . " - Photo Sent (CRITICAL FAIL)"
        } catch {
            ; Do nothing
        }
    }
}
; ---------------- Simple wrapper ----------------
SendTelegramNotification(EventName) {
    SendRichTelegramNotification(EventName, Map())
}

; ---------------- GetFileMD5 ----------------
GetFileMD5(filePath) {
    global ComSpec
    try {
        if !FileExist(filePath)
            return ""
        cmd := Format('{} /c certutil -hashfile "{}" MD5', ComSpec, filePath)
        proc := ComObject("WScript.Shell").Exec(cmd)
        out := proc.StdOut.ReadAll()
        lines := StrSplit(out, "`n", "`r")
        for line in lines {
            if (!InStr(line, "MD5 hash") && !InStr(line, "CertUtil") && StrLen(Trim(line)) = 32)
                return Trim(line)
        }
        return ""
    } catch {
        try {
            LogError("GetFileMD5 failed (no details).")
        } catch {
            ; Do nothing
        }
        return ""
    }
}

; ---------------- UriEncode ----------------
UriEncode(str, encoding := "UTF-8") {
    static chars := "0123456789ABCDEF"
    if (str = "")
        return ""
    bytes := StrPut(str, encoding) - 1
    buf := Buffer(bytes)
    StrPut(str, buf, encoding)
    result := ""
    Loop bytes {
        c := NumGet(buf, A_Index - 1, "UChar")
        if ((c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c = 0x2D || c = 0x2E || c = 0x5F || c = 0x7E)
            result .= Chr(c)
        else
            result .= "%" . SubStr(chars, (c >> 4) + 1, 1) . SubStr(chars, (c & 0xF) + 1, 1)
    }
    return result
}

; ---------------- GetBatteryPercent ----------------
GetBatteryPercent() {
    try {
        powerStatus := Buffer(12, 0)
        if DllCall("GetSystemPowerStatus", "Ptr", powerStatus) {
            lifePercent := NumGet(powerStatus, 2, "UChar")
            return (lifePercent > 100) ? -1 : lifePercent
        }
        return -1
    } catch {
        return -1
    }
}

; ---------------- Show Local Notification ----------------
ShowLocalNotification(message) {
    ToolTip(message, 10, 10)
    SetTimer(() => ToolTip(), -3000)
}

; (new function) HttpCheckInternet + Queue/Flush helpers

HttpCheckInternet(timeoutMs := 2500) {
    ; محاولة طلب رأس (HEAD) إلى api.telegram.org (خفيف وآمن حتى لو التوكن غير مستخدم)
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("HEAD", "https://api.telegram.org/", true)
        whr.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
        whr.Send()
        whr.WaitForResponse(timeoutMs)
        status := whr.Status
        return (status >= 200 && status < 400)
    } catch {
        return false
    }
}

QueueTelegram(item) {
    global STATE
    try {
        if (!IsObject(STATE) || !STATE.Has("telegramQueue"))
            return
        STATE["telegramQueue"].Push(item)
    } catch {
        ; ignore
    }
}

FlushTelegramQueue() {
    global STATE
    try {
        if (!IsObject(STATE) || !STATE.Has("telegramQueue"))
            return
        while (STATE["telegramQueue"].Length > 0) {
            itm := STATE["telegramQueue"].RemoveAt(1)
            if (!itm.Has("type"))
                continue
            if (itm["type"] = "text") {
                title := itm.Has("title") ? itm["title"] : "Queued Message"
                details := itm.Has("details") ? itm["details"] : Map()
                SendRichTelegramNotification("[Queued] " . title, details)
            } else if (itm["type"] = "photo") {
                p := itm.Has("path") ? itm["path"] : ""
                c := itm.Has("caption") ? itm["caption"] : ""
                if (p != "")
                    SendTelegramPhoto(p, "[Queued] " . c)
            }
        }
        if (STATE.Has("lastTelegramStatus"))
            STATE["lastTelegramStatus"] := FormatTime(A_Now, "HH:mm:ss") . " - Queue flushed"
    } catch {
        ; ignore
    }
}

; ---------------- State Persistence (INI) ----------------
SaveStateSnapshot(path) {
    global STATE
    try {
        IniWrite(STATE.Has("netDowntimeMs") ? STATE["netDowntimeMs"] : 0, path, "STATE", "netDowntimeMs")
        IniWrite(STATE.Has("scriptStartTime") ? STATE["scriptStartTime"] : A_Now, path, "STATE", "scriptStartTime")
        IniWrite(STATE.Has("lastReportTime") ? STATE["lastReportTime"] : A_Now, path, "STATE", "lastReportTime")
        IniWrite(STATE.Has("lastStatusChangeTick") ? STATE["lastStatusChangeTick"] : A_TickCount, path, "STATE", "lastStatusChangeTick")
        IniWrite(STATE.Has("currentStatus") ? STATE["currentStatus"] : "Unknown", path, "STATE", "currentStatus")
        IniWrite(STATE.Has("lastTelegramStatus") ? STATE["lastTelegramStatus"] : "None", path, "STATE", "lastTelegramStatus")

        ; حفظ مدد الحالات
        if (STATE.Has("statusDurations")) {
            for k, v in STATE["statusDurations"] {
                IniWrite(v, path, "DURATIONS", k)
            }
        }
    } catch {
        ; تجاهل
    }
}

LoadStateSnapshot(path) {
    global STATE
    try {
        if !FileExist(path)
            return
        nd := IniRead(path, "STATE", "netDowntimeMs", "")
        if (nd != "")
            STATE["netDowntimeMs"] := nd + 0
        ss := IniRead(path, "STATE", "scriptStartTime", "")
        if (ss != "")
            STATE["scriptStartTime"] := ss
        lr := IniRead(path, "STATE", "lastReportTime", "")
        if (lr != "")
            STATE["lastReportTime"] := lr
        lt := IniRead(path, "STATE", "lastStatusChangeTick", "")
        if (lt != "")
            STATE["lastStatusChangeTick"] := lt + 0
        cs := IniRead(path, "STATE", "currentStatus", "")
        if (cs != "")
            STATE["currentStatus"] := cs
        lts := IniRead(path, "STATE", "lastTelegramStatus", "")
        if (lts != "")
            STATE["lastTelegramStatus"] := lts

        ; تحميل مدد الحالات (إن وجدت)
        if !STATE.Has("statusDurations")
            STATE["statusDurations"] := Map()
        for name in ["Online","WorkOnMyTicket","Break","Launch","Offline","Unknown"] {
            d := IniRead(path, "DURATIONS", name, "")
            if (d != "")
                STATE["statusDurations"][name] := d + 0
        }
    } catch {
        ; تجاهل
    }
}

; ---------------- Save Target Word Area Screenshot ----------------
SaveTargetWordScreenshot(label := "target_missing") {
    global SETTINGS
    local result := Map("ok", false, "reason", "unknown error", "file", "")

    x := SETTINGS.Has("TargetAreaTopLeftX") ? SETTINGS["TargetAreaTopLeftX"] : 0
    y := SETTINGS.Has("TargetAreaTopLeftY") ? SETTINGS["TargetAreaTopLeftY"] : 0
    brx := SETTINGS.Has("TargetAreaBottomRightX") ? SETTINGS["TargetAreaBottomRightX"] : 0
    bry := SETTINGS.Has("TargetAreaBottomRightY") ? SETTINGS["TargetAreaBottomRightY"] : 0

    w := brx - x, h := bry - y
    if (w <= 0 || h <= 0) {
        result.reason := "invalid area"
        return result
    }

    ts := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    baseDir := A_ScriptDir . "\screenshots\target word"
    try {
        if !DirExist(baseDir)
            DirCreate(baseDir)
    }
    finalName := baseDir . "\" . label . "_" . ts . ".png"

    try {
        hBmp := CaptureAreaBitmap(x, y, w, h)
        if (!hBmp) {
            result.reason := "capture_failed"
            return result
        }
        saved := Gdip_SaveBitmapToFile(hBmp, finalName)
        if (hBmp)
            DllCall("DeleteObject", "Ptr", hBmp)
        if (!saved) {
            result.reason := "save_failed"
            return result
        }
        result.ok := true
        result.file := finalName
        result.reason := "success"
        try Info("Saved target-word screenshot: " . finalName)
    }
    return result
}

; ---------------- Save Stay Online Area Screenshot ----------------
SaveStayOnlineScreenshot(label := "stay_online") {
    global SETTINGS
    local result := Map("ok", false, "reason", "unknown error", "file", "")

    x := SETTINGS.Has("StayOnlineAreaTopLeftX") ? SETTINGS["StayOnlineAreaTopLeftX"] : 0
    y := SETTINGS.Has("StayOnlineAreaTopLeftY") ? SETTINGS["StayOnlineAreaTopLeftY"] : 0
    brx := SETTINGS.Has("StayOnlineAreaBottomRightX") ? SETTINGS["StayOnlineAreaBottomRightX"] : 0
    bry := SETTINGS.Has("StayOnlineAreaBottomRightY") ? SETTINGS["StayOnlineAreaBottomRightY"] : 0

    w := brx - x, h := bry - y
    if (w <= 0 || h <= 0) {
        result.reason := "invalid area"
        return result
    }

    ts := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    baseDir := A_ScriptDir . "\screenshots\stay online"
    try {
        if !DirExist(baseDir)
            DirCreate(baseDir)
    }
    finalName := baseDir . "\" . label . "_" . ts . ".png"

    try {
        hBmp := CaptureAreaBitmap(x, y, w, h)
        if (!hBmp) {
            result.reason := "capture_failed"
            return result
        }
        saved := Gdip_SaveBitmapToFile(hBmp, finalName)
        if (hBmp)
            DllCall("DeleteObject", "Ptr", hBmp)
        if (!saved) {
            result.reason := "save_failed"
            return result
        }
        result.ok := true
        result.file := finalName
        result.reason := "success"
        try Info("Saved stay-online screenshot: " . finalName)
    }
    return result
}
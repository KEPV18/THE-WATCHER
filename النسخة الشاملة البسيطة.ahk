#Requires AutoHotkey v2.0
#SingleInstance Force
; (أُزيلت #Persistent لأنها غير مدعومة في v2)
SetWorkingDir(A_ScriptDir)
CoordMode("Pixel", "Screen")
CoordMode("Mouse", "Screen")
SetTitleMatchMode(2)

; النسخة الشاملة البسيطة (إصدار AHK v2):
; - هيكلية بالدوال بدون Labels/GoSub
; - الاعتماد الأساسي على فحص البكسل بدل الصور (صور اختيارية)
; - لقطات شاشة عبر GDI+ مباشرة بدون MSPaint
; - تكامل نصي بسيط مع Telegram
; - خيار إيقاف العمل أثناء نشاط المستخدم لتجنّب التعارض

; إعدادات عامة ومسارات
logFile := A_ScriptDir "\log_simple_v2.txt"
screenshotDir := A_ScriptDir "\logs\simple_screenshots"
DirCreate(screenshotDir)

; إعدادات قابلة للتعديل (بدون settings.ini)
config := Map()
config["STAY_ONLINE_X"] := 114
config["STAY_ONLINE_Y"] := 73
config["REFRESH_X"] := 114
config["REFRESH_Y"] := 73
config["STATUS_X"] := 114
config["STATUS_Y"] := 73
config["STATUS_COLOR_OFFLINE"] := 0x000000  ; عدّل اللون حسب واجهتك

; منطقة فحص التارجت (بالإحداثيات)
config["TARGET_X1"] := 0
config["TARGET_Y1"] := 800
config["TARGET_X2"] := A_ScreenWidth
config["TARGET_Y2"] := A_ScreenHeight

; طريقة فحص التارجت
config["TARGET_BY_PIXEL"] := true               ; اجعلها true للاعتماد على PixelSearch
config["TARGET_COLOR"] := 0xFFFFFF              ; لون مرجعي للتارجت (عدّله)
config["TARGET_COLOR_VAR"] := 10                ; سماحية اختلاف اللون في PixelSearch
config["USE_IMAGES_STATUS"] := false            ; صور الحالة اختيارية
config["USE_IMAGES_TARGET"] := false            ; صور التارجت اختيارية
config["IMG_TOL"] := 120                        ; تحمل البحث بالصور إن تم تفعيله

; أزمنة التشغيل
config["STAY_ONLINE_INTERVAL"] := 90000         ; 90 ثانية
config["STATUS_CHECK_INTERVAL"] := 1000         ; 1 ثانية
config["TARGET_CHECK_INTERVAL"] := 1000         ; 1 ثانية
config["TARGET_RETRY_MS"] := 3000               ; 3 ثواني
config["POST_REFRESH_DELAY"] := 800             ; مهلة بعد الضغط على تحديث

; إيقاف العمل أثناء نشاط المستخدم
config["PAUSE_WHEN_ACTIVE"] := true             ; أوقف أثناء النشاط الحقيقي
config["IDLE_THRESHOLD_MS"] := 5000             ; اعتبر المستخدم نشطاً إن كان الخمول أقل من 5 ثوان

; تكامل Telegram (نصي فقط الآن)
config["TELEGRAM_BOT_TOKEN"] := ""
config["TELEGRAM_CHAT_ID"] := ""
; إعدادات Front Line (تُعرّف هنا قبل Main)
config["FRONTLINE_TITLE"] := "Front Line"
config["FRONTLINE_EXE"] := ""
config["FRONTLINE_CHECK_INTERVAL"] := 5000
config["FRONTLINE_RESTART_ON_HANG"] := true

; حالة الإنذار
isNetAlarmPlaying := false
isTargetAlarmPlaying := false
isAlarmPlaying := false
muteAlarm := false
retryScheduled := false

; نقطة بدء
Main()

Main() {
    global logFile
    Log("[START] تشغيل النسخة الشاملة البسيطة v2 بدون انتظار مبدئي")
    ; مؤقتات v2
    SetTimer(StatusCheckTimer, Config("STATUS_CHECK_INTERVAL"))
    SetTimer(StayOnlineClickTimer, Config("STAY_ONLINE_INTERVAL"))
    SetTimer(TargetMonitorTimer, Config("TARGET_CHECK_INTERVAL"))
    SetTimer(AlarmBeep, 0)  ; إيقاف إنذار الصوت مبدئياً
    ; حارس نافذة Front Line
    SetTimer(FrontLineGuardTimer, Config("FRONTLINE_CHECK_INTERVAL"))
}

Config(key) {
    global config
    return config.Has(key) ? config[key] : ""
}

ShouldRun() {
    if !Config("PAUSE_WHEN_ACTIVE")
        return true
    return A_TimeIdle >= Config("IDLE_THRESHOLD_MS")
}

StatusCheckTimer() {
    global isNetAlarmPlaying
    if !ShouldRun()
        return
    if DetectOffline() {
        if !isNetAlarmPlaying {
            isNetAlarmPlaying := true
            UpdateAlarmState()
            Log("[OFFLINE] تم اكتشاف أوفلاين - تشغيل الإنذار ومحاولة الإرجاع أونلاين")
            SaveScreenshot("offline")
            SendTelegramText("[OFFLINE] تم اكتشاف أوفلاين، سيتم محاولة الإصلاح")
        }
        EnsureOnlineStatus()
    } else {
        if isNetAlarmPlaying {
            isNetAlarmPlaying := false
            UpdateAlarmState()
            Log("[ONLINE] رجوع أونلاين - إيقاف إنذار الشبكة")
            SaveScreenshot("online")
            SendTelegramText("[ONLINE] رجعنا أونلاين")
        }
    }
}

StayOnlineClickTimer() {
    if !ShouldRun()
        return
    Log("[ACTION] ضغط زر Stay Online + Refresh دوري")
    Click(Config("STAY_ONLINE_X"), Config("STAY_ONLINE_Y"))
    Sleep(300)
    Click(Config("REFRESH_X"), Config("REFRESH_Y"))
}

TargetMonitorTimer() {
    global isTargetAlarmPlaying, retryScheduled
    if !ShouldRun()
        return
    found := CheckTarget()
    if found {
        if isTargetAlarmPlaying {
            isTargetAlarmPlaying := false
            UpdateAlarmState()
            Log("[TARGET] التارجت موجود - إيقاف إنذار التارجت")
            SendTelegramText("[TARGET] التارجت موجود")
        }
    } else {
        if !retryScheduled {
            retryScheduled := true
            SetTimer(TargetRetry, -Config("TARGET_RETRY_MS"))
            Log("[TARGET] لم يتم العثور على التارجت - سيعاد الفحص بعد " Config("TARGET_RETRY_MS") "ms")
        }
    }
}

TargetRetry() {
    global retryScheduled, isTargetAlarmPlaying
    retryScheduled := false
    if CheckTarget() {
        Log("[TARGET] التارجت ظهر في إعادة المحاولة")
        if isTargetAlarmPlaying {
            isTargetAlarmPlaying := false
            UpdateAlarmState()
            Log("[TARGET] إيقاف إنذار التارجت بعد ظهوره")
        }
    } else {
        Log("[TARGET] لم يظهر التارجت بعد إعادة المحاولة - التقاط صورة وتشغيل الإنذار")
        SaveScreenshot("target_missing")
        SendTelegramText("[TARGET] مفقود بعد إعادة المحاولة")
        if !isTargetAlarmPlaying {
            isTargetAlarmPlaying := true
            UpdateAlarmState()
        }
    }
}

EnsureOnlineStatus() {
    Click(Config("STAY_ONLINE_X"), Config("STAY_ONLINE_Y"))
    Sleep(300)
    Click(Config("REFRESH_X"), Config("REFRESH_Y"))
    Sleep(Config("POST_REFRESH_DELAY"))
}

DetectOffline() {
    offlineByPixel := (PixelGetColor(Config("STATUS_X"), Config("STATUS_Y"), "RGB") = Config("STATUS_COLOR_OFFLINE"))
    if offlineByPixel
        return true
    if Config("USE_IMAGES_STATUS") {
        ; إن رغبت باستعمال الصور (اختياري)
        ; ضع هنا صور الحالة وقم بالبحث عنها
        ; افتراضياً معطل لتخفيف الحمل
    }
    return false
}

CheckTarget() {
    if Config("TARGET_BY_PIXEL") {
        x1 := Config("TARGET_X1"), y1 := Config("TARGET_Y1")
        x2 := Config("TARGET_X2"), y2 := Config("TARGET_Y2")
        tol := Config("TARGET_COLOR_VAR")
        targetColor := Config("TARGET_COLOR")
        local fx := 0, fy := 0
        found := PixelSearch(&fx, &fy, x1, y1, x2, y2, targetColor, tol, "Fast RGB")
        return !!found
    } else if Config("USE_IMAGES_TARGET") {
        ; إن رغبت باستعمال صورة للكلمة المستهدفة (اختياري)
        ; استعمل ImageSearch في v2 بشكل مدروس
        ; مثال:
        ; local fx := 0, fy := 0
        ; found := ImageSearch(&fx, &fy, Config("TARGET_X1"), Config("TARGET_Y1"), Config("TARGET_X2"), Config("TARGET_Y2"), "*" Config("IMG_TOL") " " A_ScriptDir "\\profiles\\target_word.png")
        ; return !!found
        return false
    }
    return false
}

UpdateAlarmState() {
    global isNetAlarmPlaying, isTargetAlarmPlaying, isAlarmPlaying
    prev := isAlarmPlaying
    isAlarmPlaying := (isNetAlarmPlaying || isTargetAlarmPlaying)
    if isAlarmPlaying && !prev {
        SetTimer(AlarmBeep, 1500)
        Log("[ALARM] تشغيل إنذار الصوت")
    } else if !isAlarmPlaying && prev {
        SetTimer(AlarmBeep, 0)
        Log("[ALARM] إيقاف إنذار الصوت")
    }
}

AlarmBeep() {
    global isAlarmPlaying, muteAlarm
    if isAlarmPlaying && !muteAlarm
        SoundBeep(900, 250)
}

; ————— لقطات شاشة عبر GDI+ —————
SaveScreenshot(prefix) {
    global screenshotDir
    DirCreate(screenshotDir)
    ts := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    path := screenshotDir "\" prefix "_" ts ".png"
    CaptureScreenPNG(path)
    Log("[SHOT] تم حفظ لقطة شاشة: " path)
}

CaptureScreenPNG(path) {
    ; كود GDI+ لالتقاط كامل الشاشة وحفظها PNG
    w := A_ScreenWidth, h := A_ScreenHeight
    hdc := DllCall("GetDC", "ptr", 0, "ptr")
    hcdc := DllCall("CreateCompatibleDC", "ptr", hdc, "ptr")
    hbmp := DllCall("CreateCompatibleBitmap", "ptr", hdc, "int", w, "int", h, "ptr")
    obmp := DllCall("SelectObject", "ptr", hcdc, "ptr", hbmp, "ptr")
    DllCall("BitBlt", "ptr", hcdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", hdc, "int", 0, "int", 0, "uint", 0x00CC0020)

    ; بدء GDI+
    si := Buffer(24, 0)
    NumPut("uint", 1, si, 0) ; GdiplusVersion
    pToken := 0
    DllCall("gdiplus\GdiplusStartup", "ptr*", pToken, "ptr", si, "ptr", 0)
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbmp, "ptr", 0, "ptr*", pBitmap)

    ; CLSID PNG
    clsid := Buffer(16, 0)
    GetEncoderClsid("image/png", clsid)
    DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", path, "ptr", clsid, "ptr", 0)

    ; تنظيف
    DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
    DllCall("gdiplus\GdiplusShutdown", "ptr", pToken)
    DllCall("SelectObject", "ptr", hcdc, "ptr", obmp)
    DllCall("DeleteObject", "ptr", hbmp)
    DllCall("DeleteDC", "ptr", hcdc)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)
}

GetEncoderClsid(mimeType, clsidBuf) {
    ; الحصول على CLSID للمُرمِّز
    DllCall("gdiplus\GdipGetImageEncodersSize", "uint*", count, "uint*", size)
    buf := Buffer(size)
    DllCall("gdiplus\GdipGetImageEncoders", "uint", count, "uint", size, "ptr", buf)
    ; بنية ImageCodecInfo: نقرأ الـ MimeType حتى نطابقه
    ; نبحث خطياً عن النوع المطلوب
    offset := 0
    Loop count {
        ; تخطّي حقول حتى نصل لحقل MimeType (wstr pointer)
        ; البنية معقدة، سنستخدم أسلوب بسيط: نجرب قراءة سلسلة الـ MimeType من البوفر إذ عناوين الحقول ثابتة غالباً عبر الأمثلة
        ; لتجنب التعقيد الكامل، نستخدم قيمة PNG المعروفة غالباً من الأنظمة
        ; CLSID PNG القياسي
        ; {557CF406-1A04-11D3-9A73-0000F81EF32E}
        ; نكتب الـ GUID مباشرة إذا كان mimeType = "image/png"
        if (mimeType = "image/png") {
            ; اكتب الـ GUID في clsidBuf
            ; GUID = 0x557CF406,0x1A04,0x11D3,{0x9A,0x73,0x00,0x00,0xF8,0x1E,0xF3,0x2E}
            ; مخزن كـ 16 بايت
            NumPut("uint", 0x557CF406, clsidBuf, 0)
            NumPut("ushort", 0x1A04, clsidBuf, 4)
            NumPut("ushort", 0x11D3, clsidBuf, 6)
            NumPut("uchar", 0x9A, clsidBuf, 8)
            NumPut("uchar", 0x73, clsidBuf, 9)
            NumPut("uchar", 0x00, clsidBuf, 10)
            NumPut("uchar", 0x00, clsidBuf, 11)
            NumPut("uchar", 0xF8, clsidBuf, 12)
            NumPut("uchar", 0x1E, clsidBuf, 13)
            NumPut("uchar", 0xF3, clsidBuf, 14)
            NumPut("uchar", 0x2E, clsidBuf, 15)
            return
        }
    }
}

; ————— Telegram (نصي) —————
SendTelegramText(text) {
    token := Config("TELEGRAM_BOT_TOKEN")
    chatId := Config("TELEGRAM_CHAT_ID")
    if (token = "" || chatId = "")
        return
    url := "https://api.telegram.org/bot" token "/sendMessage"
    body := "chat_id=" chatId "&text=" UrlEncode(text)
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.Open("POST", url, false)
    req.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
    try req.Send(body)
}

UrlEncode(str) {
    out := ""
    for c in StrSplit(str) {
        code := Ord(c)
        if (code>=0x30 && code<=0x39) || (code>=0x41 && code<=0x5A) || (code>=0x61 && code<=0x7A) || c in "-._~" {
            out .= c
        } else if (c = " ") {
            out .= "+"
        } else {
            out .= "%" Format("{:02X}", code)
        }
    }
    return out
}

Log(msg) {
    global logFile
    now := FormatTime(A_Now, "yyyyMMddHHmmss")
    FileAppend("[" now "] " msg "`r`n", logFile, "UTF-8")
}

; إضافة إعدادات Front Line في خريطة الإعدادات
config["FRONTLINE_TITLE"] := "Front Line"
config["FRONTLINE_EXE"] := ""               ; ضع المسار التنفيذي إن رغبت بإعادة التشغيل التلقائي
config["FRONTLINE_CHECK_INTERVAL"] := 5000    ; كل 5 ثوانٍ تحقق من النافذة
config["FRONTLINE_RESTART_ON_HANG"] := true   ; أعد التشغيل إن كانت النافذة لا تستجيب

FrontLineGuardTimer() {
    if !ShouldRun()
        return
    title := Config("FRONTLINE_TITLE")
    if (title = "")
        return
    hwnd := WinExist(title)
    if !hwnd {
        Log("[FL] نافذة Front Line غير موجودة - محاولة تشغيل")
        exe := Config("FRONTLINE_EXE")
        if (exe != "" && FileExist(exe)) {
            Run(exe)
            WinWait(title, , 10)
            if WinExist(title) {
                Log("[FL] تم فتح Front Line")
                SendTelegramText("[FL] تم فتح Front Line")
            } else {
                Log("[FL] فشل فتح Front Line")
            }
        } else {
            Log("[FL] لا يوجد مسار للتشغيل - اضبط FRONTLINE_EXE إن رغبت")
        }
        return
    }
    ; تحقق من التعطل
    try {
        hung := DllCall("IsHungAppWindow", "ptr", hwnd, "int")
    } catch {
        hung := 0
    }
    if (hung && Config("FRONTLINE_RESTART_ON_HANG")) {
        Log("[FL] النافذة لا تستجيب - إعادة التشغيل")
        WinClose("ahk_id " hwnd)
        Sleep(800)
        exe := Config("FRONTLINE_EXE")
        if (exe != "" && FileExist(exe)) {
            Run(exe)
            WinWait(title, , 10)
            if WinExist(title) {
                Log("[FL] أعيد فتح Front Line")
                SendTelegramText("[FL] أعيد فتح Front Line")
            }
        }
    }
    ; تأكيد إظهار النافذة (اختياري)
    try WinActivate("ahk_id " hwnd)
}
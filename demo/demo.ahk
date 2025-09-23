; ============================================================
;                      Demo - Ultra-Light Watcher
;                Single File Version (v1.2 - Corrected)
; ============================================================
; هذا السكريبت مصمم ليكون خفيفاً وموثوقاً، ويعتمد على مراقبة
; لون بكسل محدد بدلاً من البحث المكلف عن الصور.
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================
; 1. الإعدادات الثابتة (عدّل هذه القيم لتناسب جهازك)
; ============================================================
global SETTINGS := Map(
    ; --- إعدادات أساسية ---
    "FrontlineWinTitle", "Front Line",

    ; --- مراقبة البكسل (أهم جزء) ---
    "TargetPixelX", 949,
    "TargetPixelY", 542,
    "TargetPixelColor", 0xE9F7FF, ; اللون بصيغة BGR كما يظهر في WinSpy

    ; --- إحداثيات النقرات "العمياء" ---
    "RefreshX", 114, "RefreshY", 73,
    "StayOnlineAreaX1", 1155, "StayOnlineAreaY1", 655, "StayOnlineAreaX2", 1300, "StayOnlineAreaY2", 707,
    "FixStep1X", 140, "FixStep1Y", 994,
    "FixStep2X", 156, "FixStep2Y", 845,
    "FixStep3X", 328, "FixStep3Y", 323,

    ; --- إعدادات Telegram (مهم جداً) ---
    "TelegramBotToken", "8328100113:AAEEtm8w7Em7eqSVSjq8yiG5nPu7JNBz9Nk",
    "TelegramChatId", "5670001305",

    ; --- التوقيتات (بالمللي ثانية) ---
    "UserIdleThreshold", 120000,      ; 2 دقيقة: مدة الخمول (كيبورد فقط) لبدء الإجراءات
    "RefreshInterval", 300000,         ; 5 دقائق: الفاصل بين كل عملية Refresh
    "StayOnlineInterval", 120000,      ; 2 دقيقة: الفاصل بين كل نقرة على Stay Online
    "PeriodicFixInterval", 600000,     ; 10 دقائق: الفاصل بين كل تنفيذ لخطوات الإصلاح
    "TelegramReportInterval", 600000,  ; 10 دقائق: الفاصل بين كل تقرير لـ Telegram
    "PixelCheckInterval", 1000         ; 1 ثانية: سرعة مراقبة البكسل
)

; ============================================================
; 2. متغيرات الحالة العامة (لا تعدل هذه)
; ============================================================
global STATE := Map(
    "isAlarmPlaying", false,
    "frontlineWinId", 0,
    "lastAction", "None",
    "lastActionTime", "",
    "isUserIdle", false
)

; ============================================================
; 3. نقطة البداية والتهيئة
; ============================================================
Initialize()

Initialize() {
    ; ضبط إعدادات AHK الأساسية
    CoordMode "Pixel", "Screen"
    CoordMode "Mouse", "Screen"
    SetDefaultMouseSpeed 0

    ; إرسال إشعار بدء التشغيل
    SendTelegram("✅ **Script Started**`n`nDemo Watcher is now running at " . FormatTime(A_Now, "HH:mm:ss dd-MM-yyyy"))

    ; إعداد مؤقت للبحث عن نافذة Frontline
    SetTimer(FindFrontlineWindow, 1000)

    ; إعداد روتين الخروج الآمن
    OnExit(SafeExit)
}

FindFrontlineWindow() {
    ; محاولة العثور على النافذة
    winId := WinExist(SETTINGS["FrontlineWinTitle"])
    if (winId) {
        ; تم العثور على النافذة
        if (STATE["frontlineWinId"] = 0) {
            ; هذه هي المرة الأولى التي نجد فيها النافذة
            STATE["frontlineWinId"] := winId
            SendTelegram("🟢 **Front Line Window Found**`n`nMonitoring has now started.")
            
            ; تفعيل جميع المؤقتات الأخرى الآن
            SetTimer(MonitorTargetPixel, SETTINGS["PixelCheckInterval"])
            SetTimer(CheckIdleAndAct, 1000) ; مؤقت للتحقق من الخمول واتخاذ الإجراءات
            SetTimer(SendPeriodicReport, SETTINGS["TelegramReportInterval"])
        }
    } else {
        ; لم يتم العثور على النافذة
        if (STATE["frontlineWinId"] != 0) {
            ; النافذة كانت موجودة واختفت
            SendTelegram("🔴 **Front Line Window Lost**`n`nMonitoring paused. Will attempt to relaunch.")
            STATE["frontlineWinId"] := 0
            ; إيقاف المؤقتات الرئيسية
            SetTimer(MonitorTargetPixel, 0)
            SetTimer(CheckIdleAndAct, 0)
            SetTimer(SendPeriodicReport, 0)
        }
        ; محاولة إعادة تشغيل التطبيق
        TryLaunchFrontline()
    }
}

TryLaunchFrontline() {
    ; مسارات محتملة للاختصار
    shortcutPath1 := A_Desktop . "\" . "Front Line" . ".lnk"
    shortcutPath2 := A_DesktopCommon . "\" . "Front Line" . ".lnk"

    if (FileExist(shortcutPath1)) {
        Run(shortcutPath1)
    } else if (FileExist(shortcutPath2)) {
        Run(shortcutPath2)
    }
}

; ============================================================
; 4. المنطق الرئيسي والمؤقتات
; ============================================================

; مؤقت واحد لإدارة جميع الإجراءات المعتمدة على الخمول
CheckIdleAndAct() {
    static lastRefresh := A_TickCount
    static lastStayOnline := A_TickCount
    static lastPeriodicFix := A_TickCount

    ; التحقق من خمول المستخدم (كيبورد فقط)
    STATE["isUserIdle"] := (A_TimeIdleKeyboard > SETTINGS["UserIdleThreshold"])

    if (!STATE["isUserIdle"]) {
        ; إذا عاد المستخدم للنشاط، أعد ضبط المؤقتات
        lastRefresh := A_TickCount
        lastStayOnline := A_TickCount
        lastPeriodicFix := A_TickCount
        return
    }

    ; --- تنفيذ الإجراءات فقط في حالة الخمول ---

    ; 1. نقرة Stay Online
    if (A_TickCount - lastStayOnline > SETTINGS["StayOnlineInterval"]) {
        PerformStayOnlineClick()
        lastStayOnline := A_TickCount
    }

    ; 2. نقرة Refresh
    if (A_TickCount - lastRefresh > SETTINGS["RefreshInterval"]) {
        PerformRefresh()
        lastRefresh := A_TickCount
    }

    ; 3. خطوات الإصلاح الدورية
    if (A_TickCount - lastPeriodicFix > SETTINGS["PeriodicFixInterval"]) {
        PerformPeriodicFix()
        lastPeriodicFix := A_TickCount
    }
}

MonitorTargetPixel() {
    if (STATE["isAlarmPlaying"])
        return ; لا تفعل شيئاً إذا كان المنبه يعمل بالفعل

    currentColor := PixelGetColor(SETTINGS["TargetPixelX"], SETTINGS["TargetPixelY"])

    if (currentColor != SETTINGS["TargetPixelColor"]) {
        ; اللون تغير، انتظر وتحقق مرة أخرى
        Sleep(3000)

        ; إجراء وقائي: انقر على مكان Stay Online
        PerformStayOnlineClick()
        Sleep(500) ; انتظر قليلاً بعد النقرة

        ; تحقق مرة أخيرة
        finalColor := PixelGetColor(SETTINGS["TargetPixelX"], SETTINGS["TargetPixelY"])
        if (finalColor != SETTINGS["TargetPixelColor"]) {
            ; اللون لا يزال خاطئاً، شغل المنبه
            STATE["isAlarmPlaying"] := true
            SetTimer(AlarmBeep, 500) ; تشغيل صوت التنبيه كل نصف ثانية
            SendTelegram("🚨 **ALARM: Target Pixel Changed!**`n`nPixel color at (" . SETTINGS["TargetPixelX"] . "," . SETTINGS["TargetPixelY"] . ") is incorrect.`nManual intervention may be required.")
            STATE["lastAction"] := "ALARM TRIGGERED"
            STATE["lastActionTime"] := FormatTime(A_Now, "HH:mm:ss")
        }
    }
}

; ============================================================
; 5. دوال الإجراءات
; ============================================================

PerformStayOnlineClick() {
    ; نقرة عشوائية داخل منطقة Stay Online (باستخدام الصيغة الصحيحة لـ Random في v2)
    local randX := Random(SETTINGS["StayOnlineAreaX1"], SETTINGS["StayOnlineAreaX2"])
    local randY := Random(SETTINGS["StayOnlineAreaY1"], SETTINGS["StayOnlineAreaY2"])
    
    Click(randX, randY)
    STATE["lastAction"] := "Stay Online Click"
    STATE["lastActionTime"] := FormatTime(A_Now, "HH:mm:ss")
}

PerformRefresh() {
    Click(SETTINGS["RefreshX"], SETTINGS["RefreshY"])
    STATE["lastAction"] := "Refresh Click"
    STATE["lastActionTime"] := FormatTime(A_Now, "HH:mm:ss")
}

PerformPeriodicFix() {
    Click(SETTINGS["FixStep1X"], SETTINGS["FixStep1Y"])
    Sleep(1500)
    Click(SETTINGS["FixStep2X"], SETTINGS["FixStep2Y"])
    Sleep(1500)
    Click(SETTINGS["FixStep3X"], SETTINGS["FixStep3Y"])
    STATE["lastAction"] := "Periodic 3-Step Fix"
    STATE["lastActionTime"] := FormatTime(A_Now, "HH:mm:ss")
    SendTelegram("🔧 **Periodic Fix Executed**`n`nThe 3-step online fix was performed as a precaution.")
}

AlarmBeep() {
    SoundBeep(800, 400) ; تردد 800 هرتز لمدة 400 مللي ثانية
}

; ============================================================
; 6. التقارير والتواصل عبر Telegram
; ============================================================

SendPeriodicReport() {
    ; جمع معلومات البطارية
    batteryPercent := "N/A"
    chargerStatus := "Unknown"
    try {
        powerStatus := Buffer(12, 0)
        if DllCall("GetSystemPowerStatus", "Ptr", powerStatus) {
            batteryPercent := NumGet(powerStatus, 2, "UChar") . "%"
            acLineStatus := NumGet(powerStatus, 1, "UChar")
            chargerStatus := (acLineStatus = 1) ? "Plugged In" : "On Battery"
        }
    }

    ; تحديد الحالة العامة
    currentStatus := "Monitoring"
    if (STATE["isAlarmPlaying"]) {
        currentStatus := "ALARM ACTIVE"
    } else if (STATE["isUserIdle"]) {
        currentStatus := "Monitoring (User Idle)"
    } else {
        currentStatus := "Monitoring (User Active)"
    }

    ; بناء نص الرسالة
    report := "📊 **Periodic Status Report**`n`n"
    report .= "🔹 **Status:** " . currentStatus . "`n"
    report .= "🔋 **Battery:** " . batteryPercent . " (" . chargerStatus . ")`n"
    report .= "⏰ **Last Action:** " . STATE["lastAction"] . " at " . STATE["lastActionTime"] . "`n"
    report .= "🕒 **Report Time:** " . FormatTime(A_Now, "HH:mm:ss")

    SendTelegram(report)
}

SendTelegram(message) {
    if (SETTINGS["TelegramBotToken"] = "YOUR_TOKEN" || SETTINGS["TelegramChatId"] = "YOUR_CHAT_ID")
        return ; لا ترسل إذا لم يتم تكوين الإعدادات

    ; ترميز الرسالة لإرسالها في URL
    encodedMessage := UriEncode(message)
    
    url := "https://api.telegram.org/bot" . SETTINGS["TelegramBotToken"] . "/sendMessage"
    postBody := "chat_id=" . SETTINGS["TelegramChatId"] . "&text=" . encodedMessage . "&parse_mode=Markdown"

    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1" )
        req.Open("POST", url, true) ; true = async
        req.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        req.SetTimeouts(5000, 5000, 5000, 5000) ; 5 ثواني مهلة
        req.Send(postBody)
    } catch {
        ; فشل في الإرسال، يمكن إضافة تسجيل خطأ هنا إذا أردت
    }
}

; دالة مساعدة لترميز URL (نسخة مصححة)
UriEncode(str, encoding := "UTF-8") {
    static chars := "0123456789ABCDEF"
    if (str = "") {
        return ""
    }
    
    bytes := StrPut(str, encoding) - 1
    buf := Buffer(bytes)
    StrPut(str, buf, encoding)
    
    result := ""
    Loop bytes {
        c := NumGet(buf, A_Index - 1, "UChar")
        if ((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c = 45 || c = 46 || c = 95 || c = 126) {
            result .= Chr(c)
        } else {
            result .= "%" . SubStr(chars, (c >> 4) + 1, 1) . SubStr(chars, (c & 15) + 1, 1)
        }
    }
    return result
}

; ============================================================
; 7. الاختصارات والخروج الآمن
; ============================================================

; CapsLock أو أي ضغطة كيبورد توقف المنبه
#HotIf STATE["isAlarmPlaying"]
~*::
{
    STATE["isAlarmPlaying"] := false
    SetTimer(AlarmBeep, 0) ; إيقاف المنبه الصوتي
    SendTelegram("✅ **Alarm Stopped**`n`nUser activity detected. Alarm has been silenced.")
    STATE["lastAction"] := "Alarm Stopped by User"
    STATE["lastActionTime"] := FormatTime(A_Now, "HH:mm:ss")
}
#HotIf

; اختصار الخروج الآمن
F12::SafeExit()

SafeExit(*) {
    SendTelegram("⛔ **Script Shutting Down**`n`nFinal report will be sent shortly.")
    Sleep(1000) ; انتظر ثانية لضمان إرسال الرسالة
    SendPeriodicReport() ; إرسال تقرير أخير
    Sleep(1000)
    ExitApp()
}

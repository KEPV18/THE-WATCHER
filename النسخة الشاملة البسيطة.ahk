#NoEnv
#SingleInstance Force
#Persistent
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%
CoordMode, Pixel, Screen
CoordMode, Mouse, Screen
SetTitleMatchMode, 2

; النسخة الشاملة البسيطة: مراقبة الحالة والتارجت ورد مع إنذار وتصحيح بسيط بدون انتظار مبدئي

; إعدادات عامة
global LOG_FILE := A_ScriptDir "\log_simple.txt"
global SCREENSHOT_DIR := A_ScriptDir "\logs\simple_screenshots"

; إحداثيات الأزرار (عدّلها حسب شاشتك)
; مكان زر Stay Online
global STAY_ONLINE_X := 114
global STAY_ONLINE_Y := 73
; مكان زر Refresh
global REFRESH_X := 114
global REFRESH_Y := 73
; نقطة تفحص الحالة (لون/صورة)
global STATUS_X := 114
global STATUS_Y := 73
; لون الحالة أوفلاين (عدّله حسب الواجهة)
global OFFLINE_COLOR := 0x000000  ; لون افتراضي، غيّره حسب الحاجة

; صور الحالة والتارجت (إن وجدت)
global ONLINE_IMAGES := [A_ScriptDir "\profiles\status_online.png", A_ScriptDir "\profiles\status_coaching.png"]
global OFFLINE_IMAGES := [A_ScriptDir "\profiles\status_offline.png"]
global TARGET_IMAGE := A_ScriptDir "\profiles\target_word.png"

; منطقة البحث عن التارجت ورد (عدّل حسب مكانه)
global TARGET_X1 := 0
global TARGET_Y1 := 800
global TARGET_X2 := A_ScreenWidth
global TARGET_Y2 := A_ScreenHeight

; حالات الإنذار
global isNetAlarmPlaying := false
global isTargetAlarmPlaying := false
global isAlarmPlaying := false
global muteAlarm := false
global targetRetryScheduled := false

; مؤقتات
SetTimer, StayOnlineClickTimer, 90000       ; اضغط ستاي أونلاين + ريفريش كل دقيقة ونصف
SetTimer, StatusCheckTimer, 1000            ; راقب الحالة كل ثانية
SetTimer, TargetMonitorTimer, 1000          ; راقب التارجت ورد كل ثانية
SetTimer, AlarmBeep, Off                    ; إيقاف إنذار الصوت مبدئياً

Log("[START] النسخة الشاملة البسيطة بدأت فوراً بدون انتظار")
FileCreateDir, %SCREENSHOT_DIR%

return

;==================== الوظائف ====================

StatusCheckTimer:
{
    if (DetectOffline()) {
        if (!isNetAlarmPlaying) {
            isNetAlarmPlaying := true
            UpdateAlarmState()
            Log("[OFFLINE] تم اكتشاف أوفلاين - تشغيل الإنذار ومحاولة الإرجاع أونلاين")
            SaveScreenshot("offline")
        }
        EnsureOnlineStatus()
    } else {
        if (isNetAlarmPlaying) {
            isNetAlarmPlaying := false
            UpdateAlarmState()
            Log("[ONLINE] رجعنا أونلاين - إيقاف إنذار الشبكة")
            SaveScreenshot("online")
        }
    }
}
return

StayOnlineClickTimer:
{
    Log("[ACTION] ضغط زر Stay Online + Refresh دوري")
    Click, %STAY_ONLINE_X%, %STAY_ONLINE_Y%
    Sleep, 300
    Click, %REFRESH_X%, %REFRESH_Y%
}
return

TargetMonitorTimer:
{
    if (CheckImage(TARGET_IMAGE, TARGET_X1, TARGET_Y1, TARGET_X2, TARGET_Y2) || (TARGET_IMAGE2 != "" && CheckImage(TARGET_IMAGE2, TARGET_X1, TARGET_Y1, TARGET_X2, TARGET_Y2))) {
        if (isTargetAlarmPlaying) {
            isTargetAlarmPlaying := false
            UpdateAlarmState()
            Log("[TARGET] التارجت ورد موجود - إيقاف إنذار التارجت")
        }
    } else {
        if (!targetRetryScheduled) {
            targetRetryScheduled := true
            SetTimer, TargetRetry, -3000  ; إعادة المحاولة بعد 3 ثواني
            Log("[TARGET] لم يتم العثور على التارجت - سيعاد الفحص بعد 3 ثواني")
        }
    }
}
return

TargetRetry:
{
    targetRetryScheduled := false
    if (CheckImage(TARGET_IMAGE, TARGET_X1, TARGET_Y1, TARGET_X2, TARGET_Y2)) {
        Log("[TARGET] التارجت ظهر في إعادة المحاولة")
        if (isTargetAlarmPlaying) {
            isTargetAlarmPlaying := false
            UpdateAlarmState()
            Log("[TARGET] إيقاف إنذار التارجت بعد ظهوره")
        }
    } else {
        Log("[TARGET] لم يظهر التارجت بعد إعادة المحاولة - التقاط صورة وتشغيل الإنذار")
        SaveScreenshot("target_missing")
        if (!isTargetAlarmPlaying) {
            isTargetAlarmPlaying := true
            UpdateAlarmState()
        }
    }
}
return

EnsureOnlineStatus() {
    ; محاولة إرجاع الحالة أونلاين: اضغط ستاي أونلاين ثم ريفريش
    Click, %STAY_ONLINE_X%, %STAY_ONLINE_Y%
    Sleep, 300
    Click, %REFRESH_X%, %REFRESH_Y%
    Sleep, %POST_REFRESH_DELAY%
}

DetectOffline() {
    ; تحقق أولاً عبر صور الأوفلاين إن وجدت
    for index, imgPath in OFFLINE_IMAGES {
        if (FileExist(imgPath)) {
            if (CheckImage(imgPath, 0, 0, A_ScreenWidth, A_ScreenHeight))
                return true
        }
    }
    ; بديل: تحقق عبر لون بكسل عند نقطة الحالة
    color := PixelGetColorAt(STATUS_X, STATUS_Y)
    if (color = OFFLINE_COLOR)
        return true
    ; يمكن أيضاً محاولة التأكد من صور الأونلاين
    for index, imgPath in ONLINE_IMAGES {
        if (FileExist(imgPath)) {
            if (CheckImage(imgPath, 0, 0, A_ScreenWidth, A_ScreenHeight))
                return false
        }
    }
    ; الافتراضي: اعتبرها أونلاين إذا لم تظهر مؤشرات الأوفلاين
    return false
}

CheckImage(imgPath, x1, y1, x2, y2) {
    if (!FileExist(imgPath))
        return false
    local fx, fy
    ImageSearch, fx, fy, %x1%, %y1%, %x2%, %y2%, *%IMG_TOL% %imgPath%
    return (ErrorLevel = 0)
}

PixelGetColorAt(x, y) {
    PixelGetColor, c, %x%, %y%, RGB
    return c
}

UpdateAlarmState() {
    static prev := false
    isAlarmPlaying := (isNetAlarmPlaying || isTargetAlarmPlaying)
    if (isAlarmPlaying && !prev) {
        SetTimer, AlarmBeep, 1500
        Log("[ALARM] تشغيل إنذار الصوت")
    } else if (!isAlarmPlaying && prev) {
        SetTimer, AlarmBeep, Off
        Log("[ALARM] إيقاف إنذار الصوت")
    }
    prev := isAlarmPlaying
}

AlarmBeep:
{
    if (isAlarmPlaying && !muteAlarm) {
        SoundBeep, 900, 250
    }
}
return

SaveScreenshot(prefix) {
    ; يلتقط صورة للشاشة كاملة باستخدام MSPaint
    FileCreateDir, %SCREENSHOT_DIR%
    FormatTime, ts, , yyyyMMdd_HHmmss
    filePath := SCREENSHOT_DIR "\" prefix "_" ts ".png"

    ; انسخ الشاشة إلى الحافظة
    Send, {PrintScreen}
    ClipWait, 2
    if (ErrorLevel) {
        Log("[SHOT] فشل نسخ الشاشة إلى الحافظة")
        return
    }
    ; افتح الرسام وألصق واحفظ
    Run, mspaint.exe
    WinWaitActive, ahk_exe mspaint.exe, , 3
    if (ErrorLevel) {
        Log("[SHOT] لم يفتح برنامج الرسام")
        return
    }
    Send, ^v
    Sleep, 300
    Send, ^s
    WinWaitActive, Save As, , 3
    if (!ErrorLevel) {
        ; أدخل المسار واحفظ
        Send, %filePath%
        Sleep, 200
        Send, {Enter}
        Sleep, 500
    }
    ; إغلاق الرسام
    WinClose, ahk_exe mspaint.exe
    Log("[SHOT] تم حفظ لقطة شاشة: " filePath)
}

Log(msg) {
    FormatTime, now, , yyyyMMddHHmmss
    FileAppend, % "[" now "] " msg "`r`n", %LOG_FILE%
}

LoadSettings() {
    global STAY_ONLINE_X, STAY_ONLINE_Y, REFRESH_X, REFRESH_Y, STATUS_X, STATUS_Y
    global TARGET_X1, TARGET_Y1, TARGET_X2, TARGET_Y2
    global STAY_ONLINE_INTERVAL, STATUS_CHECK_INTERVAL, MAIN_LOOP_INTERVAL, POST_REFRESH_DELAY, IMG_TOL
    global ONLINE_IMAGES, OFFLINE_IMAGES, TARGET_IMAGE, TARGET_IMAGE2

    ini := A_ScriptDir "\settings.ini"

    ; منطقة "Stay Online" -> احسب نقطة النقر في المنتصف
    IniRead, soX1, %ini%, Coordinates, StayOnlineAreaTopLeftX
    IniRead, soY1, %ini%, Coordinates, StayOnlineAreaTopLeftY
    IniRead, soX2, %ini%, Coordinates, StayOnlineAreaBottomRightX
    IniRead, soY2, %ini%, Coordinates, StayOnlineAreaBottomRightY
    if (soX1 != "ERROR" && soY1 != "ERROR" && soX2 != "ERROR" && soY2 != "ERROR") {
        STAY_ONLINE_X := Floor((soX1 + soX2) / 2)
        STAY_ONLINE_Y := Floor((soY1 + soY2) / 2)
    }

    ; زر التحديث
    IniRead, REFRESH_X, %ini%, Coordinates, RefreshX, %REFRESH_X%
    IniRead, REFRESH_Y, %ini%, Coordinates, RefreshY, %REFRESH_Y%

    ; منطقة الحالة StatusArea -> احسب بكسل المنتصف للفحص
    IniRead, stX1, %ini%, Coordinates, StatusAreaTopLeftX
    IniRead, stY1, %ini%, Coordinates, StatusAreaTopLeftY
    IniRead, stX2, %ini%, Coordinates, StatusAreaBottomRightX
    IniRead, stY2, %ini%, Coordinates, StatusAreaBottomRightY
    if (stX1 != "ERROR" && stY1 != "ERROR" && stX2 != "ERROR" && stY2 != "ERROR") {
        STATUS_X := Floor((stX1 + stX2) / 2)
        STATUS_Y := Floor((stY1 + stY2) / 2)
    }

    ; منطقة التارجت
    IniRead, TARGET_X1, %ini%, Coordinates, TargetAreaTopLeftX, %TARGET_X1%
    IniRead, TARGET_Y1, %ini%, Coordinates, TargetAreaTopLeftY, %TARGET_Y1%
    IniRead, TARGET_X2, %ini%, Coordinates, TargetAreaBottomRightX, %TARGET_X2%
    IniRead, TARGET_Y2, %ini%, Coordinates, TargetAreaBottomRightY, %TARGET_Y2%

    ; الأزمنة
    IniRead, STAY_ONLINE_INTERVAL, %ini%, Timings, StayOnlineInterval, %STAY_ONLINE_INTERVAL%
    IniRead, STATUS_CHECK_INTERVAL, %ini%, Timings, StatusCheckInterval, %STATUS_CHECK_INTERVAL%
    IniRead, MAIN_LOOP_INTERVAL, %ini%, Timings, MainLoopInterval, %MAIN_LOOP_INTERVAL%
    IniRead, POST_REFRESH_DELAY, %ini%, Timings, PostRefreshDelayMs, %POST_REFRESH_DELAY%

    ; تحمل البحث بالصورة
    IniRead, IMG_TOL, %ini%, Search, Tolerance, %IMG_TOL%

    ; الصور
    profilesDir := A_ScriptDir "\profiles\"
    ONLINE_IMAGES := []
    OFFLINE_IMAGES := []
    TARGET_IMAGE := ""
    TARGET_IMAGE2 := ""

    IniRead, OnlineImageName, %ini%, Citrix, OnlineImageName
    IniRead, OnlineImageName2, %ini%, Citrix, OnlineImageName2
    IniRead, CoachingImageName, %ini%, Citrix, CoachingImageName
    IniRead, CoachingImageName2, %ini%, Citrix, CoachingImageName2
    IniRead, OfflineImageName, %ini%, Citrix, OfflineImageName

    IniRead, TargetImageName, %ini%, WordMonitor, TargetImageName
    IniRead, TargetImageName2, %ini%, WordMonitor, TargetImageName2

    if (OnlineImageName != "")
        ONLINE_IMAGES.Push(profilesDir OnlineImageName)
    if (OnlineImageName2 != "")
        ONLINE_IMAGES.Push(profilesDir OnlineImageName2)
    if (CoachingImageName != "")
        ONLINE_IMAGES.Push(profilesDir CoachingImageName)
    if (CoachingImageName2 != "")
        ONLINE_IMAGES.Push(profilesDir CoachingImageName2)

    if (OfflineImageName != "")
        OFFLINE_IMAGES.Push(profilesDir OfflineImageName)

    if (TargetImageName != "")
        TARGET_IMAGE := profilesDir TargetImageName
    if (TargetImageName2 != "")
        TARGET_IMAGE2 := profilesDir TargetImageName2
}
; أعلى الملف - مقطع التهيئة التلقائية
#Requires AutoHotkey v2.0
#Include lib\01_CoreSettings.ahk
#Include lib\02_Logging.ahk
#Include lib\07_GDIPlus.ahk
#Include lib\04_Helpers.ahk
#Include lib\03_InitAndSettings.ahk

Gdip_Startup()
OnExit("Gdip_Shutdown")
CoordMode("Mouse", "Screen")
SETTINGS := Map()
global STATE := Map()

; تحميل الإعدادات (بدون إسناد لقيمة راجعة)
LoadSettings()

; دالة تتبع النقرات مع تأخير وتسجيل
DebugEnsureOnlineStatus() {
    global SETTINGS
    
    ; التقاط الحالة قبل محاولة الإصلاح
    initialStatus := GetCurrentStatus()
    Info("[DEBUG] Current status before fix: " . initialStatus)
    
    ; تنفيذ خطوات الإصلاح مع تأخير وتتبع بصري
    Info("[DEBUG] Step 1: Clicking at (" . SETTINGS["FixStep1X"] . ", " . SETTINGS["FixStep1Y"] . ")")
    ShowClickMarker(SETTINGS["FixStep1X"], SETTINGS["FixStep1Y"])
    Click(SETTINGS["FixStep1X"], SETTINGS["FixStep1Y"])
    Sleep(3000)
    
    Info("[DEBUG] Step 2: Clicking at (" . SETTINGS["FixStep2X"] . ", " . SETTINGS["FixStep2Y"] . ")")
    ShowClickMarker(SETTINGS["FixStep2X"], SETTINGS["FixStep2Y"])
    Click(SETTINGS["FixStep2X"], SETTINGS["FixStep2Y"])
    Sleep(3000)
    
    Info("[DEBUG] Step 3: Clicking at (" . SETTINGS["FixStep3X"] . ", " . SETTINGS["FixStep3Y"] . ")")
    ShowClickMarker(SETTINGS["FixStep3X"], SETTINGS["FixStep3Y"])
    Click(SETTINGS["FixStep3X"], SETTINGS["FixStep3Y"])
    Sleep(3000)
    
    ; التقاط الحالة بعد محاولة الإصلاح
    finalStatus := GetCurrentStatus()
    Info("[DEBUG] Status after fix: " . finalStatus)
    
    return Map(
        "beforeStatus", initialStatus,
        "afterStatus", finalStatus
    )
}

; دالة إظهار علامة النقر
ShowClickMarker(x, y) {
    Gui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    Gui.BackColor := "Red"
    size := 20
    Gui.Show(Format("x{} y{} w{} h{}", x - size/2, y - size/2, size, size))
    SetTimer(ObjBindMethod(Gui, "Destroy"), -1000)
}

; دالة التحقق من الحالة الحالية (تدعم صور Online المتعددة)
GetCurrentStatus() {
    global SETTINGS
    statusArea := Map(
        "x1", SETTINGS["StatusAreaTopLeftX"],
        "y1", SETTINGS["StatusAreaTopLeftY"],
        "x2", SETTINGS["StatusAreaBottomRightX"],
        "y2", SETTINGS["StatusAreaBottomRightY"]
    )

    local foundX, foundY

    ; لو عندنا قائمة صور Online متعددة، افحصها
    if (SETTINGS.Has("OnlineImageList") && SETTINGS["OnlineImageList"].Length > 0) {
        for imgPath in SETTINGS["OnlineImageList"] {
            if (ReliableImageSearch(&foundX, &foundY, imgPath, statusArea))
                return "Online"
        }
    } else {
        ; رجوع للصورة الأساسية كاحتياطي
        if (ReliableImageSearch(&foundX, &foundY, SETTINGS["OnlineImage"], statusArea))
            return "Online"
    }

    if (ReliableImageSearch(&foundX, &foundY, SETTINGS["OfflineImage"], statusArea))
        return "Offline"

    return "Unknown"
}

; تشغيل الاختبار
MsgBox("سيتم بدء اختبار عملية الإصلاح. تأكد من أن النافذة مفتوحة وظاهرة.")
result := DebugEnsureOnlineStatus()
MsgBox("نتيجة الاختبار:`n" .
       "الحالة قبل: " . result["beforeStatus"] . "`n" .
       "الحالة بعد: " . result["afterStatus"])
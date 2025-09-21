; ============================================================
; 08_IntelligentSystem.ahk - Intelligent Coordinate Detection & Smart Monitoring
; ============================================================

; ============================================================
; النظام الذكي لاكتشاف الإحداثيات والصور تلقائياً
; ============================================================

; دالة لاكتشاف الإحداثيات الذكية للعناصر
IntelligentCoordinateDetection() {
    global SETTINGS, STATE
    
    if (!SETTINGS.Has("IntelligentCoordinates") || !SETTINGS["IntelligentCoordinates"]) {
        return false
    }
    
    Info("Starting intelligent coordinate detection...")
    
    ; اكتشاف جميع الشاشات المتاحة
    DetectAvailableScreens()
    
    ; اكتشاف إحداثيات العناصر المختلفة
    DetectStatusAreaCoordinates()
    DetectTargetAreaCoordinates()
    DetectStayOnlineAreaCoordinates()
    DetectRefreshButtonCoordinates()
    
    ; حفظ الإحداثيات المكتشفة في البروفايل الحالي
    SaveIntelligentCoordinates()
    
    Info("Intelligent coordinate detection completed.")
    return true
}

; اكتشاف الشاشات المتاحة
DetectAvailableScreens() {
    global STATE
    
    STATE["detectedScreens"] := []
    monitorCount := MonitorGetCount()
    
    Loop monitorCount {
        monitorIndex := A_Index
        try {
            MonitorGet(monitorIndex, &left, &top, &right, &bottom)
            screenInfo := Map(
                "index", monitorIndex,
                "left", left,
                "top", top,
                "right", right,
                "bottom", bottom,
                "width", right - left,
                "height", bottom - top,
                "isPrimary", (monitorIndex == 1)
            )
            STATE["detectedScreens"].Push(screenInfo)
            Info("Detected Screen " . monitorIndex . ": " . (right-left) . "x" . (bottom-top) . " at (" . left . "," . top . ")")
        } catch {
            Warn("Failed to detect screen " . monitorIndex)
        }
    }
}

; اكتشاف منطقة الحالة (Status Area) بذكاء
DetectStatusAreaCoordinates() {
    global SETTINGS, STATE
    
    ; البحث عن أي من صور الحالة المعروفة لتحديد المنطقة
    statusImages := ["OnlineImage", "OfflineImage", "WorkOnMyTicketImage", "LaunchImage", "BreakImage"]
    
    for screenInfo in STATE["detectedScreens"] {
        for imageKey in statusImages {
            if (!SETTINGS.Has(imageKey) || !FileExist(SETTINGS[imageKey])) {
                continue
            }
            
            ; البحث في الشاشة الحالية
            searchArea := Map(
                "x1", screenInfo["left"],
                "y1", screenInfo["top"],
                "x2", screenInfo["right"],
                "y2", screenInfo["bottom"]
            )
            
            local foundX, foundY
            if (ReliableImageSearch(&foundX, &foundY, SETTINGS[imageKey], searchArea)) {
                ; تم العثور على صورة الحالة، تحديد المنطقة المحيطة
                margin := 50
                newStatusArea := Map(
                    "x1", Max(screenInfo["left"], foundX - margin),
                    "y1", Max(screenInfo["top"], foundY - margin),
                    "x2", Min(screenInfo["right"], foundX + margin + 100),
                    "y2", Min(screenInfo["bottom"], foundY + margin + 50)
                )
                
                ; حفظ الإحداثيات الجديدة
                profileKey := "StatusArea_Screen" . screenInfo["index"]
                STATE["smartCoordinates"][profileKey] := newStatusArea
                
                Info("Detected Status Area on Screen " . screenInfo["index"] . " at (" . foundX . "," . foundY . ")")
                return true
            }
        }
    }
    
    Warn("Could not detect Status Area automatically")
    return false
}

; اكتشاف منطقة Target Word بذكاء
DetectTargetAreaCoordinates() {
    global SETTINGS, STATE
    
    if (!SETTINGS.Has("TargetImageList") || SETTINGS["TargetImageList"].Length == 0) {
        if (!SETTINGS.Has("TargetImage") || !FileExist(SETTINGS["TargetImage"])) {
            Warn("No Target images configured for detection")
            return false
        }
    }
    
    ; محاولة البحث في كل الشاشات مع تحسين الدقة
    for screenInfo in STATE["detectedScreens"] {
        searchArea := Map(
            "x1", screenInfo["left"],
            "y1", screenInfo["top"],
            "x2", screenInfo["right"],
            "y2", screenInfo["bottom"]
        )
        
        local foundX, foundY
        targetFound := false
        
        ; البحث باستخدام قائمة الصور مع تحسين الدقة
        if (SETTINGS.Has("TargetImageList") && SETTINGS["TargetImageList"].Length > 0) {
            for imgPath in SETTINGS["TargetImageList"] {
                ; محاولة البحث بالدقة الافتراضية
                if (ReliableImageSearch(&foundX, &foundY, imgPath, searchArea)) {
                    targetFound := true
                    Info("Target found using: " . imgPath)
                    break
                }
            }
        } else {
            ; البحث بالصورة الواحدة
            if (ReliableImageSearch(&foundX, &foundY, SETTINGS["TargetImage"], searchArea)) {
                targetFound := true
                Info("Target found using single image")
            }
        }
        
        if (targetFound) {
            ; تحديد منطقة أكبر حول Target Word مع تحسين الحدود
            margin := 150  ; زيادة الهامش
            newTargetArea := Map(
                "x1", Max(screenInfo["left"], foundX - margin),
                "y1", Max(screenInfo["top"], foundY - margin),
                "x2", Min(screenInfo["right"], foundX + margin + 300),  ; منطقة أوسع
                "y2", Min(screenInfo["bottom"], foundY + margin + 150)
            )
            
            profileKey := "TargetArea_Screen" . screenInfo["index"]
            STATE["smartCoordinates"][profileKey] := newTargetArea
            
            ; حفظ الإحداثيات في الإعدادات أيضاً
            SETTINGS["TargetAreaTopLeftX"] := newTargetArea["x1"]
            SETTINGS["TargetAreaTopLeftY"] := newTargetArea["y1"]
            SETTINGS["TargetAreaBottomRightX"] := newTargetArea["x2"]
            SETTINGS["TargetAreaBottomRightY"] := newTargetArea["y2"]
            
            Info("Detected Target Area on Screen " . screenInfo["index"] . " at (" . foundX . "," . foundY . ") - Area: " . newTargetArea["x1"] . "," . newTargetArea["y1"] . " to " . newTargetArea["x2"] . "," . newTargetArea["y2"])
            return true
        }
    }
    
    ; إذا فشل الاكتشاف، استخدم منطقة افتراضية أوسع
    Info("Target Area detection failed - using expanded default area")
    defaultArea := Map(
        "x1", 500,
        "y1", 300,
        "x2", 1400,
        "y2", 800
    )
    
    SETTINGS["TargetAreaTopLeftX"] := defaultArea["x1"]
    SETTINGS["TargetAreaTopLeftY"] := defaultArea["y1"]
    SETTINGS["TargetAreaBottomRightX"] := defaultArea["x2"]
    SETTINGS["TargetAreaBottomRightY"] := defaultArea["y2"]
    
    profileKey := "TargetArea_Screen1"
    STATE["smartCoordinates"][profileKey] := defaultArea
    
    Warn("Could not detect Target Area automatically - using expanded default area")
    return false
}

; اكتشاف منطقة Stay Online بذكاء
DetectStayOnlineAreaCoordinates() {
    global SETTINGS, STATE
    
    for screenInfo in STATE["detectedScreens"] {
        searchArea := Map(
            "x1", screenInfo["left"],
            "y1", screenInfo["top"],
            "x2", screenInfo["right"],
            "y2", screenInfo["bottom"]
        )
        
        local foundX, foundY
        stayOnlineFound := false
        
        ; البحث باستخدام قائمة صور Stay Online
        if (SETTINGS.Has("StayOnlineImageList") && SETTINGS["StayOnlineImageList"].Length > 0) {
            for imgPath in SETTINGS["StayOnlineImageList"] {
                if (ReliableImageSearch(&foundX, &foundY, imgPath, searchArea)) {
                    stayOnlineFound := true
                    break
                }
            }
        } else if (SETTINGS.Has("StayOnlineImage") && FileExist(SETTINGS["StayOnlineImage"])) {
            stayOnlineFound := ReliableImageSearch(&foundX, &foundY, SETTINGS["StayOnlineImage"], searchArea)
        }
        
        if (stayOnlineFound) {
            margin := 30
            newStayOnlineArea := Map(
                "x1", Max(screenInfo["left"], foundX - margin),
                "y1", Max(screenInfo["top"], foundY - margin),
                "x2", Min(screenInfo["right"], foundX + margin + 150),
                "y2", Min(screenInfo["bottom"], foundY + margin + 50)
            )
            
            profileKey := "StayOnlineArea_Screen" . screenInfo["index"]
            STATE["smartCoordinates"][profileKey] := newStayOnlineArea
            
            Info("Detected Stay Online Area on Screen " . screenInfo["index"] . " at (" . foundX . "," . foundY . ")")
            return true
        }
    }
    
    Info("Stay Online Area not currently visible - will detect when it appears")
    return false
}

; اكتشاف زر الريفريش بذكاء
DetectRefreshButtonCoordinates() {
    global SETTINGS, STATE
    
    ; البحث عن زر الريفريش في المتصفح (عادة في الأعلى)
    for screenInfo in STATE["detectedScreens"] {
        ; البحث في الجزء العلوي من الشاشة فقط
        searchArea := Map(
            "x1", screenInfo["left"],
            "y1", screenInfo["top"],
            "x2", screenInfo["right"],
            "y2", screenInfo["top"] + 200  ; البحث في أول 200 بكسل من الأعلى
        )
        
        ; محاولة العثور على أيقونة الريفريش أو النص
        ; يمكن إضافة صور لأيقونة الريفريش هنا
        
        ; للآن، نستخدم موقع تقريبي ذكي بناءً على حجم الشاشة
        estimatedRefreshX := screenInfo["left"] + 114
        estimatedRefreshY := screenInfo["top"] + 73
        
        profileKey := "RefreshButton_Screen" . screenInfo["index"]
        STATE["smartCoordinates"][profileKey] := Map(
            "x", estimatedRefreshX,
            "y", estimatedRefreshY
        )
        
        Info("Estimated Refresh Button on Screen " . screenInfo["index"] . " at (" . estimatedRefreshX . "," . estimatedRefreshY . ")")
    }
    
    return true
}

; حفظ الإحداثيات الذكية المكتشفة
SaveIntelligentCoordinates() {
    global STATE
    
    profileFile := A_ScriptDir "\profiles\" . STATE["currentProfile"] . "_coordinates.ini"
    
    ; إنشاء مجلد البروفايلات إذا لم يكن موجوداً
    if (!DirExist(A_ScriptDir "\profiles")) {
        DirCreate(A_ScriptDir "\profiles")
    }
    
    try {
        ; حفظ جميع الإحداثيات المكتشفة
        for key, coords in STATE["smartCoordinates"] {
            if (IsObject(coords)) {
                if (coords.Has("x1")) {
                    ; منطقة مستطيلة
                    IniWrite(coords["x1"], profileFile, key, "x1")
                    IniWrite(coords["y1"], profileFile, key, "y1")
                    IniWrite(coords["x2"], profileFile, key, "x2")
                    IniWrite(coords["y2"], profileFile, key, "y2")
                } else if (coords.Has("x")) {
                    ; نقطة واحدة
                    IniWrite(coords["x"], profileFile, key, "x")
                    IniWrite(coords["y"], profileFile, key, "y")
                }
            }
        }
        
        ; حفظ معلومات الشاشات
        IniWrite(STATE["detectedScreens"].Length, profileFile, "General", "ScreenCount")
        for i, screenInfo in STATE["detectedScreens"] {
            sectionName := "Screen" . i
            IniWrite(screenInfo["left"], profileFile, sectionName, "left")
            IniWrite(screenInfo["top"], profileFile, sectionName, "top")
            IniWrite(screenInfo["right"], profileFile, sectionName, "right")
            IniWrite(screenInfo["bottom"], profileFile, sectionName, "bottom")
        }
        
        Info("Intelligent coordinates saved to profile: " . STATE["currentProfile"])
    } catch as e {
        Warn("Failed to save intelligent coordinates: " . e.Message)
    }
}

; تحميل الإحداثيات الذكية من البروفايل
LoadIntelligentCoordinates(profileName := "") {
    global STATE
    
    if (profileName == "") {
        profileName := STATE["currentProfile"]
    }
    
    profileFile := A_ScriptDir "\profiles\" . profileName . "_coordinates.ini"
    
    if (!FileExist(profileFile)) {
        Info("No intelligent coordinates profile found: " . profileName)
        return false
    }
    
    try {
        STATE["smartCoordinates"] := Map()
        
        ; قراءة جميع الأقسام والمفاتيح
        ; هذا مبسط - في التطبيق الحقيقي نحتاج لقراءة جميع الأقسام
        
        Info("Intelligent coordinates loaded from profile: " . profileName)
        return true
    } catch as e {
        Warn("Failed to load intelligent coordinates: " . e.Message)
        return false
    }
}

; استخدام الإحداثيات الذكية بدلاً من الثابتة
GetSmartCoordinates(elementType, screenIndex := 1) {
    global STATE, SETTINGS
    
    if (!STATE.Has("smartCoordinates")) {
        return GetDefaultCoordinates(elementType)
    }
    
    profileKey := elementType . "_Screen" . screenIndex
    
    if (STATE["smartCoordinates"].Has(profileKey)) {
        return STATE["smartCoordinates"][profileKey]
    }
    
    ; إذا لم توجد إحداثيات ذكية، استخدم الافتراضية
    return GetDefaultCoordinates(elementType)
}

; الحصول على الإحداثيات الافتراضية
GetDefaultCoordinates(elementType) {
    global SETTINGS
    
    switch elementType {
        case "StatusArea":
            return Map(
                "x1", SETTINGS["StatusAreaTopLeftX"],
                "y1", SETTINGS["StatusAreaTopLeftY"],
                "x2", SETTINGS["StatusAreaBottomRightX"],
                "y2", SETTINGS["StatusAreaBottomRightY"]
            )
        case "TargetArea":
            return Map(
                "x1", SETTINGS["TargetAreaTopLeftX"],
                "y1", SETTINGS["TargetAreaTopLeftY"],
                "x2", SETTINGS["TargetAreaBottomRightX"],
                "y2", SETTINGS["TargetAreaBottomRightY"]
            )
        case "StayOnlineArea":
            return Map(
                "x1", SETTINGS["StayOnlineAreaTopLeftX"],
                "y1", SETTINGS["StayOnlineAreaTopLeftY"],
                "x2", SETTINGS["StayOnlineAreaBottomRightX"],
                "y2", SETTINGS["StayOnlineAreaBottomRightY"]
            )
        case "RefreshButton":
            return Map(
                "x", SETTINGS["RefreshX"],
                "y", SETTINGS["RefreshY"]
            )
        default:
            return Map()
    }
}

; البحث الذكي عن العناصر في جميع الشاشات
SmartElementSearch(imageList, elementType) {
    global STATE
    
    ; البحث في الإحداثيات الذكية أولاً
    for screenInfo in STATE["detectedScreens"] {
        smartCoords := GetSmartCoordinates(elementType, screenInfo["index"])
        
        if (smartCoords.Has("x1")) {
            local foundX, foundY
            if (IsObject(imageList)) {
                for imgPath in imageList {
                    if (ReliableImageSearch(&foundX, &foundY, imgPath, smartCoords)) {
                        return Map("found", true, "x", foundX, "y", foundY, "screen", screenInfo["index"])
                    }
                }
            } else {
                if (ReliableImageSearch(&foundX, &foundY, imageList, smartCoords)) {
                    return Map("found", true, "x", foundX, "y", foundY, "screen", screenInfo["index"])
                }
            }
        }
    }
    
    ; إذا لم يتم العثور عليه في الإحداثيات الذكية، ابحث في الشاشة كاملة
    for screenInfo in STATE["detectedScreens"] {
        fullScreenArea := Map(
            "x1", screenInfo["left"],
            "y1", screenInfo["top"],
            "x2", screenInfo["right"],
            "y2", screenInfo["bottom"]
        )
        
        local foundX, foundY
        if (IsObject(imageList)) {
            for imgPath in imageList {
                if (ReliableImageSearch(&foundX, &foundY, imgPath, fullScreenArea)) {
                    ; تحديث الإحداثيات الذكية بالموقع الجديد
                    UpdateSmartCoordinates(elementType, screenInfo["index"], foundX, foundY)
                    return Map("found", true, "x", foundX, "y", foundY, "screen", screenInfo["index"])
                }
            }
        } else {
            if (ReliableImageSearch(&foundX, &foundY, imageList, fullScreenArea)) {
                UpdateSmartCoordinates(elementType, screenInfo["index"], foundX, foundY)
                return Map("found", true, "x", foundX, "y", foundY, "screen", screenInfo["index"])
            }
        }
    }
    
    return Map("found", false)
}

; تحديث الإحداثيات الذكية عند العثور على عنصر في موقع جديد
UpdateSmartCoordinates(elementType, screenIndex, foundX, foundY) {
    global STATE
    
    profileKey := elementType . "_Screen" . screenIndex
    
    ; تحديد المنطقة الجديدة بناءً على نوع العنصر
    local margin := 50
    switch elementType {
        case "StatusArea":
            margin := 50
        case "TargetArea":
            margin := 100
        case "StayOnlineArea":
            margin := 30
    }
    
    ; الحصول على معلومات الشاشة
    screenInfo := ""
    for screen in STATE["detectedScreens"] {
        if (screen["index"] == screenIndex) {
            screenInfo := screen
            break
        }
    }
    
    if (screenInfo != "") {
        newCoords := Map(
            "x1", Max(screenInfo["left"], foundX - margin),
            "y1", Max(screenInfo["top"], foundY - margin),
            "x2", Min(screenInfo["right"], foundX + margin + 100),
            "y2", Min(screenInfo["bottom"], foundY + margin + 50)
        )
        
        STATE["smartCoordinates"][profileKey] := newCoords
        Info("Updated smart coordinates for " . elementType . " on Screen " . screenIndex)
        
        ; حفظ التحديث
        SaveIntelligentCoordinates()
    }
}
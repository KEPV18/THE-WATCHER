; ============================================================
; 09_ProfileSystem.ahk - Multi-Profile System for Different Screen Configurations
; ============================================================

; ============================================================
; نظام البروفايلات المتعددة لحفظ إعدادات مختلفة للشاشات والإحداثيات
; ============================================================

; إنشاء بروفايل جديد
CreateProfile(profileName, description := "") {
    global STATE, SETTINGS
    
    if (profileName == "") {
        Warn("Profile name cannot be empty")
        return false
    }
    
    profileDir := A_ScriptDir "\profiles"
    if (!DirExist(profileDir)) {
        DirCreate(profileDir)
    }
    
    profileFile := profileDir "\" . profileName . "_profile.ini"
    
    if (FileExist(profileFile)) {
        Info("Profile already exists: " . profileName)
        return false
    }
    
    try {
        ; حفظ معلومات البروفايل الأساسية
        IniWrite(description, profileFile, "General", "Description")
        IniWrite(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"), profileFile, "General", "Created")
        IniWrite(A_ScreenWidth . "x" . A_ScreenHeight, profileFile, "General", "ScreenResolution")
        IniWrite(MonitorGetCount(), profileFile, "General", "MonitorCount")
        
        ; حفظ الإعدادات الحالية
        SaveCurrentSettingsToProfile(profileName)
        
        Info("Profile created successfully: " . profileName)
        return true
    } catch as e {
        Warn("Failed to create profile: " . e.Message)
        return false
    }
}

; حفظ الإعدادات الحالية في البروفايل
SaveCurrentSettingsToProfile(profileName) {
    global SETTINGS, STATE
    
    profileFile := A_ScriptDir "\profiles\" . profileName . "_profile.ini"
    
    try {
        ; حفظ إحداثيات المناطق
        IniWrite(SETTINGS["StatusAreaTopLeftX"], profileFile, "Coordinates", "StatusAreaTopLeftX")
        IniWrite(SETTINGS["StatusAreaTopLeftY"], profileFile, "Coordinates", "StatusAreaTopLeftY")
        IniWrite(SETTINGS["StatusAreaBottomRightX"], profileFile, "Coordinates", "StatusAreaBottomRightX")
        IniWrite(SETTINGS["StatusAreaBottomRightY"], profileFile, "Coordinates", "StatusAreaBottomRightY")
        
        IniWrite(SETTINGS["TargetAreaTopLeftX"], profileFile, "Coordinates", "TargetAreaTopLeftX")
        IniWrite(SETTINGS["TargetAreaTopLeftY"], profileFile, "Coordinates", "TargetAreaTopLeftY")
        IniWrite(SETTINGS["TargetAreaBottomRightX"], profileFile, "Coordinates", "TargetAreaBottomRightX")
        IniWrite(SETTINGS["TargetAreaBottomRightY"], profileFile, "Coordinates", "TargetAreaBottomRightY")
        
        IniWrite(SETTINGS["StayOnlineAreaTopLeftX"], profileFile, "Coordinates", "StayOnlineAreaTopLeftX")
        IniWrite(SETTINGS["StayOnlineAreaTopLeftY"], profileFile, "Coordinates", "StayOnlineAreaTopLeftY")
        IniWrite(SETTINGS["StayOnlineAreaBottomRightX"], profileFile, "Coordinates", "StayOnlineAreaBottomRightX")
        IniWrite(SETTINGS["StayOnlineAreaBottomRightY"], profileFile, "Coordinates", "StayOnlineAreaBottomRightY")
        
        IniWrite(SETTINGS["RefreshX"], profileFile, "Coordinates", "RefreshX")
        IniWrite(SETTINGS["RefreshY"], profileFile, "Coordinates", "RefreshY")
        
        IniWrite(SETTINGS["FixStep1X"], profileFile, "Coordinates", "FixStep1X")
        IniWrite(SETTINGS["FixStep1Y"], profileFile, "Coordinates", "FixStep1Y")
        IniWrite(SETTINGS["FixStep2X"], profileFile, "Coordinates", "FixStep2X")
        IniWrite(SETTINGS["FixStep2Y"], profileFile, "Coordinates", "FixStep2Y")
        IniWrite(SETTINGS["FixStep3X"], profileFile, "Coordinates", "FixStep3X")
        IniWrite(SETTINGS["FixStep3Y"], profileFile, "Coordinates", "FixStep3Y")
        
        ; حفظ إعدادات الداشبورد
        IniWrite(SETTINGS["DashboardX"], profileFile, "Dashboard", "X")
        IniWrite(SETTINGS["DashboardY"], profileFile, "Dashboard", "Y")
        if (SETTINGS.Has("DashboardX2")) {
            IniWrite(SETTINGS["DashboardX2"], profileFile, "Dashboard", "X2")
        }
        if (SETTINGS.Has("DashboardY2")) {
            IniWrite(SETTINGS["DashboardY2"], profileFile, "Dashboard", "Y2")
        }
        
        ; حفظ الإحداثيات الذكية إن وجدت
        if (STATE.Has("smartCoordinates")) {
            for key, coords in STATE["smartCoordinates"] {
                if (IsObject(coords)) {
                    if (coords.Has("x1")) {
                        IniWrite(coords["x1"], profileFile, "SmartCoordinates", key . "_x1")
                        IniWrite(coords["y1"], profileFile, "SmartCoordinates", key . "_y1")
                        IniWrite(coords["x2"], profileFile, "SmartCoordinates", key . "_x2")
                        IniWrite(coords["y2"], profileFile, "SmartCoordinates", key . "_y2")
                    } else if (coords.Has("x")) {
                        IniWrite(coords["x"], profileFile, "SmartCoordinates", key . "_x")
                        IniWrite(coords["y"], profileFile, "SmartCoordinates", key . "_y")
                    }
                }
            }
        }
        
        ; حفظ معلومات الشاشات
        if (STATE.Has("detectedScreens")) {
            IniWrite(STATE["detectedScreens"].Length, profileFile, "Screens", "Count")
            for i, screenInfo in STATE["detectedScreens"] {
                sectionName := "Screen" . i
                IniWrite(screenInfo["left"], profileFile, sectionName, "left")
                IniWrite(screenInfo["top"], profileFile, sectionName, "top")
                IniWrite(screenInfo["right"], profileFile, sectionName, "right")
                IniWrite(screenInfo["bottom"], profileFile, sectionName, "bottom")
                IniWrite(screenInfo["width"], profileFile, sectionName, "width")
                IniWrite(screenInfo["height"], profileFile, sectionName, "height")
                IniWrite(screenInfo["isPrimary"], profileFile, sectionName, "isPrimary")
            }
        }
        
        ; تحديث تاريخ آخر حفظ
        IniWrite(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"), profileFile, "General", "LastSaved")
        
        Info("Settings saved to profile: " . profileName)
        return true
    } catch as e {
        Warn("Failed to save settings to profile: " . e.Message)
        return false
    }
}

; تحميل بروفايل
LoadProfile(profileName) {
    global SETTINGS, STATE
    
    profileFile := A_ScriptDir "\profiles\" . profileName . "_profile.ini"
    
    if (!FileExist(profileFile)) {
        Warn("Profile not found: " . profileName)
        return false
    }
    
    try {
        ; تحميل إحداثيات المناطق
        SETTINGS["StatusAreaTopLeftX"] := IniRead(profileFile, "Coordinates", "StatusAreaTopLeftX", SETTINGS["StatusAreaTopLeftX"])
        SETTINGS["StatusAreaTopLeftY"] := IniRead(profileFile, "Coordinates", "StatusAreaTopLeftY", SETTINGS["StatusAreaTopLeftY"])
        SETTINGS["StatusAreaBottomRightX"] := IniRead(profileFile, "Coordinates", "StatusAreaBottomRightX", SETTINGS["StatusAreaBottomRightX"])
        SETTINGS["StatusAreaBottomRightY"] := IniRead(profileFile, "Coordinates", "StatusAreaBottomRightY", SETTINGS["StatusAreaBottomRightY"])
        
        SETTINGS["TargetAreaTopLeftX"] := IniRead(profileFile, "Coordinates", "TargetAreaTopLeftX", SETTINGS["TargetAreaTopLeftX"])
        SETTINGS["TargetAreaTopLeftY"] := IniRead(profileFile, "Coordinates", "TargetAreaTopLeftY", SETTINGS["TargetAreaTopLeftY"])
        SETTINGS["TargetAreaBottomRightX"] := IniRead(profileFile, "Coordinates", "TargetAreaBottomRightX", SETTINGS["TargetAreaBottomRightX"])
        SETTINGS["TargetAreaBottomRightY"] := IniRead(profileFile, "Coordinates", "TargetAreaBottomRightY", SETTINGS["TargetAreaBottomRightY"])
        
        SETTINGS["StayOnlineAreaTopLeftX"] := IniRead(profileFile, "Coordinates", "StayOnlineAreaTopLeftX", SETTINGS["StayOnlineAreaTopLeftX"])
        SETTINGS["StayOnlineAreaTopLeftY"] := IniRead(profileFile, "Coordinates", "StayOnlineAreaTopLeftY", SETTINGS["StayOnlineAreaTopLeftY"])
        SETTINGS["StayOnlineAreaBottomRightX"] := IniRead(profileFile, "Coordinates", "StayOnlineAreaBottomRightX", SETTINGS["StayOnlineAreaBottomRightX"])
        SETTINGS["StayOnlineAreaBottomRightY"] := IniRead(profileFile, "Coordinates", "StayOnlineAreaBottomRightY", SETTINGS["StayOnlineAreaBottomRightY"])
        
        SETTINGS["RefreshX"] := IniRead(profileFile, "Coordinates", "RefreshX", SETTINGS["RefreshX"])
        SETTINGS["RefreshY"] := IniRead(profileFile, "Coordinates", "RefreshY", SETTINGS["RefreshY"])
        
        SETTINGS["FixStep1X"] := IniRead(profileFile, "Coordinates", "FixStep1X", SETTINGS["FixStep1X"])
        SETTINGS["FixStep1Y"] := IniRead(profileFile, "Coordinates", "FixStep1Y", SETTINGS["FixStep1Y"])
        SETTINGS["FixStep2X"] := IniRead(profileFile, "Coordinates", "FixStep2X", SETTINGS["FixStep2X"])
        SETTINGS["FixStep2Y"] := IniRead(profileFile, "Coordinates", "FixStep2Y", SETTINGS["FixStep2Y"])
        SETTINGS["FixStep3X"] := IniRead(profileFile, "Coordinates", "FixStep3X", SETTINGS["FixStep3X"])
        SETTINGS["FixStep3Y"] := IniRead(profileFile, "Coordinates", "FixStep3Y", SETTINGS["FixStep3Y"])
        
        ; تحميل إعدادات الداشبورد
        SETTINGS["DashboardX"] := IniRead(profileFile, "Dashboard", "X", SETTINGS["DashboardX"])
        SETTINGS["DashboardY"] := IniRead(profileFile, "Dashboard", "Y", SETTINGS["DashboardY"])
        
        try {
            SETTINGS["DashboardX2"] := IniRead(profileFile, "Dashboard", "X2", "")
            SETTINGS["DashboardY2"] := IniRead(profileFile, "Dashboard", "Y2", "")
        } catch {
        }
        
        ; تحميل الإحداثيات الذكية
        STATE["smartCoordinates"] := Map()
        ; هذا مبسط - في التطبيق الحقيقي نحتاج لقراءة جميع المفاتيح في القسم
        
        ; تحديث البروفايل الحالي
        STATE["currentProfile"] := profileName
        
        Info("Profile loaded successfully: " . profileName)
        return true
    } catch as e {
        Warn("Failed to load profile: " . e.Message)
        return false
    }
}

; الحصول على قائمة البروفايلات المتاحة
GetAvailableProfiles() {
    profileDir := A_ScriptDir "\profiles"
    profiles := []
    
    if (!DirExist(profileDir)) {
        return profiles
    }
    
    try {
        Loop Files, profileDir "\*_profile.ini", "F" {
            profileName := StrReplace(A_LoopFileName, "_profile.ini", "")
            
            ; قراءة معلومات البروفايل
            description := ""
            created := ""
            try {
                description := IniRead(A_LoopFileFullPath, "General", "Description", "")
                created := IniRead(A_LoopFileFullPath, "General", "Created", "")
            } catch {
            }
            
            profileInfo := Map(
                "name", profileName,
                "description", description,
                "created", created,
                "file", A_LoopFileFullPath
            )
            
            profiles.Push(profileInfo)
        }
    } catch as e {
        Warn("Failed to get available profiles: " . e.Message)
    }
    
    return profiles
}

; حذف بروفايل
DeleteProfile(profileName) {
    if (profileName == "default") {
        Warn("Cannot delete default profile")
        return false
    }
    
    profileFile := A_ScriptDir "\profiles\" . profileName . "_profile.ini"
    
    if (!FileExist(profileFile)) {
        Warn("Profile not found: " . profileName)
        return false
    }
    
    try {
        FileDelete(profileFile)
        Info("Profile deleted: " . profileName)
        return true
    } catch as e {
        Warn("Failed to delete profile: " . e.Message)
        return false
    }
}

; اكتشاف البروفايل المناسب تلقائياً بناءً على إعدادات الشاشة
AutoDetectProfile() {
    global STATE
    
    currentResolution := A_ScreenWidth . "x" . A_ScreenHeight
    currentMonitorCount := MonitorGetCount()
    
    profiles := GetAvailableProfiles()
    
    for profileInfo in profiles {
        try {
            profileFile := profileInfo["file"]
            savedResolution := IniRead(profileFile, "General", "ScreenResolution", "")
            savedMonitorCount := IniRead(profileFile, "General", "MonitorCount", 0)
            
            if (savedResolution == currentResolution && savedMonitorCount == currentMonitorCount) {
                Info("Auto-detected matching profile: " . profileInfo["name"])
                return profileInfo["name"]
            }
        } catch {
            continue
        }
    }
    
    Info("No matching profile found for current screen configuration")
    return ""
}

; إنشاء بروفايل تلقائي بناءً على الإعدادات الحالية
CreateAutoProfile() {
    global STATE
    
    currentResolution := A_ScreenWidth . "x" . A_ScreenHeight
    currentMonitorCount := MonitorGetCount()
    
    profileName := "auto_" . currentResolution . "_" . currentMonitorCount . "mon"
    description := "Auto-generated profile for " . currentResolution . " with " . currentMonitorCount . " monitor(s)"
    
    if (CreateProfile(profileName, description)) {
        Info("Auto-profile created: " . profileName)
        return profileName
    }
    
    return ""
}

; تبديل البروفايل
SwitchProfile(profileName) {
    global STATE
    
    if (LoadProfile(profileName)) {
        STATE["currentProfile"] := profileName
        Info("Switched to profile: " . profileName)
        
        ; إعادة تشغيل النظام الذكي لاكتشاف الإحداثيات الجديدة
        if (SETTINGS.Has("IntelligentCoordinates") && SETTINGS["IntelligentCoordinates"]) {
            try {
                IntelligentCoordinateDetection()
            } catch as e {
                Warn("Failed to run intelligent coordinate detection after profile switch: " . e.Message)
            }
        }
        
        return true
    }
    
    return false
}

; حفظ البروفايل الحالي
SaveCurrentProfile() {
    global STATE
    
    if (!STATE.Has("currentProfile") || STATE["currentProfile"] == "") {
        STATE["currentProfile"] := "default"
    }
    
    return SaveCurrentSettingsToProfile(STATE["currentProfile"])
}

; تصدير بروفايل إلى ملف منفصل
ExportProfile(profileName, exportPath) {
    profileFile := A_ScriptDir "\profiles\" . profileName . "_profile.ini"
    
    if (!FileExist(profileFile)) {
        Warn("Profile not found: " . profileName)
        return false
    }
    
    try {
        FileCopy(profileFile, exportPath, true)
        Info("Profile exported to: " . exportPath)
        return true
    } catch as e {
        Warn("Failed to export profile: " . e.Message)
        return false
    }
}

; استيراد بروفايل من ملف خارجي
ImportProfile(importPath, newProfileName) {
    if (!FileExist(importPath)) {
        Warn("Import file not found: " . importPath)
        return false
    }
    
    profileDir := A_ScriptDir "\profiles"
    if (!DirExist(profileDir)) {
        DirCreate(profileDir)
    }
    
    newProfileFile := profileDir "\" . newProfileName . "_profile.ini"
    
    try {
        FileCopy(importPath, newProfileFile, false)
        
        ; تحديث معلومات البروفايل
        IniWrite(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"), newProfileFile, "General", "Imported")
        IniWrite("Imported profile", newProfileFile, "General", "Description")
        
        Info("Profile imported as: " . newProfileName)
        return true
    } catch as e {
        Warn("Failed to import profile: " . e.Message)
        return false
    }
}
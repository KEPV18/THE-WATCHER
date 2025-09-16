InitializeScript() {
    // ... existing code ...
    
    ; إضافة مراقبة الموارد
    SetTimer(MonitorResources, SETTINGS["ResourceMonitorInterval"])
}

MonitorResources(*) {
    try {
        memUsage := GetScriptMemoryUsage()
        cpuUsage := GetScriptCPUUsage()
        
        if (memUsage > SETTINGS["MemoryWarningThreshold"] || cpuUsage > SETTINGS["CPUWarningThreshold"]) {
            Warn("High resource usage - Memory: " . memUsage . "MB, CPU: " . cpuUsage . "%")
        }
        
        LogPerformance("ResourceUsage", 0, Map(
            "Memory", memUsage,
            "CPU", cpuUsage,
            "GDIResources", GdipResourceCount
        ))
    } catch as err {
        LogError("Resource monitoring failed: " . err.Message)
    }
}

LoadSettings() {
    SETTINGS["OnlineImage"] := imageFolder . IniRead(iniFile, "Citrix", "OnlineImageName", "online.png")
    SETTINGS["OnlineImage2"] := imageFolder . IniRead(iniFile, "Citrix", "OnlineImage2Name", "online2.png")
}
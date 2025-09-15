; إضافة متغيرات لتتبع استخدام GDI+
global GdipResourceCount := 0
global GdipLastCleanup := 0

; دالة جديدة لتتبع موارد GDI+
TrackGdipResource(action) {
    global GdipResourceCount
    if (action = "add")
        GdipResourceCount++
    else if (action = "remove" && GdipResourceCount > 0)
        GdipResourceCount--
    
    if (GdipResourceCount > 100) { ; عتبة تحذير
        Warn("High GDI+ resource usage: " . GdipResourceCount)
    }
}

; تحسين دالة إنشاء الصور
Gdip_CreateBitmapFromFile(sFile) {
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", sFile, "Ptr*", &pBitmap)
    if (pBitmap)
        TrackGdipResource("add")
    return pBitmap
}

; تحسين دالة التخلص من الصور
Gdip_DisposeImage(pBitmap) {
    if pBitmap {
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
        TrackGdipResource("remove")
    }
}
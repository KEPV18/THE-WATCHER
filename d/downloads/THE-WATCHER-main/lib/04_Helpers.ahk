ReliableImageSearch(&foundX, &foundY, ImageFile, SearchArea := "") {
    static imageCache := Map()
    static lastUsed := Map()  ; تتبع آخر استخدام للصور
    static maxCacheSize := 10  ; الحد الأقصى لعدد الصور في الذاكرة المؤقتة
    
    foundX := -1
    foundY := -1

    if (!FileExist(ImageFile)) {
        try {
            Warn("Image file not found: " . ImageFile)
        }
        return false
    }

    ; تنظيف الذاكرة المؤقتة إذا تجاوزت الحد
    if (imageCache.Count >= maxCacheSize) {
        oldestImage := ""
        oldestTime := A_TickCount
        for file, time in lastUsed {
            if (time < oldestTime) {
                oldestTime := time
                oldestImage := file
            }
        }
        if (oldestImage && imageCache.Has(oldestImage)) {
            Gdip_DisposeImage(imageCache[oldestImage])
            imageCache.Delete(oldestImage)
            lastUsed.Delete(oldestImage)
        }
    }

    ; تحديث أو إنشاء الصورة في الذاكرة المؤقتة
    if (!imageCache.Has(ImageFile)) {
        try {
            pBitmap := Gdip_CreateBitmapFromFile(ImageFile)
            if (pBitmap) {
                imageCache[ImageFile] := pBitmap
            }
        }
    }
    lastUsed[ImageFile] := A_TickCount

    ; استخدام الصورة المخزنة مؤقتاً
    pBitmap := imageCache[ImageFile]
    if (!pBitmap) {
        return false
    }

    // ... existing code ...
}
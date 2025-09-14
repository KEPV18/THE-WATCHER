#Requires AutoHotkey v2.0
; UpdateFromGithub.ahk
; سكربت لتحديث المشروع أوتوماتيكياً من GitHub بدون الحاجة إلى Git
; 1) إنشاء نسخة احتياطية
; 2) تنزيل آخر ZIP من الريبو
; 3) فك الضغط ونسخ الملفات فوق المشروع الحالي
; 4) تجاهل ملف التحديث نفسه ومجلد النسخ السابقة

; =============== إعدادات ثابتة ===============
REPO_URL := "https://github.com/KEPV18/THE-WATCHER"
BRANCHES_TO_TRY := ["main", "master"]
BACKUP_DIR_NAME := "نسخ سابقة"

; =============== الدالة الرئيسية ===============
Main() {
    projectDir  := A_ScriptDir
    updaterName := A_ScriptName

    ; 1) إنشاء نسخة احتياطية
    if !CreateBackupZip(projectDir, BACKUP_DIR_NAME, updaterName, &backupZipPath) {
        MsgBox "تعذّر إنشاء النسخة الاحتياطية."
        return
    }

    ; 2) تنزيل ملف ZIP من GitHub
    zipPath := A_Temp "\upd_" FormatTime(, "yyyyMMdd_HHmmss") ".zip"
    urls := BuildZipUrls(REPO_URL, BRANCHES_TO_TRY*)
    if (urls.Length = 0) {
        MsgBox "رابط الريبو غير صالح: " REPO_URL
        return
    }
    if !TryDownloadZip(urls, zipPath) {
        MsgBox "تعذّر تنزيل ZIP من GitHub. تم تجربة الفروع: " . StrJoin(", ", BRANCHES_TO_TRY*)
        return
    }

    ; 3) فك الضغط
    extractDir := A_Temp "\ex_" FormatTime(, "yyyyMMdd_HHmmss")
    try DirCreate(extractDir)
    catch {
        MsgBox "تعذّر إنشاء مجلد مؤقت."
        return
    }

    if ExpandArchive(zipPath, extractDir) != 0 {
        MsgBox "فشل فك الضغط."
        try FileDelete(zipPath)
        return
    }

    ; 4) تحديد مجلد الجذر بعد الفك
    srcRoot := GetFirstSubdir(extractDir)
    if (srcRoot = "")
        srcRoot := extractDir

    ; 5) نسخ الملفات باستخدام robocopy
    robocopy := 'robocopy "' srcRoot '" "' projectDir '" /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1'
    robocopy .= ' /XF "' updaterName '"'
    robocopy .= ' /XD "' BACKUP_DIR_NAME '"'
    try RunWait('cmd.exe /C ' robocopy, , "Hide")

    ; 6) تنظيف الملفات المؤقتة
    try FileDelete(zipPath)
    try DirDelete(extractDir, true)

    ; تحديث صامت: بدون MsgBox نجاح
}

; =============== دوال مساعدة ===============

BuildZipUrls(repoUrl, branches*) {
    urls := []
    if RegExMatch(repoUrl, "i)github\.com/([^/]+)/([^/]+)", &m) {
        owner := m[1], repo := m[2]
        if (SubStr(repo, -3) = ".git")
            repo := SubStr(repo, 1, -4)
        for br in branches {
            urls.Push("https://codeload.github.com/" owner "/" repo "/zip/refs/heads/" br)
            urls.Push("https://github.com/" owner "/" repo "/archive/refs/heads/" br ".zip")
        }
    }
    return urls
}

ExpandArchive(zipPath, destDir) {
    ; نحاول باستخدام PowerShell Expand-Archive
    ps := "Expand-Archive -LiteralPath '" zipPath "' -DestinationPath '" destDir "' -Force"
    rc := RunWait('powershell -NoProfile -ExecutionPolicy Bypass -Command "' ps '"', , "Hide")
    if (rc = 0)
        return 0

    ; المحاولة الثانية: .NET ZipFile
    ps2 := "[System.IO.Compression.ZipFile]::ExtractToDirectory('" zipPath "', '" destDir "')"
    rc2 := RunWait('powershell -NoProfile -ExecutionPolicy Bypass -Command "' ps2 '"', , "Hide")
    if (rc2 = 0)
        return 0

    ; المحاولة الثالثة: tar
    rc3 := RunWait('cmd.exe /C tar -xf "' zipPath '" -C "' destDir '"', , "Hide")
    return (rc3 = 0 ? 0 : 1)
}

GetFirstSubdir(baseDir) {
    Loop Files baseDir "\*", "D"
        return A_LoopFileFullPath
    return ""
}

CreateBackupZip(projectDir, backupDirName, updaterName, &outZipPath) {
    try {
        backupDir := projectDir "\" backupDirName
        if !DirExist(backupDir)
            DirCreate(backupDir)

        ts := FormatTime(, "yyyyMMdd_HHmmss")
        outZipPath := backupDir "\backup_" ts ".zip"

        psScript :=
        (
"$root = '" projectDir "'; 
$zip  = '" outZipPath "'; 
$exclude = @('" backupDirName "', '" updaterName "'); 
$items = Get-ChildItem -Force -LiteralPath $root | Where-Object { $exclude -notcontains $_.Name }; 
if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force; } 
Compress-Archive -Path $items -DestinationPath $zip -Force;"
        )
        rc := RunWait('powershell -NoProfile -ExecutionPolicy Bypass -Command "' psScript '"', , "Hide")
        return (rc = 0)
    }
    return false
}

TryDownloadZip(urls, zipPath) {
    for url in urls {
        try {
            Download(url, zipPath)
            if IsLikelyZip(zipPath)
                return true
        } catch {
            continue
        }
    }
    return false
}

IsLikelyZip(path) {
    if !FileExist(path)
        return false
    f := FileOpen(path, "r")
    if !IsObject(f)
        return false
    buf := Buffer(2)
    f.RawRead(buf, 2), f.Close()
    return (NumGet(buf, 0, "UChar") = 0x50 && NumGet(buf, 1, "UChar") = 0x4B)
}

StrJoin(delimiter, params*) {
    out := ""
    for i, v in params
        out .= (i = 1 ? "" : delimiter) v
    return out
}

; =============== تشغيل ===============
Main()

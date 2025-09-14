#Requires AutoHotkey v2.0
; UpdateFromGithub.ahk - Silent updater without Git
; 1) Backup current folder into "نسخ سابقة\backup_yyyyMMdd_HHmmss.zip"
; 2) Download latest ZIP from GitHub (tries main then master)
; 3) Extract and copy over current folder (no deletions), excluding backup folder and this updater file.

; ====== ثابت رابط الريبو (بدون تفاعل) ======
REPO_URL := "https://github.com/KEPV18/THE-WATCHER.git"
BRANCHES_TO_TRY := ["main", "master"]
BACKUP_DIR_NAME := "نسخ سابقة"

Main() {
    projectDir := A_ScriptDir
    updaterName := A_ScriptName
    ; 1) إنشاء نسخة احتياطية
    ok := CreateBackupZip(projectDir, BACKUP_DIR_NAME, updaterName, &backupZipPath)
    if (!ok) {
        ; خطأ في النسخ الاحتياطي -> توقف
        ; متعمّد عدم إظهار MsgBox حفاظاً على الصمت، لكن نسمح برسالة عند الخطأ الشديد
        MsgBox "تعذّر إنشاء النسخة الاحتياطية."
        return
    }

    ; 2) تنزيل ملف ZIP من GitHub (تجربة main ثم master)
    zipPath := A_Temp "\upd_" FormatTime(, "yyyyMMdd_HHmmss") ".zip"
    urls := BuildZipUrls(REPO_URL, BRANCHES_TO_TRY*)
    if (urls.Length = 0) {
        MsgBox "رابط الريبو غير صالح: " REPO_URL
        return
    }
    downloaded := false
    for url in urls {
        try {
            Download(url, zipPath)
            downloaded := true
            break
        } catch {
            ; جرّب الرابط التالي
        }
    }
    if (!downloaded) {
        MsgBox "تعذّر تنزيل ZIP من GitHub. تم تجربة الفروع: " StrJoin(BRANCHES_TO_TRY, ", ")
        return
    }

    ; 3) فك الضغط في مجلد مؤقت
    extractDir := A_Temp "\ex_" FormatTime(, "yyyyMMdd_HHmmss")
    DirCreate(extractDir)
    if (ExpandArchive(zipPath, extractDir) != 0) {
        MsgBox "فشل فك الضغط باستخدام PowerShell."
        try FileDelete(zipPath)
        return
    }

    ; 4) تحديد جذر الملفات داخل الـ ZIP
    srcRoot := GetFirstSubdir(extractDir)
    if (srcRoot = "")
        srcRoot := extractDir

    ; 5) نسخ الملفات إلى مجلد المشروع (استبدال بدون حذف)، مع استثناءات
    ;    - استثناء مجلد النسخ الاحتياطية حتى لا يُمسّ
    ;    - استثناء هذا السكريبت حتى لا يُستبدل أثناء العمل
    robocopy := 'robocopy "' . srcRoot . '" "' . projectDir . '" /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1'
    robocopy .= ' /XF "' . updaterName . '"'
    robocopy .= ' /XD "' . BACKUP_DIR_NAME . '"'
    ; ملاحظة: لا نستخدم /MIR لتجنّب حذف أي ملفات إضافية لديك (ولضمان بقاء السكريبت ومجلد النسخ)
    RunWait('cmd.exe /C ' . robocopy, , "Hide")

    ; 6) تنظيف المؤقّتات
    try FileDelete(zipPath)
    try DirDelete(extractDir, true)

    ; صامت: لا نعرض MsgBox نجاحاً لالتزام "بدون أسئلة/حوار".
}

BuildZipUrls(repoUrl, branches*) {
    urls := []
    if RegExMatch(repoUrl, "i)github\.com/([^/]+)/([^/]+)", &m) {
        owner := m[1], repo := m[2]
        if (SubStr(repo, -3) = ".git")
            repo := SubStr(repo, 1, -4)
        for br in branches {
            urls.Push("https://codeload.github.com/" owner "/" repo "/zip/refs/heads/" br)
        }
    }
    return urls
}

ExpandArchive(zipPath, destDir) {
    ; يستخدم PowerShell Expand-Archive (موجود افتراضياً في Windows 10+)
    ps := 'powershell -NoProfile -ExecutionPolicy Bypass -Command "Try { Expand-Archive -LiteralPath '''
        . zipPath . "'' -DestinationPath ''" . destDir . "'' -Force; exit 0 } Catch { exit 1 }\""
    return RunWait(ps, , "Hide")
}

GetFirstSubdir(baseDir) {
    first := ""
    Loop Files baseDir "\*", "D" {
        first := A_LoopFileFullPath
        break
    }
    return first
}

CreateBackupZip(projectDir, backupDirName, updaterName, &outZipPath) {
    try {
        backupDir := projectDir "\" backupDirName
        if !DirExist(backupDir)
            DirCreate(backupDir)
        ts := FormatTime(, "yyyyMMdd_HHmmss")
        outZipPath := backupDir "\backup_" ts ".zip"

        ; نستخدم PowerShell لضغط كل شيء باستثناء:
        ; - مجلد "نسخ سابقة"
        ; - ملف السكريبت الحالي
        psScript :=
        (
            "
            $root = '" projectDir "';
            $zip  = '" outZipPath "';
            $exclude = @('" backupDirName "', '" updaterName "');
            $items = Get-ChildItem -Force -LiteralPath $root
                     | Where-Object { $exclude -notcontains $_.Name };
            if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force; }
            Compress-Archive -Path $items -DestinationPath $zip -Force;
            "
        )
        rc := RunWait('powershell -NoProfile -ExecutionPolicy Bypass -Command ' . QuoteForPS(psScript), , "Hide")
        return rc = 0
    } catch {
        return false
    }
}

QuoteForPS(s) {
    ; نلفّ السكربت بين & { } لحماية المسافات والاقتباسات
    ; ونستبدل الاقتباس المزدوج بـ \" داخل السلسلة
    s := StrReplace(s, '"', '\"')
    return '"& { ' . s . ' }"'
}

; تشغيل
Main()
#Requires AutoHotkey v2.0
; PublishRepo.ahk - Commit & push the entire folder to GitHub (reads [Git] from settings.ini)
; يعرض لك نتيجة كل عملية بشكل واضح.

DEFAULT_BRANCH := "main"

Main() {
    projectDir := A_ScriptDir
    EnsureGitAvailable()

    ; 1) قراءة إعدادات الريبو
    repoUrl := IniRead(projectDir "\settings.ini", "Git", "RepoUrl", "")
    branch  := IniRead(projectDir "\settings.ini", "Git", "Branch", DEFAULT_BRANCH)
    if (repoUrl = "") {
        ib := InputBox("ضع رابط الريبو (مثال: https://github.com/username/repo.git)", "Git Repo URL")
        if (ib.Result != "OK" || ib.Value = "") {
            MsgBox "تم الإلغاء: لم يتم تحديد رابط الريبو."
            return
        }
        repoUrl := ib.Value
        IniWrite(repoUrl, projectDir "\settings.ini", "Git", "RepoUrl")
        IniWrite(branch,  projectDir "\settings.ini", "Git", "Branch")
    } else {
        IniWrite(branch,  projectDir "\settings.ini", "Git", "Branch")
    }

    ; 2) إنشاء .gitignore عند الحاجة
    EnsureGitignore(projectDir)

    ; 3) تهيئة Git repo عند الحاجة
    if !DirExist(projectDir "\.git") {
        if (RunCmd("git init", projectDir) != 0) {
            MsgBox "فشل git init. تأكد أن Git مثبت."
            return
        }
    }

    ; 4) ضبط الريموت origin
    rc := RunCmd('git remote add origin "' . repoUrl . '"', projectDir)
    if (rc != 0) {
        ; لو موجود بالفعل -> حدّث الرابط
        RunCmd('git remote set-url origin "' . repoUrl . '"', projectDir)
    }

    ; 5) إضافة كل الملفات
    RunCmd("git add -A", projectDir)

    ; 6) محاولة إنشاء commit
    now := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    comp := EnvGet("COMPUTERNAME")
    msg  := 'Auto publish: ' . now . ' (' . comp . ')'
    commitRc := RunCmd('git commit -m "' . msg . '"', projectDir)

    ; معالجة فشل commit
    if (commitRc != 0) {
        hasChanges := GitHasChanges(projectDir)
        if (hasChanges) {
            ; في الغالب مشكلة هوية git user/email
            MsgBox "فشل إنشاء commit رغم وجود تغييرات.`nتأكد من إعداد هوية Git (user.name / user.email) ثم أعد المحاولة."
            return
        }
        ; لا توجد تغييرات جديدة -> سنحاول push على أي حال
    } else {
        ; بعد أول commit في ريبوزيتوري جديد، اضبط اسم الفرع
        RunCmd('git branch -M "' . branch . '"', projectDir)
    }

    ; 7) دفع التغييرات إلى GitHub
    pushRc := RunCmd('git push -u origin "' . branch . '"', projectDir)

    if (pushRc = 0) {
        if (commitRc = 0)
            MsgBox "تم النشر إلى GitHub بنجاح.`nCommit: " msg
        else
            MsgBox "تم الدفع إلى GitHub بنجاح (لا توجد تغييرات جديدة، كل شيء مُحدّث)."
    } else {
        MsgBox "فشل git push.`nتأكد أن لديك صلاحية الدفع (PAT/اعتماد) وأن اسم الفرع صحيح (" branch ")."
    }
}

EnsureGitignore(projectDir) {
    gi := projectDir "\.gitignore"
    if FileExist(gi)
        return
    content :=
    (
        "
        # Local runtime artifacts
        screenshots/
        master_log.txt
        last_error.log
        state_snapshot.ini
        نسخ سابقة/
        UpdateFromGithub.ahk

        # Windows noise
        Thumbs.db
        desktop.ini

        # Archives & temp
        *.tmp
        *.bak
        "
    )
    FileAppend(content, gi, "UTF-8-RAW")
}

GitHasChanges(workdir) {
    out := RunAndCapture("git status --porcelain", workdir)
    return Trim(out) != ""
}

EnsureGitAvailable() {
    rc := RunCmd("git --version")
    if (rc != 0) {
        MsgBox "Git غير مثبت أو غير متاح في PATH.`nقم بتثبيته من: https://git-scm.com/download/win"
        ExitApp
    }
}

RunCmd(cmd, workdir := "", quiet := true) {
    try {
        opts := quiet ? "Hide" : ""
        return RunWait("cmd.exe /C " . cmd, workdir, opts)
    } catch e {
        MsgBox "خطأ أثناء تنفيذ الأمر:`n" cmd "`n`n" e.Message
        return -1
    }
}

RunAndCapture(cmd, workdir := "") {
    tmp := A_Temp "\git_out_" FormatTime(, "yyyyMMdd_HHmmss") "_" A_TickCount ".txt"
    full := cmd . ' > "' . tmp . '" 2>&1'
    RunWait("cmd.exe /C " . full, workdir, "Hide")
    try {
        content := FileRead(tmp, "UTF-8")
        FileDelete(tmp)
        return content
    } catch {
        return ""
    }
}

; تشغيل
Main()
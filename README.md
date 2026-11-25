# THE-WATCHER

A Windows desktop monitor written in AutoHotkey v2. It watches a remote-desktop window on screen, recognizes its status by matching reference images, shows a small dashboard, and sends alerts to Telegram. A second script keeps it running and restarts it after a crash.

This is a personal automation project. It is not a library and it has only been run on the author's own setup.

## What it does

- **Status detection.** Timers in `lib/05_TimersLogic.ahk` look for reference images (online, offline, break and similar states) in the watched window and react when the state changes.
- **Coordinate detection.** `lib/08_IntelligentSystem.ahk` finds image positions automatically, so you do not hard-code screen coordinates.
- **Profiles.** `lib/09_ProfileSystem.ahk` and `profiles/` store separate settings for different screen layouts (for example 1366x768 with one monitor, 1920x1080 with two).
- **Dashboard and hotkeys.** `lib/06_DashboardHotkeys.ahk` draws the on-screen dashboard and handles hotkeys. Image work goes through a GDI+ helper in `lib/07_GDIPlus.ahk`.
- **Telegram alerts and logs.** Notifications go out through the Telegram Bot API. `telegram_tools/` has scripts for sending and fetching logs (see its own README).
- **Crash supervisor.** `Watcher.ahk` runs `master.ahk`, captures its errors into `last_error.log`, reports the failure, and offers to restart it.
- **Self-update.** `UpdateFromGithub.ahk` backs up the project, downloads the latest ZIP of this repo and copies it over the current folder.
- **Demo.** `demo/demo.ahk` is a single-file, lighter version.

## Layout

```
Watcher.ahk            supervisor: runs and restarts master.ahk
master.ahk             main dashboard, loads the modules in lib/
lib/                   core settings, logging, helpers, timers, hotkeys, GDI+, detection, profiles
profiles/              per-screen-layout settings
settings.ini           window titles, reference image names, beep settings
telegram_tools/        log send/fetch helpers
demo/demo.ahk          single-file version
UpdateFromGithub.ahk   updater
```

## Setup

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Put your own reference screenshots next to the scripts and set their file names in `settings.ini`.
3. Create your own Telegram bot and set its token and chat ID either in a local `[Telegram]` section of `settings.ini` (`BotToken`, `ChatId`) or in the environment variables `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`. Prefer the environment variables so the token never lands in a committed file.
4. Run `Watcher.ahk`.

## Notes

- The current files in this repository do not contain a bot token. Configure your own token locally and keep it out of commits.
- Detection depends on screen resolution, scaling and the exact look of the watched window, so expect to re-capture images and adjust a profile.
- Comments and some messages are in Arabic.

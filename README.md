# Eyes Guardian

Tiny Windows 11 eye-rest reminder app built with AutoHotkey v2.

## Features
- Draggable cute eye widget (borderless + tool window)
- Default pinned (always on top)
- Right-click menu: `Pin/Unpin`, `Close`
- Eye gradually turns soft red over 20 minutes
- Exclamation mark appears when 20 minutes is up
- Double left-click resets the timer cycle
- Saves last position and pinned state in `%LOCALAPPDATA%\EyesGuardian\settings.ini`

## Run (script mode)
1. Install AutoHotkey v2 on Windows.
2. Run `EyesGuardian.ahk`.

## Build Standalone EXE
1. Install AutoHotkey v2 (includes `Ahk2Exe`).
2. Open PowerShell in this folder.
3. Run:

```powershell
& "$env:ProgramFiles\AutoHotkey\Compiler\Ahk2Exe.exe" /in "EyesGuardian.ahk" /out "EyesGuardian.exe"
```

This produces a portable single-file executable: `EyesGuardian.exe`.

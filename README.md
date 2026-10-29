<p align="center">
  <img src="docs/img/banner.png" alt="PZ Workshop Doctor" width="100%">
</p>
<p align="center">
  <a href="../../releases/latest"><img src="docs/img/button-download-en.png" alt="Download for Windows"></a>
</p>
<p align="center">
  <a href="README.md"><img src="https://img.shields.io/badge/README-English-8A9A5B?style=for-the-badge" alt="English"></a>
  <a href="README.ru.md"><img src="https://img.shields.io/badge/README-%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B0%D1%8F%20%D0%B2%D0%B5%D1%80%D1%81%D0%B8%D1%8F-C9963C?style=for-the-badge" alt="Русская версия"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-6B7057?style=for-the-badge" alt="MIT License"></a>
</p>

# PZ Workshop Doctor

Unofficial mod doctor for **Project Zomboid** (Steam Workshop). One file, one window, one button: it scans Steam, the saves and every mod by itself, finds the problems the in-game manager cannot see, and fixes them — backups first. While it works, a survivor walks the road along the bottom, the horde shambling behind him — **his walk is the progress bar**: when the round ends he reaches the end of the road, the window reads "THE STREET IS CLEAN — YOU SURVIVED", and the zombies drop dead. When something breaks, the horde catches him and eats him instead.

**The check — from a pile of problems to a clean street**

| Before | The scan | One button |
|---|---|---|
| [![Before: the whole pile of problems in one window](docs/img/workshop/v1.1/en/shot-1-before.png)](https://genocide12.github.io/pz-workshop-doctor/gallery.html#en-1) | [![Scan: the survivor walks the road](docs/img/workshop/v1.1/en/shot-2-scan.png)](https://genocide12.github.io/pz-workshop-doctor/gallery.html#en-2) | [![Fix everything automatically](docs/img/workshop/v1.1/en/shot-3-button.png)](https://genocide12.github.io/pz-workshop-doctor/gallery.html#en-3) |
| The game won't load the mods, half are off, the logs are a wall of errors — one run shows the whole picture. | One press of the green button — Steam, the game, the mods and the saves are found by themselves; the road below is the progress bar. | 23 problems found — "Fix everything automatically" does the rest, backups first. |

| Missing mods | Orphans | After |
|---|---|---|
| [![Missing mods download themselves](docs/img/workshop/v1.1/en/shot-4-download.png)](https://genocide12.github.io/pz-workshop-doctor/gallery.html#en-4) | [![Orphaned requirements are disabled with a backup](docs/img/workshop/v1.1/en/shot-5-orphans.png)](https://genocide12.github.io/pz-workshop-doctor/gallery.html#en-5) | [![After: the street is clean — you survived](docs/img/workshop/v1.1/en/shot-6-after.png)](https://genocide12.github.io/pz-workshop-doctor/gallery.html#en-6) |
| A require= entry is looked up in the Workshop — the subscribe page opens, Steam downloads, the program notices and re-checks by itself. | The required mod is gone from the Workshop? The mods that need it are cleanly disabled in the saves — with a backup, and the warnings die for good. | Quarantine removed, broken downloads reinstalled, missing mods fetched — 23 → 0, everything in the repair log. |

**Manual management, details, optimizer, terminal**

| Manual mode | Details |
|---|---|
| [![The sortable mods table](docs/img/workshop/v1.1/en/shot-7-manual.png)](https://genocide12.github.io/pz-workshop-doctor/gallery.html#en-7) | [![Mod details with the live Workshop description](docs/img/workshop/v1.1/en/shot-8-details.png)](https://genocide12.github.io/pz-workshop-doctor/gallery.html#en-8) |
| Click any column to sort (status sorts by meaning, ticked rows rise to the top), tick rows, then "Enable checked" / "Disable checked". | Select a row: modID, paths and requirements on top, the live Workshop description below — tags, size, update date. |

| Optimizer | CLI |
|---|---|
| [![The optimizer view](docs/img/workshop/v1.1/en/shot-9-optimizer.png)](https://genocide12.github.io/pz-workshop-doctor/gallery.html#en-9) | [![CLI report and auto-fix in the terminal](docs/img/workshop/v1.1/en/shot-10-cli.png)](https://genocide12.github.io/pz-workshop-doctor/gallery.html#en-10) |
| Game memory (-Xmx), Steam launch options, junk logs — every change is one button away from being undone. | -Cli -AutoFix in one command: same engine, same backups, zero windows. |

## Install (30 seconds)

1. Download `PZWorkshopDoctor.exe` (or the `.ps1`) from [Releases](../../releases/latest).
2. Run it. Nothing to install — Windows 10/11, PowerShell 5.1 or 7, game B41/B42.

The start shows a "ready to check" card and the street below comes alive — but nothing runs by itself: the check begins exactly when you press the one green button. No settings, no accounts, no popups — and if anything unexpected happens on a live machine, the window names the failing step and keeps working instead of dying with a cryptic error.

## What it actually fixes

- **Missing mods are fetched for you**: the requirement named in `require=` is looked up in the Workshop and its subscribe page opens; Steam downloads it, the program notices and re-checks by itself. A requirement that does not exist in the Workshop at all (deleted or never published)? The mods that demand it — and everything depending on them — are switched off in the saves, with a backup, so the warnings die for good.
- **Manual management, when you want it**: tick mods in the table and press "Enable checked" or "Disable checked" — enabling pulls the installed requirements along, disabling takes the dependents with it (no orphan warnings after your own click), and Build 42's `workshopMods.txt` stays in sync. Click any column header to sort the table — status sorts by meaning rather than alphabet, ticked rows rise to the top, and the order survives every re-check. Every change is one click, one backup.
- Mods that are installed but not enabled in the save — enabled, in dependency order, with a `mods.txt` backup.
- Duplicate modIDs (two Workshop items shipping the same id) and leftovers from unsubscribed mods.
- Broken downloads (no `mod.info`) — removed so Steam re-downloads them; map/tile packs are recognized as content, not errors.
- Full Workshop descriptions, selectable logs, and a real optimizer: game memory (`-Xmx`), Steam launch options, junk logs — every change reversible.

## Terminal, if you prefer

```powershell
powershell -ExecutionPolicy Bypass -File .\PZ-WorkshopDoctor.ps1 -Cli            # full report
powershell -ExecutionPolicy Bypass -File .\PZ-WorkshopDoctor.ps1 -Cli -AutoFix   # check, fix, report before/after
```

## Links

[Releases](../../releases/latest) · [Русское README](README.ru.md) — community tool, not affiliated with The Indie Stone or Valve.

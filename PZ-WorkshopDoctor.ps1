#Requires -Version 5.1
<#
    PZ Workshop Doctor v1.1
    Unofficial mod manager and conflict doctor for Project Zomboid Steam Workshop.

    GUI : powershell -ExecutionPolicy Bypass -File .\PZ-WorkshopDoctor.ps1
    CLI : powershell -ExecutionPolicy Bypass -File .\PZ-WorkshopDoctor.ps1 -Cli
    Help: powershell -ExecutionPolicy Bypass -File .\PZ-WorkshopDoctor.ps1 -Help

    Everything is auto-detected: Steam libraries, Workshop content, saves,
    interface language. The script can live in any folder and be run from anywhere.

    Unofficial community tool. Not affiliated with The Indie Stone or Valve.
#>
[CmdletBinding()]
param(
    [switch]$Cli,
    [switch]$Help,
    [switch]$Conflicts,
    [switch]$Export,
    [string]$OutFile = '',
    [string]$SteamPath = '',
    [string]$SaveDir = '',
    [string]$ZomboidDir = '',
    [switch]$Optimize,
    [switch]$CleanQuarantine,
    [switch]$AutoFix,
    [switch]$NoWizard,
    [string]$Lang = ''
)

$ErrorActionPreference = 'Continue'
$Script:Version = '1.1'
$Script:ZomboidDir = $ZomboidDir

# Language: an explicit -Lang RU|EN wins; otherwise it follows the Windows culture.
$Script:Lang = $Lang
if ($Script:Lang -ne 'RU' -and $Script:Lang -ne 'EN') {
    $Script:Lang = 'EN'
    try {
        if ((Get-Culture).TwoLetterISOLanguageName -eq 'ru') { $Script:Lang = 'RU' }
    } catch { }
}

# =============================================================================
# Localization
# =============================================================================
$Script:L10N = @{}
$Script:L10N['RU'] = @{
    tagline           = 'Диагностика модов Workshop для Project Zomboid'
    footer            = 'Неофициальный инструмент сообщества. Не связан с The Indie Stone и Valve.'
    col_sel           = '✓'
    col_num           = '№'
    col_name          = 'Имя мода'
    col_ids           = 'modID'
    col_wid           = 'WorkshopID'
    col_status        = 'Статус'
    btn_main          = '1. Проверить и исправить'
    btn_manual        = '2. Ручное управление модами'
    btn_manual_hide   = '× Скрыть таблицу'
    btn_opt           = '3. Оптимизировать игру'
    btn_select_all    = 'Выбрать все'
    btn_clear_all     = 'Снять все'
    btn_toggle_on     = 'Включить отмеченные'
    btn_toggle_off    = 'Отключить отмеченные'
    status_disabled_deps = 'Отключил: {0} — вместе с ними зависимые: {1}. Бэкап: {2}'
    btn_browse        = 'Указать папку Steam...'
    btn_zomboid       = 'Указать папку Zomboid...'
    lbl_saves         = 'Сейвы (Zomboid\Saves) — выбран последний'
    lbl_steam         = 'Папка Steam (найдена автоматически)'
    lbl_details       = 'Детали'
    lbl_game          = 'Папка игры'
    status_ready      = 'Готово'
    status_scan       = 'Сканирую...'
    status_saved      = 'Сейв обновлён. Бэкап: {0}'
    status_checked    = 'Проверка завершена — проблем: {0}'
    msg_no_steam      = 'Steam не найден — укажите папку вручную'
    msg_no_save       = 'Сначала выберите сейв'
    msg_no_sel        = 'Сначала отметьте галочкой строки в таблице'
    msg_no_items      = 'Сначала выполните сканирование'
    msg_marked        = 'Отмечено строк: {0}'
    msg_no_steam_local = 'Steam не найден — показываю локальные моды и сейвы'
    msg_local_added   = 'Локальные моды (Zomboid\mods): {0}'
    msg_no_saves      = 'Сейвы не найдены'
    auto_steam        = 'Steam найден: {0}'
    auto_save         = 'Сейв выбран автоматически (последний по дате): {0}'
    err_line          = 'Ошибка: {0}'
    err_title         = 'Ошибка'
    no_modinfo        = '(без mod.info)'
    st_active         = 'да'
    st_no             = '—'
    st_status_active  = '✓ работает'
    st_status_orphan  = '⚠ отключён'
    st_quarantine     = '✗ карантин игры'
    st_noinfo         = '✗ битая загрузка'
    st_content        = '◆ контент-пак'
    content_name      = 'Контент (карты/ассеты без mod.info)'
    st_nosave         = '— сейв не найден'
    col_link          = 'Ссылка'
    col_link_open     = 'открыть ↗'
    fl_dup            = 'дубликат'
    wid_local         = '(локальный)'
    msg_no_game       = 'Папка игры не найдена (моды работают всё равно)'
    cli_header        = 'СПИСОК МОДОВ PROJECT ZOMBOID — {0}'
    cli_intro         = 'Всего папок Workshop: {0}'
    cli_save_note     = 'Сейв: {0}'
    cli_conflicts     = 'КОНФЛИКТЫ И ПРОБЛЕМЫ ({0})'
    cli_none          = 'Конфликтов и проблем не найдено.'
    cli_totals        = 'Итого: работает {0} · не включён {1} · карантин {2} · битые {3} · проблем {4} · контент-паков {5}'
    cli_exported      = 'Экспортировано: {0}'
    cli_no_items      = 'Папки Workshop не найдены (steamapps\workshop\content\108600).'
    cli_outfile_req   = 'Для -Export укажите -OutFile <файл>.'
    cli_game          = 'Игра: {0}'
    cli_game_no       = 'Папка игры не найдена'
    cli_quar_found    = 'Карантин игры: {0} папок. Запустите с -CleanQuarantine, чтобы удалить их.'
    cli_quar_none     = 'Папок карантина нет.'
    cli_quar_cleaned  = 'Карантин очищен: удалено {0} папок ({1}).'
    cli_save_none     = 'Сейвы не найдены: статусы «работает / не включён» недоступны. Если папка Zomboid нестандартная — укажите её (кнопка «Указать папку Zomboid...» или параметр -ZomboidDir).'
    cli_local_note    = 'Локальные моды (без Steam): {0}'
    cli_no_items_any  = 'Ни модов Workshop, ни локальных модов не найдено.'
    cli_opt_title     = 'ОПТИМИЗАЦИЯ ПОД ВАШ КОМПЬЮТЕР'
    cli_opt_done      = 'Готово. Каждый шаг выполнен с резервной копией.'
    cli_autofix_title = 'АВТОПОЧИНКА'
    cli_autofix_before= 'Проблем до автопочинки: {0}'
    cli_autofix_after = 'Проблем после автопочинки: {0}'
    cli_autofix_quar  = 'Удалено карантинных папок: {0} ({1})'
    cli_autofix_broken= 'Удалено битых папок (без mod.info): {0} ({1}) — Steam скачает их заново'
    cli_autofix_save  = 'Сейв «{0}»: добавлено модов {1} (бэкап: {2})'
    cli_autofix_none  = 'Автопочинка не требовалась — проблем нет.'
    cli_autofix_dl    = 'Недостающие моды: нашёл в Мастерской {0} из {1} — открыл страницы для подписки:'
    cli_autofix_dlnone = 'Мод «{0}» не нашёлся в Мастерской — поищите вручную: {1}'
    cli_autofix_disable = 'Мод «{0}» не нашёлся в Мастерской — отключил в сейвах: {1}'
    f_dup             = 'modID «{0}» встречается в нескольких предметах Workshop: {1} — это конфликт'
    f_noinfo          = 'Предмет {0} без mod.info — битая или неполная загрузка; кнопка «Исправить всё» удалит папку, и Steam скачает предмет заново'
    f_quar            = 'Папка {0} переименована игрой (карантин) — мод выключен'
    f_notinstalled    = 'Сейв просит мод «{0}», но он не установлен — при исправлении скачаю его из Мастерской'
    f_reqmissing      = 'Моду «{0}» нужен мод «{1}», а он не установлен'
    f_reqnotsave      = 'Моду «{0}» нужен мод «{1}» — он установлен, но не включён'
 # --- одна кнопка «Проверить и исправить», всё в одном окне ---
    sp_title_ok       = 'Всё в порядке!'
    sp_title_bad      = 'Найдено проблем: {0}'
    sp_stats          = 'Модов: {0}    Сейвов: {1}    Проблем: {2}'
    sp_detail_ok      = 'Конфликтов, карантина и битых модов не найдено.'
    sp_fixed_line     = 'Исправлено: проблем {0} → {1} · восстановлено модов в сейвы: {2}'
    sp_no_items       = 'Моды не найдены: подпишитесь на моды в Мастерской Steam и нажмите «1. Проверить и исправить».'
    wiz_welcome       = 'Первый запуск — всё сделаю сам'
    wiz_sub           = 'Найду игру, Steam, моды и сейвы, проверю и предложу исправить. От вас — максимум одна кнопка.'
    wiz_noitems       = 'Моды не найдены'
    step_scan1        = 'Шаг 1/3 — ищу Steam, игру и моды...'
    step_scan2        = 'Шаг 2/3 — проверяю моды, сейвы и совместимость...'
    step_scan3        = 'Шаг 3/3 — считаю проблемы...'
    state_scanning    = 'Идёт проверка...'
    idle_title        = 'Готов к проверке'
    idle_sub          = 'Нажмите «1. Проверить и исправить» — найду Steam, моды и сейвы, проверю и предложу исправить.'
    state_fixing      = 'Идёт исправление...'
    action_fix        = 'Исправить всё автоматически'
    action_recheck    = 'Проверить ещё раз'
    skip              = 'Пропустить'
    quar_confirm      = 'Игра сама отключила {0} мод(ов) и переименовала их папки:{1}{2}Удалить их? Steam скачает предметы заново, и моды вернутся целыми.'
    quar_yes          = 'Удалить {0} папок — Steam скачает заново'
    broken_confirm    = '{0} предмет(ов) скачались без mod.info — это битые или неполные загрузки:{1}{2}Удалить их? Steam скачает их заново при следующем запуске.'
    broken_yes        = 'Удалить {0} битых папок'
    quar_removed      = 'Карантин: удалено папок {0} ({1})'
    broken_removed    = 'Битые предметы: удалено папок {0} ({1}) — Steam скачает их заново'
    wiz_save_fixed    = 'Сейв «{0}»: восстановлено модов {1} (бэкап: {2})'
    done_clean        = 'Всё исправлено. Проблем нет!'
    done_title        = 'Готово! Проблем: {0} → {1}'
    done_left         = 'Осталось проблем: {0} — {1}.'
    left_dup          = 'дубликаты модов ({0}): оставьте один из двух — список в «2. Ручное управление модами»'
    left_miss         = 'не хватает модов ({0}): страницы подписки открыты в Steam — подпишитесь и снова «1. Проверить и исправить»; то, чего в Мастерской нет вообще, уже отключено в сейвах'
    left_notinst      = 'в сейвах упомянуты моды, которых нет на диске ({0}) — их страницы тоже открыты'
    left_other        = 'остальное — в списке выше ({0})'
    done_nosaves      = 'Сейвы не найдены — укажите папку Zomboid, чтобы статусы заработали.'
    ws_fetching       = 'Загружаю описания из Мастерской Steam...'
    ws_fetched        = 'Описания Мастерской: получено {0} из {1}'
    fun_text          = 'УЛИЦА ЧИСТА — ВЫ ВЫЖИЛИ!'
    fun_sub           = 'моды проверены — проблем нет'
    fun_note_fixed    = 'исправлено проблем: {0} → 0 · модов возвращено в сейвы: {1}'
    fun_note_nosaves  = 'сейвы не нашлись — моды в порядке; папку Zomboid можно указать кнопкой ниже'
    scene_died        = 'ВЫ ПОГИБЛИ...'
    scene_fixed       = 'исправлено проблем: {0} → {1}'
    scene_shield      = 'Внутренняя ошибка перехвачена — программа продолжает работать: {0}'
    step_failed       = 'Шаг «{0}» прерван (строка {2}): {1}'
 # --- автоскачивание недостающих модов ---
    miss_searching    = 'Ищу недостающие моды в Мастерской Steam...'
    miss_found        = 'Мод «{0}» не установлен — нашёл в Мастерской: «{1}». Открыл страницу — нажмите «Подписаться», Steam скачает его сам.'
    miss_found_wid    = 'Предмет Мастерской «{0}» из сейва не установлен — открыл страницу, нажмите «Подписаться».'
    miss_notfound     = 'Мод «{0}» не установлен и точно не нашёлся — открыл поиск Мастерской, найдите похожий и подпишитесь.'
    miss_opened       = 'Открыл страниц: {0} — нажмите «Подписаться» в каждой. Программа сама заметит загрузку и продолжит проверку.'
    miss_watch        = 'Жду загрузку из Steam...'
    miss_disabled     = 'Мод «{0}» не нашёлся в Мастерской — отключил в сейвах моды, которым он нужен: {1} (бэкап сохранён).'
    miss_save_disabled = 'Сейв «{0}»: список модов переписан (бэкап: {1})'
    miss_disable_done = 'Отключил моды с недостижимыми зависимостями — перепроверил: проблем {0}.'
    scene_checked     = 'проверено: проблем {0}'
    scene_optimized   = 'оптимизация завершена'
    scene_err         = '(улица не завелась: {0})'
 # --- оптимизация: программа делает всё сама, а не советует ---
    opt_title         = 'Оптимизация под ваш компьютер'
    opt_sys_cpu       = 'Процессор: {0} ({1} потоков)'
    opt_sys_ram       = 'Память: {0} ГБ · Видеокарта: {1}'
    opt_ram           = 'Память: {0} ГБ · Потоки CPU: {1}'
    opt_plan_head     = 'Программа сделает всё сама:'
    opt_plan_json     = '• выделит игре больше памяти — поправит файл ProjectZomboid64.json в папке игры (с бэкапом);'
    opt_plan_launch   = '• пропишет параметры запуска в настройках Steam — вступят в силу при следующем запуске Steam;'
    opt_plan_logs     = '• вычистит старые логи крашей и ужмёт подросший console.txt.'
    opt_do            = 'Оптимизировать сейчас'
    opt_rollback      = 'Вернуть как было'
    opt_log_head      = 'Вот что сделано:'
    opt_xmx_set       = 'Память игры: {0} → {1} МБ (бэкап: {2})'
    opt_xmx_same      = 'Память игры уже оптимальна: {0} МБ'
    opt_json_missing  = 'В папке игры нет ProjectZomboid64.json — память не меняю'
    opt_launch_set    = 'Параметры запуска Steam записаны: {0}'
    opt_launch_same   = 'Параметры запуска Steam уже оптимальны'
    opt_launch_skip   = 'Внимание: Steam сейчас запущен и может перезаписать параметры при закрытии — запустите оптимизацию ещё раз, когда Steam закрыт.'
    opt_logs_cleaned  = 'Вычищено старых логов: {0} ({1})'
    opt_console_trim  = 'console.txt ужат: {0} МБ → 0 (старый сохранён как console.old.txt)'
    opt_no_game       = 'Папка игры не найдена — память игры не меняю'
    opt_no_steam      = 'Steam не найден — параметры запуска не пишу'
    opt_back_done     = 'Всё возвращено как было (из резервных копий)'
    opt_back_none     = 'Откатывать нечего: в этом запуске ничего не менялось'
 # --- описания из Мастерской в деталях ---
    ws_desc_title     = '— Из Мастерской —'
    ws_meta           = 'Теги: {0} · {1} МБ · обновлён {2}'
    ws_name           = 'Название'
    ws_none           = '(описание ещё не загрузилось — появится после загрузки из Steam)'
}
$Script:L10N['EN'] = @{
    tagline           = 'Workshop mod diagnostics for Project Zomboid'
    footer            = 'Unofficial community tool. Not affiliated with The Indie Stone or Valve.'
    col_sel           = '✓'
    col_num           = 'No'
    col_name          = 'Mod name'
    col_ids           = 'modID'
    col_wid           = 'WorkshopID'
    col_status        = 'Status'
    btn_main          = '1. Check & fix'
    btn_manual        = '2. Manual mod management'
    btn_manual_hide   = '× Hide the table'
    btn_opt           = '3. Optimize the game'
    btn_select_all    = 'Select all'
    btn_clear_all     = 'Clear all'
    btn_toggle_on     = 'Enable checked'
    btn_toggle_off    = 'Disable checked'
    status_disabled_deps = 'Disabled: {0} - dependents followed: {1}. Backup: {2}'
    btn_browse        = 'Set Steam folder...'
    btn_zomboid       = 'Set Zomboid folder...'
    lbl_saves         = 'Saves (Zomboid\Saves) — newest selected'
    lbl_steam         = 'Steam folder (auto-detected)'
    lbl_details       = 'Details'
    lbl_game          = 'Game folder'
    status_ready      = 'Ready'
    status_scan       = 'Scanning...'
    status_saved      = 'Save updated. Backup: {0}'
    status_checked    = 'Check complete — issues: {0}'
    msg_no_steam      = 'Steam not found — set the folder manually'
    msg_no_save       = 'Select a save first'
    msg_no_sel        = 'Tick the rows in the table first'
    msg_no_items      = 'Run a scan first'
    msg_marked        = 'Rows ticked: {0}'
    msg_no_steam_local = 'Steam not found - showing local mods and saves'
    msg_local_added   = 'Local mods (Zomboid\mods): {0}'
    msg_no_saves      = 'No saves found'
    auto_steam        = 'Steam found: {0}'
    auto_save         = 'Save auto-selected (newest): {0}'
    err_line          = 'Error: {0}'
    err_title         = 'Error'
    no_modinfo        = '(no mod.info)'
    st_active         = 'yes'
    st_no             = '-'
    st_status_active  = '✓ works'
    st_status_orphan  = '⚠ disabled'
    st_quarantine     = '✗ game quarantine'
    st_noinfo         = '✗ broken download'
    st_content        = '◆ content pack'
    content_name      = 'Content (maps/assets without mod.info)'
    st_nosave         = '— no save found'
    col_link          = 'Link'
    col_link_open     = 'open ↗'
    fl_dup            = 'dup'
    wid_local         = '(local)'
    msg_no_game       = 'Game folder not found (mods still work)'
    cli_header        = 'PROJECT ZOMBOID MOD LIST — {0}'
    cli_intro         = 'Workshop folders total: {0}'
    cli_save_note     = 'Save: {0}'
    cli_conflicts     = 'CONFLICTS AND PROBLEMS ({0})'
    cli_none          = 'No conflicts or problems found.'
    cli_totals        = 'Totals: works {0} · not enabled {1} · quarantined {2} · broken {3} · issues {4} · content packs {5}'
    cli_exported      = 'Exported: {0}'
    cli_no_items      = 'No Workshop content found (steamapps\workshop\content\108600).'
    cli_outfile_req   = '-Export requires -OutFile <file>.'
    cli_game          = 'Game: {0}'
    cli_game_no       = 'Game folder not found'
    cli_quar_found    = 'Game quarantine: {0} folders. Run with -CleanQuarantine to delete them.'
    cli_quar_none     = 'No quarantined folders.'
    cli_quar_cleaned  = 'Quarantine cleaned: removed {0} folders ({1}).'
    cli_save_none     = 'No saves found: "works / not enabled" statuses are unavailable. If your Zomboid folder is non-standard, set it ("Set Zomboid folder..." button or -ZomboidDir).'
    cli_local_note    = 'Local mods (no Steam): {0}'
    cli_no_items_any  = 'No Workshop or local mods found.'
    cli_opt_title     = 'OPTIMIZATION FOR YOUR SYSTEM'
    cli_opt_done      = 'Done. Every step performed with a backup copy.'
    cli_autofix_title = 'AUTO-FIX'
    cli_autofix_before= 'Problems before auto-fix: {0}'
    cli_autofix_after = 'Problems after auto-fix: {0}'
    cli_autofix_quar  = 'Quarantine folders removed: {0} ({1})'
    cli_autofix_broken= 'Broken folders (no mod.info) removed: {0} ({1}) - Steam will re-download them'
    cli_autofix_save  = 'Save "{0}": mods added {1} (backup: {2})'
    cli_autofix_none  = 'Auto-fix was not needed - no problems.'
    cli_autofix_dl    = 'Missing mods: found {0} of {1} in the Workshop - opened the pages to subscribe:'
    cli_autofix_dlnone = 'Mod "{0}" was not found in the Workshop - look it up manually: {1}'
    cli_autofix_disable = 'Mod "{0}" was not found in the Workshop - disabled in the saves: {1}'
    f_dup             = 'modID "{0}" is declared by several Workshop items: {1} - this is a conflict'
    f_noinfo          = 'Item {0} has no mod.info - a broken or incomplete download; the "Fix everything" button removes the folder and Steam re-downloads the item'
    f_quar            = 'Folder {0} was renamed by the game (quarantine) - the mod is off'
    f_notinstalled    = 'The save wants mod "{0}" but it is not installed - the fix fetches it from the Workshop'
    f_reqmissing      = 'Mod "{0}" needs mod "{1}" which is not installed'
    f_reqnotsave      = 'Mod "{0}" needs mod "{1}" which is installed but not enabled'
 # --- one "Check & fix" button, everything inside one window ---
    sp_title_ok       = 'Everything is fine!'
    sp_title_bad      = 'Problems found: {0}'
    sp_stats          = 'Mods: {0}    Saves: {1}    Problems: {2}'
    sp_detail_ok      = 'No conflicts, quarantine or broken mods found.'
    sp_fixed_line     = 'Fixed: problems {0} -> {1} · mods restored into saves: {2}'
    sp_no_items       = 'No mods found: subscribe to mods in the Steam Workshop and press "1. Check & fix" again.'
    wiz_welcome       = 'First launch - I will do everything myself'
    wiz_sub           = 'I will find the game, Steam, mods and saves, check them and offer to fix everything. You press one button at most.'
    wiz_noitems       = 'No mods found'
    step_scan1        = 'Step 1/3 - looking for Steam, the game and mods...'
    step_scan2        = 'Step 2/3 - checking mods, saves and compatibility...'
    step_scan3        = 'Step 3/3 - counting problems...'
    state_scanning    = 'Checking...'
    idle_title        = 'Ready to check'
    idle_sub          = 'Press "1. Check and fix" - I will find Steam, the mods and the saves, check them and offer to fix everything.'
    state_fixing      = 'Fixing...'
    action_fix        = 'Fix everything automatically'
    action_recheck    = 'Check again'
    skip              = 'Skip'
    quar_confirm      = 'The game itself disabled {0} mod(s) and renamed their folders:{1}{2}Delete them? Steam will re-download the items, and the mods come back whole.'
    quar_yes          = 'Delete {0} folders - Steam re-downloads them'
    broken_confirm    = '{0} item(s) downloaded without any mod.info - broken or incomplete downloads:{1}{2}Delete them? Steam re-downloads them on the next start.'
    broken_yes        = 'Delete {0} broken folders'
    quar_removed      = 'Quarantine: removed folders {0} ({1})'
    broken_removed    = 'Broken items: removed folders {0} ({1}) - Steam will re-download them'
    wiz_save_fixed    = 'Save "{0}": restored mods {1} (backup: {2})'
    done_clean        = 'All fixed. No problems left!'
    done_title        = 'Done! Problems: {0} -> {1}'
    done_left         = 'Problems left: {0} - {1}.'
    left_dup          = 'mod duplicates ({0}): keep one of the two - the list is in "2. Manual mod management"'
    left_miss         = 'missing mods ({0}): the subscribe pages are open in Steam - subscribe and press "1. Check and fix" again; what is not in the Workshop at all is already disabled in the saves'
    left_notinst      = 'saves mention mods that are not on disk ({0}) - their pages are open too'
    left_other        = 'the rest are listed above ({0})'
    done_nosaves      = 'No saves found - set the Zomboid folder so the statuses start working.'
    ws_fetching       = 'Fetching descriptions from the Steam Workshop...'
    ws_fetched        = 'Workshop descriptions: received {0} of {1}'
    fun_text          = 'THE STREET IS CLEAN — YOU SURVIVED!'
    fun_sub           = 'mods checked - no problems found'
    fun_note_fixed    = 'problems fixed: {0} -> 0 · mods restored into saves: {1}'
    fun_note_nosaves  = 'saves were not found - the mods are fine; the Zomboid folder can be set with the button below'
    scene_died        = 'YOU DIED...'
    scene_fixed       = 'problems fixed: {0} -> {1}'
    scene_shield      = 'An internal error was caught - the program keeps running: {0}'
    step_failed       = 'Step "{0}" was interrupted (line {2}): {1}'
 # --- auto-downloading the missing mods ---
    miss_searching    = 'Looking up the missing mods in the Steam Workshop...'
    miss_found        = 'Mod "{0}" is not installed - found in the Workshop: "{1}". The page is open - press Subscribe and Steam downloads it.'
    miss_found_wid    = 'Workshop item "{0}" from the save is not installed - the page is open, press Subscribe.'
    miss_notfound     = 'Mod "{0}" is not installed and could not be identified for sure - the Workshop search page is open, find a matching mod and subscribe.'
    miss_opened       = 'Pages opened: {0} - press Subscribe in each. The program notices the download by itself and continues the check.'
    miss_watch        = 'Waiting for the Steam download...'
    miss_disabled     = 'Mod "{0}" was not found in the Workshop - disabled the mods that need it in the saves: {1} (backup kept).'
    miss_save_disabled = 'Save "{0}": the mod list was rewritten (backup: {1})'
    miss_disable_done = 'Disabled the mods with unreachable requirements - re-checked: {0} problems left.'
    scene_checked     = 'checked: {0} problems'
    scene_optimized   = 'optimization complete'
    scene_err         = '(the street would not start: {0})'
 # --- optimization: the program does everything itself ---
    opt_title         = 'Optimization for your PC'
    opt_sys_cpu       = 'CPU: {0} ({1} threads)'
    opt_sys_ram       = 'RAM: {0} GB · GPU: {1}'
    opt_ram           = 'RAM: {0} GB · CPU threads: {1}'
    opt_plan_head     = 'The program does everything itself:'
    opt_plan_json     = '• gives the game more memory - patches ProjectZomboid64.json in the game folder (with a backup);'
    opt_plan_launch   = '• writes the launch options into Steam settings - they take effect on the next Steam start;'
    opt_plan_logs     = '• cleans old crash logs and trims an overgrown console.txt.'
    opt_do            = 'Optimize now'
    opt_rollback      = 'Roll everything back'
    opt_log_head      = 'Here is what was done:'
    opt_xmx_set       = 'Game memory: {0} -> {1} MB (backup: {2})'
    opt_xmx_same      = 'Game memory is already optimal: {0} MB'
    opt_json_missing  = 'No ProjectZomboid64.json in the game folder - memory untouched'
    opt_launch_set    = 'Steam launch options written: {0}'
    opt_launch_same   = 'Steam launch options are already optimal'
    opt_launch_skip   = 'Note: Steam is running right now and may overwrite the options on exit - run the optimization again while Steam is closed.'
    opt_logs_cleaned  = 'Old logs cleaned: {0} ({1})'
    opt_console_trim  = 'console.txt trimmed: {0} MB -> 0 (the old one kept as console.old.txt)'
    opt_no_game       = 'Game folder not found - game memory untouched'
    opt_no_steam      = 'Steam not found - launch options not written'
    opt_back_done     = 'Everything rolled back (from the backup copies)'
    opt_back_none     = 'Nothing to roll back: nothing was changed in this run'
 # --- Workshop descriptions in details ---
    ws_desc_title     = '— From the Workshop —'
    ws_meta           = 'Tags: {0} · {1} MB · updated {2}'
    ws_name           = 'Title'
    ws_none           = '(description not loaded yet - appears once Steam answers)'
}
function Get-T([string]$Key) {
    if ($Script:L10N.ContainsKey($Script:Lang)) {
        $t = $Script:L10N[$Script:Lang]
        if ($t.ContainsKey($Key)) { return $t[$Key] }
    }
    return $Key
}

function Get-NormalizedModId([string]$Id) {
 # mod.info files written by different tools disagree on decoration: some
 # ids and require= entries carry a leading backslash ("\damnlib"), stray
 # quotes or spaces. The game tolerates that; exact string comparison does
 # not - and that mismatch is exactly why "fixed" problems kept coming
 # back and why installed mods were reported as missing.
    if (-not $Id) { return '' }
    $t = ([string]$Id).Trim()
    $t = $t -replace '^[\\/"]+', '' -replace '[\\/"]+$', ''
    return $t.Trim()
}

function Limit-Text([string]$Text, [int]$Max) {
    if ($null -eq $Text) { return '' }
    if ($Text.Length -le $Max) { return $Text }
    if ($Max -le 3) { return $Text.Substring(0, $Max) }
    return $Text.Substring(0, $Max - 3) + '...'
}

function Clean-Tsv([string]$Text) {
    if ($null -eq $Text) { return '' }
    return ($Text -replace "\t", ' ') -replace "\r?\n", ' '
}

function Get-Seq($Value) {
 # Bullet-proof enumeration for Windows PowerShell 5.1: never routes a .NET
 # collection through the "@()" binder (which can throw "Argument types do
 # not match" inside WPF event handlers). Always returns a plain [object[]]
 # (the leading comma keeps 0- and 1-element arrays from being unwrapped
 # by the pipeline).
    if ($null -eq $Value) { return , [object[]]@() }
    if ($Value -is [object[]]) { return , $Value }
    if ($Value -is [string]) { return , [object[]]@($Value) }
    $enumerable = $Value -as [System.Collections.IEnumerable]
    if ($null -ne $enumerable) {
        $out = [System.Collections.Generic.List[object]]::new()
        $en = $enumerable.GetEnumerator()
        while ($en.MoveNext()) { $out.Add([object]$en.Current) }
        return , $out.ToArray()
    }
    $single = [System.Collections.Generic.List[object]]::new()
    $single.Add([object]$Value)
    return , $single.ToArray()
}

function Normalize-Items($Value) {
 # armor: whatever a discovery phase really produced - a $null
 # leaked into the pipeline by some bare .NET call, an array riding
 # inside the return value, an empty pipeline - the Items list must
 # become a flat object[] of mod hashtables and nothing else. One bad
 # element used to cost the whole grid ("mods are not shown") and then
 # the analysis round ("line 1033: Cannot index into a null array").
    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($x in (Get-Seq $Value)) {
        if ($null -eq $x) { continue }
        if ($x -is [hashtable]) { $out.Add($x); continue }
 # a nested collection of items (the workshop array itself, a List,
 # an object[] someone concatenated the wrong way) is flattened one
 # level deep; anything else is not an item and is dropped quietly
        foreach ($y in (Get-Seq $x)) {
            if ($null -ne $y -and $y -is [hashtable]) { $out.Add($y) }
        }
    }
    return , [object[]]$out.ToArray()
}

# =============================================================================
# File helpers (BOM / UTF-8 / ANSI aware — keeps Cyrillic readable)
# =============================================================================
function Read-TextSmart([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }
    if ($bytes.Length -eq 0) { return '' }
    $strict = New-Object System.Text.UTF8Encoding($false, $true)
    try { return $strict.GetString($bytes) }
    catch {
 # Not valid UTF-8. Russian mod.info files from Windows are usually
 # CP1251 regardless of the system locale — try it before the ANSI
 # code page, so Cyrillic survives on non-Russian Windows too.
        $hasHiByte = $false
        foreach ($b in $bytes) { if ($b -ge 0xC0) { $hasHiByte = $true; break } }
        if ($hasHiByte) {
            try { return [System.Text.Encoding]::GetEncoding(1251).GetString($bytes) } catch { }
        }
        return [System.Text.Encoding]::Default.GetString($bytes)
    }
}

function Parse-ModInfo([string]$Path) {
    $props = @{}
    $props['Name'] = ''
    $props['Id'] = ''
    $props['Poster'] = ''
    $props['Pack'] = ''
    $props['Description'] = ''
    $props['Url'] = ''
    $props['Requires'] = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ((Read-TextSmart $Path) -split "`r?`n")) {
        if ($line -match '^\s*(\w+)\s*=\s*(.*)$') {
            $k = $Matches[1].ToLower()
            $v = $Matches[2].Trim()
            switch ($k) {
                'name'        { $props['Name'] = $v }
                'id'          { if ($v) { $props['Id'] = Get-NormalizedModId $v } }
 # some hand-edited and tool-generated mod.info files
 # spell the same field "modID=" (the wiki documents "id=");
 # accept both so such mods stop looking id-less
                'modid'       { if ($v -and -not $props['Id']) { $props['Id'] = Get-NormalizedModId $v } }
                'poster'      { $props['Poster'] = $v }
                'pack'        { $props['Pack'] = $v }
                'description' { if (-not $props['Description']) { $props['Description'] = $v } }
                'url'         { $props['Url'] = $v }
                'require'     { if ($v) { foreach ($r0 in ($v -split '[ ,]+')) { $r = Get-NormalizedModId $r0; if ($r) { if (-not $props['Requires'].Contains($r)) { $props['Requires'].Add($r) } } } } }
            }
        }
    }
    if (-not $props['Name']) {
        $props['Name'] = Split-Path -Leaf (Split-Path -Parent $Path)
    }
    return $props
}

# =============================================================================
# Steam / Workshop discovery — fully automatic
# =============================================================================
function Find-SteamRoot([string]$Hint) {
 # Order: explicit hint -> registry -> running Steam process -> classic
 # locations -> a quick sweep over every filesystem drive root.
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($Hint) { $candidates.Add($Hint) }
    foreach ($k in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $p = (Get-ItemProperty -Path $k -ErrorAction Stop).InstallPath
            if ($p) { $candidates.Add([string]$p) }
        } catch { }
    }
    try {
        $proc = Get-Process -Name 'steam' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proc -and $proc.Path) { $candidates.Add([string](Split-Path -Parent $proc.Path)) }
    } catch { }
    if (${env:ProgramFiles(x86)}) { $candidates.Add("${env:ProgramFiles(x86)}\Steam") }
    if ($env:ProgramFiles) { $candidates.Add("$env:ProgramFiles\Steam") }
    foreach ($c in @('C:\Steam', 'C:\Games\Steam', 'C:\Program Files\Steam', 'D:\Steam', 'D:\Games\Steam', 'E:\Steam', 'E:\Games\Steam', 'F:\Steam', 'F:\Games\Steam', 'G:\Steam', 'G:\Games\Steam')) {
        $candidates.Add($c)
    }
    try {
        foreach ($d in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
            $root = [string]$d.Root
            if (-not $root) { continue }
            foreach ($sub in @('Steam', 'Games\Steam', 'Program Files\Steam', 'Program Files (x86)\Steam', 'SteamLibrary', 'Games\SteamLibrary', 'Игры\Steam')) {
                $candidates.Add((Join-Path $root $sub))
            }
        }
    } catch { }
    $seen = [System.Collections.Generic.List[string]]::new()
    foreach ($c in $candidates) {
        if (-not $c) { continue }
        $c2 = [string]$c
 # a relative hint (".\Steam") must not create a second copy of the
 # same library - normalize every candidate to a full path first
        try { $c2 = [System.IO.Path]::GetFullPath($c2) } catch { }
        if ($seen.Contains($c2)) { continue }
        $seen.Add($c2)
        try {
 # A valid Steam root has either the library index (vdf) or actual
 # Workshop content - the second check accepts standalone
 # "SteamLibrary" drives that have no libraryfolders.vdf of their own.
 # -ErrorAction SilentlyContinue keeps classic "C:\..." candidates
 # quiet on non-Windows hosts where those drives do not exist.
            $vdfPath = Join-Path $c2 'steamapps\libraryfolders.vdf' -ErrorAction SilentlyContinue
            $wsPath  = Join-Path $c2 'steamapps\workshop\content\108600' -ErrorAction SilentlyContinue
            if (($vdfPath -and (Test-Path -LiteralPath $vdfPath)) -or
                ($wsPath -and (Test-Path -LiteralPath $wsPath))) { return $c2 }
        } catch { }
    }
    return $null
}

function Get-SteamLibraries([string]$SteamRoot) {
    $libs = [System.Collections.Generic.List[string]]::new()
    $libs.Add($SteamRoot)
    $vdf = Join-Path $SteamRoot 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
        foreach ($m in [regex]::Matches((Read-TextSmart $vdf), '"path"\s+"([^"]+)"')) {
            $p = $m.Groups[1].Value -replace '\\\\', '\'
 # full-path normalization: the same library listed once via a
 # relative path and once via an absolute one is ONE library
            try { $p = [System.IO.Path]::GetFullPath($p) } catch { }
            if ($p -and (Test-Path -LiteralPath $p) -and -not $libs.Contains($p)) { $libs.Add($p) }
        }
    }
    return $libs
}

function Find-PZInstall([object[]]$Libraries) {
 # Where the game itself lives. Steam copies sit in
 # <library>\steamapps\common\ProjectZomboid; non-Steam copies (GOG,
 # hand-placed folders) are probed via the usual install paths on every
 # drive. Informational only: mods and saves work even without the game.
    $cands = [System.Collections.Generic.List[string]]::new()
    foreach ($lib in $Libraries) {
        if ($lib) { $cands.Add((Join-Path ([string]$lib) ('steamapps' + [IO.Path]::DirectorySeparatorChar + 'common' + [IO.Path]::DirectorySeparatorChar + 'ProjectZomboid'))) }
    }
    if (${env:ProgramFiles(x86)}) { $cands.Add("${env:ProgramFiles(x86)}\Project Zomboid") }
    if ($env:ProgramFiles) {
        $cands.Add("$env:ProgramFiles\Project Zomboid")
        $cands.Add("$env:ProgramFiles\GOG Games\Project Zomboid")
    }
    foreach ($c in @('C:\GOG Games\Project Zomboid', 'C:\Games\Project Zomboid', 'D:\GOG Games\Project Zomboid', 'D:\Games\Project Zomboid', 'E:\Games\Project Zomboid', 'F:\Games\Project Zomboid')) {
        $cands.Add($c)
    }
    try {
        foreach ($d in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
            $root = [string]$d.Root
            if (-not $root) { continue }
            foreach ($sub in @('Project Zomboid', 'Games\Project Zomboid', 'GOG Games\Project Zomboid', 'Игры\Project Zomboid')) {
                $cands.Add((Join-Path $root $sub -ErrorAction SilentlyContinue))
            }
        }
    } catch { }
    foreach ($c in $cands) {
        if (-not $c) { continue }
        try { if (Test-Path -LiteralPath $c) { return [string]$c } } catch { }
    }
    return $null
}

function Get-WorkshopUrl([string]$WorkshopId) {
    if ($WorkshopId -match '^\d+$') {
        return ('https://steamcommunity.com/sharedfiles/filedetails/?id={0}' -f $WorkshopId)
    }
    return ''
}


# =============================================================================
# Zomboid folder discovery (the classic reason for "no save found" is a
# Zomboid folder that is not %USERPROFILE%\Zomboid - custom -cachedir launch
# option, a profile on another drive, a moved folder. The root is now found
# everywhere, remembered in the settings and can be pointed at manually.)
# =============================================================================
$Script:ZomboidRootCache = ''

function Find-ZomboidOnDrives([string[]]$Roots) {
 # Quick, bounded sweep: Zomboid folders live either right on a drive
 # root, under \Users\<name>\ or under a Games/PZ folder. Only folders
 # that actually contain Saves count - anything else is noise.
    $cands = [System.Collections.Generic.List[string]]::new()
    foreach ($r in $Roots) {
        if (-not $r) { continue }
        try {
            $cands.Add((Join-Path $r 'Zomboid'))
            $cands.Add((Join-Path $r 'Games\Zomboid'))
            $cands.Add((Join-Path $r 'PZ\Zomboid'))
            $users = Join-Path $r 'Users'
            if (Test-Path -LiteralPath $users) {
                foreach ($u in (Get-ChildItem -LiteralPath $users -Directory -ErrorAction SilentlyContinue)) {
                    $cands.Add((Join-Path $u.FullName 'Zomboid'))
                }
            }
        } catch { }
    }
    foreach ($c in $cands) {
        if (-not $c) { continue }
        try { if (Test-Path -LiteralPath (Join-Path $c 'Saves')) { return [string]$c } } catch { }
    }
    foreach ($c in $cands) {
        if (-not $c) { continue }
        try { if (Test-Path -LiteralPath (Join-Path $c 'mods')) { return [string]$c } } catch { }
    }
    return $null
}

function Get-ZomboidRoot {
 # Priority: explicit -ZomboidDir / user pick -> saved setting ->
 # %USERPROFILE%\Zomboid -> the -cachedir launch option from Steam ->
 # a sweep over every drive root. The result is cached for the run.
    if ($Script:ZomboidDir) { return [string]$Script:ZomboidDir }
    if ($Script:ZomboidRootCache) { return [string]$Script:ZomboidRootCache }
    $root = $null
    try {
        $st = Read-Settings
        if ($st -and $st.zomboidDir) {
            $zd = [string]$st.zomboidDir
            if ($zd -and (Test-Path -LiteralPath $zd)) { $root = $zd }
        }
    } catch { }
    if (-not $root) {
        try {
            $def = Join-Path $env:USERPROFILE 'Zomboid'
            if (Test-Path -LiteralPath $def) { $root = $def }
        } catch { }
    }
    if (-not $root) {
        try {
            $cd = Get-CachedirFromSteamLaunchOptions
            if ($cd -and (Test-Path -LiteralPath $cd)) { $root = $cd }
        } catch { }
    }
    if (-not $root) {
        try {
            $roots = [System.Collections.Generic.List[string]]::new()
            foreach ($d in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
                $r = [string]$d.Root
                if ($r) { $roots.Add($r) }
            }
            $root = Find-ZomboidOnDrives ([string[]]$roots.ToArray())
        } catch { }
    }
    if (-not $root) { $root = (Join-Path $env:USERPROFILE 'Zomboid') }
    $Script:ZomboidRootCache = [string]$root
    return [string]$root
}

function Get-SteamLaunchOptionsForPZ([string]$Hint = '') {
 # Reads the launch options Steam stores for Project Zomboid (appid
 # 108600) in every local user's userdata\*\config\localconfig.vdf.
 # Pure read: used to discover a custom -cachedir= Zomboid folder.
    $out = [System.Collections.Generic.List[string]]::new()
    $steam = $null
    try { $steam = Find-SteamRoot $Hint } catch { }
    if (-not $steam) { return , [string[]]$out.ToArray() }
    try {
        $ud = Join-Path $steam 'userdata'
        if (-not (Test-Path -LiteralPath $ud)) { return , [string[]]$out.ToArray() }
        foreach ($cfg in (Get-ChildItem -LiteralPath $ud -Filter 'localconfig.vdf' -Recurse -Depth 2 -ErrorAction SilentlyContinue)) {
            try {
                $txt = Read-TextSmart $cfg.FullName
                if ($txt -match '"108600"') {
                    $m = [regex]::Match($txt, '"108600"\s*\{([^\{\}]*)\}')
                    if ($m.Success) {
                        $lm = [regex]::Match($m.Groups[1].Value, '"LaunchOptions"\s+"([^"]*)"')
                        if ($lm.Success) { $out.Add([string]$lm.Groups[1].Value) }
                    }
                }
            } catch { }
        }
    } catch { }
    return , [string[]]$out.ToArray()
}

function Get-CachedirFromSteamLaunchOptions([string]$Hint = '') {
 # -cachedir=D:\PZData is how players move the Zomboid folder; if it is
 # set there, the saves live exactly there.
    foreach ($lo in (Get-SteamLaunchOptionsForPZ $Hint)) {
        if ($lo -match '-cachedir=("[^"]+"|[^\s"]+)') {
            $p = $Matches[1].Trim('"')
            if ($p -and (Test-Path -LiteralPath $p)) { return [string]$p }
        }
    }
    return $null
}

function Merge-LaunchOptions([string]$Existing, [int]$XmxMB) {
 # Keeps every flag the user set (most importantly -cachedir) and only
 # replaces the memory flags the optimizer owns.
    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($p in ($Existing -split '\s+')) {
        if (-not $p) { continue }
        if ($p -match '^-Xmx' -or $p -match '^-Xms') { continue }
        $parts.Add($p)
    }
    $parts.Add(('-Xmx{0}m' -f [int]$XmxMB))
    $parts.Add(('-Xms{0}m' -f [int][math]::Min(2048, $XmxMB)))
    return ($parts.ToArray() -join ' ')
}

function Set-SteamLaunchOptionsForPZ([string]$SteamRoot, [int]$XmxMB) {
 # The program writes the launch options itself (the user never
 # copies anything by hand). Every changed localconfig.vdf gets a
 # timestamped backup next to it. Existing flags survive: only the
 # -Xmx/-Xms pair is owned by the optimizer.
    $res = @{ Changed = 0; Same = 0; SteamRunning = $false; Backups = [object[]]@() }
    if (-not $SteamRoot) { return $res }
    try { if (Get-Process -Name 'steam' -ErrorAction SilentlyContinue) { $res['SteamRunning'] = $true } } catch { }
    $ud = Join-Path $SteamRoot 'userdata'
    if (-not (Test-Path -LiteralPath $ud)) { return $res }
    $backups = [System.Collections.Generic.List[object]]::new()
    $merged = Merge-LaunchOptions '' ([int]$XmxMB)
    $mergedEsc = $merged -replace '"', '\"'
    foreach ($cfg in (Get-ChildItem -LiteralPath $ud -Filter 'localconfig.vdf' -Recurse -Depth 2 -ErrorAction SilentlyContinue)) {
        try {
            $txt = Read-TextSmart $cfg.FullName
            $newTxt = $null
            $m = [regex]::Match($txt, '"108600"\s*\{([^\{\}]*)\}')
            if ($m.Success) {
                $inner = $m.Groups[1].Value
                $lm = [regex]::Match($inner, '"LaunchOptions"\s+"([^"]*)"')
                if ($lm.Success) {
                    $existing = $lm.Groups[1].Value
                    $newVal = Merge-LaunchOptions $existing ([int]$XmxMB)
                    if ($newVal -ne $existing) {
                        $newValEsc = $newVal -replace '"', '\"'
                        $newInner = $inner.Substring(0, $lm.Index) + '"LaunchOptions"' + "`t`t" + '"' + $newValEsc + '"' + $inner.Substring($lm.Index + $lm.Length)
                        $newTxt = $txt.Substring(0, $m.Groups[1].Index) + $newInner + $txt.Substring($m.Groups[1].Index + $m.Groups[1].Length)
                    }
                } else {
                    $newInner = $inner.TrimEnd() + "`r`n`t`t`t`t`t`t`t`t" + '"LaunchOptions"' + "`t`t" + '"' + $mergedEsc + '"' + "`r`n`t`t`t`t`t`t`t"
                    $newTxt = $txt.Substring(0, $m.Groups[1].Index) + $newInner + $txt.Substring($m.Groups[1].Index + $m.Groups[1].Length)
                }
            } else {
 # no 108600 entry yet: add a block right inside "apps" { ... }
                $am = [regex]::Match($txt, '"apps"\s*\{')
                if ($am.Success) {
                    $block = "`r`n`t`t`t`t`t`t`"108600`"`r`n`t`t`t`t`t`t{`r`n`t`t`t`t`t`t`t`"LaunchOptions`"`t`t`"$mergedEsc`"`r`n`t`t`t`t`t`t}"
                    $newTxt = $txt.Insert($am.Index + $am.Length, $block)
                }
            }
            if ($newTxt) {
                $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                $bak = '{0}.pzwd-bak-{1}' -f $cfg.FullName, $stamp
                Copy-Item -LiteralPath $cfg.FullName -Destination $bak -Force
                [System.IO.File]::WriteAllText($cfg.FullName, $newTxt, [System.Text.UTF8Encoding]::new($false))
                $res['Changed']++
                $backups.Add(@{ Path = [string]$cfg.FullName; Backup = [string]$bak })
            } else {
                $res['Same']++
            }
        } catch { }
    }
    $res['Backups'] = [object[]]$backups.ToArray()
    return $res
}
function Get-LocalMods([string]$ZomboidRoot) {
 # Mods installed manually into <Zomboid>\mods - the way non-Steam copies
 # (GOG, portable) and hand-installed mods work. Items are shaped exactly
 # like Workshop ones, with WorkshopId = '' so links/status stay uniform.
    $items = [System.Collections.Generic.List[object]]::new()
    if (-not $ZomboidRoot) { return , $items.ToArray() }
    $modsRoot = Join-Path $ZomboidRoot 'mods'
    if (-not (Test-Path -LiteralPath $modsRoot)) { return , $items.ToArray() }
    foreach ($dir in (Get-ChildItem -LiteralPath $modsRoot -Directory -ErrorAction SilentlyContinue)) {
 # depth 5 - hand-installed archives often unpack one or two
 # levels deeper than the game's own layout.
        $modInfoFiles = Get-ChildItem -LiteralPath $dir.FullName -Filter 'mod.info' -Recurse -Depth 5 -ErrorAction SilentlyContinue
        $mods = [System.Collections.Generic.List[object]]::new()
        foreach ($mi in $modInfoFiles) { $mods.Add((Parse-ModInfo $mi.FullName)) }
        $name = ''
        if ($mods.Count -gt 0) { $name = [string]$mods[0]['Name'] }
        $idList = [System.Collections.Generic.List[string]]::new()
        foreach ($m in $mods) {
            $mid = [string]$m['Id']
            if ($mid -and -not $idList.Contains($mid)) { $idList.Add($mid) }
        }
        $kind = 'MODS'
        if ($mods.Count -eq 0 -and (Test-ContentPack $dir.FullName)) { $kind = 'CONTENT' }
        $items.Add(@{
            WorkshopId  = ''
            Folder      = [string]$dir.FullName
            Quarantined = $false
            Broken      = ($mods.Count -eq 0 -and $kind -ne 'CONTENT')
            IsLocal     = $true
            Kind        = $kind
            Mods        = $mods.ToArray()
            ModIds      = $idList.ToArray()
            Name        = $name
        })
    }
    return , $items.ToArray()
}

function Test-ContentPack([string]$Folder) {
 # A Workshop item without any mod.info is NOT always broken.
 # Map packs, B42 tile packs, model/texture asset packs ship only a
 # media/ folder (media\maps, media\tiles, ...) and the game loads them
 # straight from the Workshop folder via workshopMods.txt - no mod.info,
 # no modID, nothing wrong. Such items get Kind='CONTENT' and are NOT
 # counted as problems. Everything else without mod.info is treated as
 # a broken/incomplete download that "2. Fix" can repair.
    if (-not $Folder -or (-not (Test-Path -LiteralPath $Folder))) { return $false }
    if (Test-Path -LiteralPath (Join-Path $Folder 'media')) { return $true }
    try {
        $deep = Get-ChildItem -LiteralPath $Folder -Directory -Recurse -Depth 1 -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ieq 'media' } | Select-Object -First 1
        if ($deep) { return $true }
    } catch { }
    return $false
}

function Get-WorkshopItems([object[]]$Libraries) {
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($lib in $Libraries) {
        $content = Join-Path ([string]$lib) 'steamapps\workshop\content\108600'
        if (-not (Test-Path -LiteralPath $content)) { continue }
        $dirList = @(Get-ChildItem -LiteralPath $content -Directory -ErrorAction SilentlyContinue)
        $dirIdx = 0
        foreach ($dir in $dirList) {
            $dirIdx++
 # mid-scan breaths: the street keeps walking and the window
 # keeps repainting while the workshop folders are being read
            if (($dirIdx % 6) -eq 0) { Step-ScenePump }
            $quarantined = ($dir.Name -notmatch '^\d+$')
 # depth 5 - some items (bundle re-packs, nested packs)
 # keep mod.info four or five levels deep; depth 3 missed them
 # and reported perfectly working mods as "no mod.info".
            $modInfoFiles = Get-ChildItem -LiteralPath $dir.FullName -Filter 'mod.info' -Recurse -Depth 5 -ErrorAction SilentlyContinue
            $mods = [System.Collections.Generic.List[object]]::new()
            foreach ($mi in $modInfoFiles) { $mods.Add((Parse-ModInfo $mi.FullName)) }
            $name = ''
            if ($mods.Count -gt 0) { $name = [string]$mods[0]['Name'] }
            $idList = [System.Collections.Generic.List[string]]::new()
            foreach ($m in $mods) {
                $mid = [string]$m['Id']
                if ($mid -and -not $idList.Contains($mid)) { $idList.Add($mid) }
            }
            $kind = 'MODS'
            if ($mods.Count -eq 0 -and (Test-ContentPack $dir.FullName)) { $kind = 'CONTENT' }
            $items.Add(@{
                WorkshopId  = [string]$dir.Name
                Folder      = [string]$dir.FullName
                Quarantined = [bool]$quarantined
                Broken      = ($mods.Count -eq 0 -and $kind -ne 'CONTENT')
                IsLocal     = $false
                Kind        = $kind
                Mods        = $mods.ToArray()
                ModIds      = $idList.ToArray()
                Name        = $name
            })
        }
    }
    return , $items.ToArray()
}
# =============================================================================
# Saves and mods.txt
# =============================================================================
function Read-ModsTxt([string]$Path) {
 # Accepts every known layout of the save's mod list:
 # single line : mods=A;B;C (B41/B42 own format; ',' accepted too)
 # multi-line : mods= + { "A", "B" } (B42 tools / hand-edited files)
 # quoted ids : "A","B" (quotes and braces are stripped)
    $ids = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $Path)) { return , $ids.ToArray() }
    $lines = [string[]]@((Read-TextSmart $Path) -split "`r?`n")
    $i = 0
    while ($i -lt $lines.Count) {
        if ($lines[$i] -match '^\s*mods\s*=\s*(.*)$') {
            $val = $Matches[1].Trim()
            $i++
            if ($val -eq '' -or $val -eq '{') {
 # the list continues on the following lines until '}'
                $val = ''
                while ($i -lt $lines.Count) {
                    $l = [string]$lines[$i]
                    $i++
                    if ($l -match '^\s*\}') { break }
                    if ($l.Trim() -eq '') { continue }
                    $val += ' ' + $l
                }
            }
            foreach ($one in ($val -split '[;,]')) {
                $t = Get-NormalizedModId (($one.Trim() -replace '^[{"\s]+', '' -replace '[}"\s]+$', ''))
                if ($t) { if (-not $ids.Contains($t)) { $ids.Add($t) } }
            }
        } else {
            $i++
        }
    }
    return , $ids.ToArray()
}

function Read-WorkshopModsTxt([string]$ModsTxtPath) {
 # B42 saves keep the list of Workshop item IDs in workshopMods.txt next to
 # mods.txt. Read-only: used as an extra "the game uses this item" match,
 # so a status stays correct even when modIDs do not line up.
    $ids = [System.Collections.Generic.List[string]]::new()
    if (-not $ModsTxtPath) { return , $ids.ToArray() }
    $p = Join-Path (Split-Path -Parent $ModsTxtPath) 'workshopMods.txt'
    if (-not (Test-Path -LiteralPath $p)) { return , $ids.ToArray() }
    foreach ($line in ((Read-TextSmart $p) -split "`r?`n")) {
        if ($line -match '^\s*workshopMods\s*=\s*(.*)$') {
            foreach ($one in ($Matches[1] -split '[;,]')) {
                $t = Get-NormalizedModId (($one.Trim() -replace '^[{"\s]+', '' -replace '[}"\s]+$', ''))
                if ($t) { if (-not $ids.Contains($t)) { $ids.Add($t) } }
            }
        }
    }
    return , $ids.ToArray()
}

function Write-ModsTxt([string]$Path, [string[]]$Mods) {
 # millisecond stamp + collision loop: two rewrites inside one second
 # used to share a backup name and silently overwrite each other
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $bak = "{0}.bak-{1}" -f $Path, $stamp
    $n = 1
    while (Test-Path -LiteralPath $bak) {
        $bak = ("{0}.bak-{1}-{2}" -f $Path, $stamp, $n)
        $n++
    }
    Copy-Item -LiteralPath $Path -Destination $bak -Force
    $keep = [System.Collections.Generic.List[string]]::new()
 # Preserve the separator style already used in the file (';' is the game's own choice).
    $sep = ';'
    if (Test-Path -LiteralPath $Path) {
        $oldList = ''
        foreach ($l in ((Read-TextSmart $Path) -split "`r?`n")) {
            if ($l -match '^\s*mods\s*=(.*)$') { $oldList = $Matches[1]; continue }
            if ($l) { $keep.Add($l) }
        }
        if ($oldList -and ($oldList -notmatch ';') -and ($oldList -match ',')) { $sep = ',' }
    }
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($l in $keep) { $lines.Add($l) }
    $lines.Add('mods=' + ($Mods -join $sep))
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, (($lines.ToArray() -join "`r`n") + "`r`n"), $utf8NoBom)
    return $bak
}

function Write-WorkshopModsTxt([string]$Path, [string[]]$Wids) {
 # the workshopMods.txt twin of Write-ModsTxt - the game's own
 # B42 list of Workshop IDs gets the same respect as mods.txt:
 # millisecond-stamped backup, separator style preserved, every other
 # line kept exactly as it was
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $bak = "{0}.bak-{1}" -f $Path, $stamp
    $n = 1
    while (Test-Path -LiteralPath $bak) {
        $bak = ("{0}.bak-{1}-{2}" -f $Path, $stamp, $n)
        $n++
    }
    Copy-Item -LiteralPath $Path -Destination $bak -Force
    $keep = [System.Collections.Generic.List[string]]::new()
    $sep = ';'
    if (Test-Path -LiteralPath $Path) {
        $oldList = ''
        foreach ($l in ((Read-TextSmart $Path) -split "`r?`n")) {
            if ($l -match '^\s*workshopMods\s*=(.*)$') { $oldList = $Matches[1]; continue }
            if ($l) { $keep.Add($l) }
        }
        if ($oldList -and ($oldList -notmatch ';') -and ($oldList -match ',')) { $sep = ',' }
    }
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($l in $keep) { $lines.Add($l) }
    $lines.Add('workshopMods=' + ($Wids -join $sep))
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, (($lines.ToArray() -join "`r`n") + "`r`n"), $utf8NoBom)
    return $bak
}

function Sync-WorkshopIdsInSave([object]$Sv, [object[]]$Items) {
 # B42 keeps its own list of Workshop IDs in workshopMods.txt;
 # a switched-off mod leaves a dead entry there, and the status check
 # reads that entry as "still active" - the row lied right after the
 # user's own click. The sync removes exactly the dead-and-known
 # entries: a WorkshopID the scanner never saw is never touched.
    try {
        if ($null -eq $Sv) { return , [string[]]@() }
        $wids = [string[]]$Sv['WorkshopIds']
        if ($null -eq $wids -or $wids.Count -eq 0) { return , [string[]]@() }
        $alive = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($m in [string[]]$Sv['Mods']) { $m2 = Get-NormalizedModId ([string]$m); if ($m2) { [void]$alive.Add($m2) } }
        $known = @{}
        foreach ($it in $Items) {
            if ($null -eq $it) { continue }
            $w = [string]$it['WorkshopId']
            if (-not $w) { continue }
            if (-not $known.ContainsKey($w)) { $known[$w] = $false }
            foreach ($mid0 in [string[]]$it['ModIds']) {
                $mid = Get-NormalizedModId ([string]$mid0)
                if ($mid -and $alive.Contains($mid)) { $known[$w] = $true; break }
            }
        }
        $keep = [System.Collections.Generic.List[string]]::new()
        $removed = [System.Collections.Generic.List[string]]::new()
        foreach ($w in $wids) {
            if ($w -and $known.ContainsKey($w) -and (-not $known[$w])) { $removed.Add([string]$w); continue }
            $keep.Add([string]$w)
        }
        if ($removed.Count -eq 0) { return , [string[]]@() }
        $dir = Split-Path -Parent ([string]$Sv['Path'])
        $wmPath = Join-Path $dir 'workshopMods.txt'
        if (Test-Path -LiteralPath $wmPath) {
            [void](Write-WorkshopModsTxt $wmPath ([string[]]$keep.ToArray()))
        }
        $Sv['WorkshopIds'] = [string[]]$keep.ToArray()
        return , [string[]]$removed.ToArray()
    } catch { return , [string[]]@() }
}

function Reset-SaveAggregates {
 # the "works" status is computed from the union of every
 # save's mods.txt / workshopMods.txt. That union used to grow forever
 # and never shrink, so a disabled mod kept showing "works" (and the
 # disable button then did nothing: nothing left to remove). It is
 # rebuilt from the live save objects after every rewrite now.
    $Script:AllSaveMods = [System.Collections.Generic.List[string]]::new()
    $Script:AllWorkshops = [System.Collections.Generic.List[string]]::new()
    foreach ($sv in $Script:Saves) {
        if ($null -eq $sv) { continue }
        try {
            foreach ($m in [string[]]$sv['Mods']) { if ($m -and -not $Script:AllSaveMods.Contains($m)) { $Script:AllSaveMods.Add($m) } }
            foreach ($w in [string[]]$sv['WorkshopIds']) { if ($w -and -not $Script:AllWorkshops.Contains($w)) { $Script:AllWorkshops.Add($w) } }
        } catch {
            Write-CrashLog 'saves-collect' $_
        }
    }
}

function Get-PZSaves {
    $list = [System.Collections.Generic.List[object]]::new()
    $savesRoot = Join-Path (Get-ZomboidRoot) 'Saves'
    if (-not (Test-Path -LiteralPath $savesRoot)) { return , $list.ToArray() }
 # depth 3, not 2. B41 keeps worlds at Saves\<mode>\<user>\<world>
 # (three levels below Saves), B42 at Saves\<mode>\<world> (two); depth 2
 # silently missed every B41-style save, and the empty result then came
 # back as a NULL element (Sort-Object emits nothing on empty input) -
 # the same poison that crashed the mod scan.
    foreach ($mt in (Get-ChildItem -LiteralPath $savesRoot -Filter 'mods.txt' -Recurse -Depth 3 -ErrorAction SilentlyContinue)) {
 # label = "<top mode folder>\<world>" whatever depth the world sits at
        $world = Split-Path -Leaf $mt.DirectoryName
        $mode = ''
        try {
            $rel = [System.IO.Path]::GetFullPath($mt.DirectoryName).Substring([System.IO.Path]::GetFullPath($savesRoot).Length).TrimStart('\', '/')
            $parts = @($rel -split '[\\/]')
            if ($parts.Count -ge 2) { $mode = [string]$parts[0] }
        } catch { }
 # the mods.txt stamp goes stale on saves whose mod list
 # never changed - the game touches the world files on every
 # save. The newest file in the world folder is the honest
 # "last played" time the list is ordered by.
        $newest = $mt.LastWriteTime
        try {
            $nf = Get-ChildItem -LiteralPath $mt.DirectoryName -Recurse -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($nf -and ($nf.LastWriteTime -gt $newest)) { $newest = $nf.LastWriteTime }
        } catch { }
        $list.Add(@{
            Label       = ("{0}\{1}" -f $mode, $world)
            World       = $world
            Mode        = $mode
            Path        = [string]$mt.FullName
            Mods        = [string[]](Read-ModsTxt $mt.FullName)
            WorkshopIds = [string[]](Read-WorkshopModsTxt ([string]$mt.FullName))
            Modified    = $newest
        })
    }
 # an empty pipeline must never become a null someone can index:
 # @() keeps the shape a real object[] even when Sort-Object emits nothing
    $sorted = @($list.ToArray() | Sort-Object Modified -Descending)
    return , [object[]]$sorted
}

function Resolve-SaveDir([string]$Dir) {
    if (-not $Dir) { return $null }
    $direct = Join-Path $Dir 'mods.txt'
    if (Test-Path -LiteralPath $direct) { return (Get-Item -LiteralPath $direct).FullName }
    $found = Get-ChildItem -LiteralPath $Dir -Filter 'mods.txt' -Recurse -Depth 3 -ErrorAction SilentlyContinue
    if ($found) {
        $first = $found | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($first) { return $first.FullName }
    }
    return $null
}

# =============================================================================
# Analysis
# =============================================================================
function Invoke-Analysis([object[]]$Items, [string[]]$SaveMods) {
    $findings = [System.Collections.Generic.List[object]]::new()
    $byId = @{}
    foreach ($it in $Items) {
 # the twin of the guard below - the first loop used to miss
 # it, and one null element here was the whole "line 1033" crash
        if ($null -eq $it) { continue }
        foreach ($id in [string[]]$it['ModIds']) {
            if (-not $id) { continue }
            if (-not $byId.ContainsKey($id)) { $byId[$id] = [System.Collections.Generic.List[object]]::new() }
            $byId[$id].Add($it)
        }
    }
    $dupIds = @{}
    foreach ($id in $byId.Keys) {
        $owners = $byId[$id]
        $wids = [System.Collections.Generic.List[string]]::new()
        foreach ($o in $owners) {
            $w = [string]$o['WorkshopId']
            if (-not $wids.Contains($w)) { $wids.Add($w) }
        }
        if ($wids.Count -gt 1) {
            $dupIds[$id] = $true
            $findings.Add(@{
                Severity = 'ERROR'
                Code     = 'DUP_MODID'
                Text     = ((Get-T 'f_dup') -f $id, ($wids.ToArray() -join ', '))
            })
        }
    }
    foreach ($it in $Items) {
        if ($null -eq $it) { continue }
 # a local item has no WorkshopId - the folder name says who it is,
 # an empty "Предмет без mod.info" said nothing
        $w0 = [string]$it['WorkshopId']
        if (-not $w0) { $w0 = [string](Split-Path -Leaf ([string]$it['Folder'])) }
        if ($it['Broken']) {
            $findings.Add(@{
                Severity = 'INFO'
                Code     = 'NO_MOD_INFO'
                Text     = ((Get-T 'f_noinfo') -f $w0)
            })
        }
        if ($it['Quarantined']) {
            $findings.Add(@{
                Severity = 'INFO'
                Code     = 'QUARANTINED'
                Text     = ((Get-T 'f_quar') -f $w0)
            })
        }
    }
    if ($SaveMods -and $SaveMods.Count -gt 0) {
        foreach ($m in $SaveMods) {
            if (-not $byId.ContainsKey($m)) {
                $findings.Add(@{
                    Severity = 'ERROR'
                    Code     = 'MOD_NOT_INSTALLED'
                    Text     = ((Get-T 'f_notinstalled') -f $m)
                })
            }
        }
        $seenReq = @{}
        foreach ($m in $SaveMods) {
            if (-not $byId.ContainsKey($m)) { continue }
            foreach ($owner in $byId[$m]) {
                foreach ($sub in $owner['Mods']) {
                    if ([string]$sub['Id'] -ne $m) { continue }
                    foreach ($req0 in [string[]]$sub['Requires']) {
                        $req = Get-NormalizedModId $req0
                        if (-not $req) { continue }
 # repacks often ship two mod.info files with the same
 # id - the same requirement must not be reported twice
                        $rkey = (($m + '|' + $req).ToLower())
                        if ($seenReq.ContainsKey($rkey)) { continue }
                        $seenReq[$rkey] = $true
                        if (-not $byId.ContainsKey($req)) {
                            $findings.Add(@{
                                Severity = 'WARN'
                                Code     = 'REQ_MISSING'
                                Text     = ((Get-T 'f_reqmissing') -f $m, $req)
                            })
                        } elseif ($SaveMods -notcontains $req) {
                            $findings.Add(@{
                                Severity = 'WARN'
                                Code     = 'REQ_NOT_IN_SAVE'
                                Text     = ((Get-T 'f_reqnotsave') -f $m, $req)
                            })
                        }
                    }
                }
            }
        }
    }
    return @{ Findings = $findings.ToArray(); ById = $byId; DupIds = $dupIds }
}

function Get-ItemStatus([object]$Item, [string[]]$SaveMods, $AllSaveMods, $AllWorkshops, [bool]$HasSaves = $false) {
 # "Works" is deliberately wider than the selected save: the modID is
 # matched against EVERY save's mods.txt, and the Workshop ID against
 # every save's workshopMods.txt (B42). A user reads "works" as
 # "on in my game", not "on in save X". When nothing is known at all
 # (no saves found) the row says so instead of claiming "not enabled".
    if ($null -eq $Item) { return 'NOINFO' }
    if ($null -eq $AllSaveMods) { $AllSaveMods = $SaveMods }
    if ($null -eq $AllWorkshops) { $AllWorkshops = [string[]]@() }
    if ($Item['Quarantined']) { return 'QUARANTINE' }
    if ($Item['Kind'] -eq 'CONTENT') { return 'CONTENT' }
    if ($Item['Broken']) { return 'NOINFO' }
 # "no saves" must mean exactly that - not "every mod got
 # switched off". With saves present the row reads "disabled" even
 # when the unions are momentarily empty; only a machine with no
 # saves at all says "no saves" (CLI keeps the union-based verdict)
    $knows = $HasSaves -or (($null -ne $AllSaveMods) -and ($AllSaveMods.Count -gt 0)) -or (($null -ne $AllWorkshops) -and ($AllWorkshops.Count -gt 0))
    if (-not $knows) { return 'NOSAVE' }
    $wid = [string]$Item['WorkshopId']
    if ($wid -and ($AllWorkshops -contains $wid)) { return 'ACTIVE' }
    foreach ($mid in [string[]]$Item['ModIds']) {
        if ($mid -and ($AllSaveMods -contains $mid)) { return 'ACTIVE' }
    }
    return 'ORPHAN'
}

function Get-ItemStatusText([string]$Code) {
    switch ($Code) {
        'ACTIVE'     { Get-T 'st_status_active' }
        'ORPHAN'     { Get-T 'st_status_orphan' }
        'QUARANTINE' { Get-T 'st_quarantine' }
        'NOINFO'     { Get-T 'st_noinfo' }
        'CONTENT'    { Get-T 'st_content' }
        'NOSAVE'     { Get-T 'st_nosave' }
        default      { $Code }
    }
}

function Remove-QuarantineItems([object[]]$Items) {
 # Deletes the folders the game itself renamed+disabled (its quarantine
 # leftovers, folder names like "12345__pzfix_orphan"). Steam no longer
 # tracks a renamed folder, so unsubscribing never removes it - this is
 # the only way to clean such residue up. Files are deleted only here,
 # after an explicit confirmation in the GUI or the -CleanQuarantine flag.
    $kept = [System.Collections.Generic.List[object]]::new()
    $removed = 0
    $failed = 0
    $bytes = [long]0
    foreach ($it in $Items) {
        if ($null -eq $it) { continue }
        if (-not $it['Quarantined']) { $kept.Add($it); continue }
        $folder = [string]$it['Folder']
        try {
            $sum = 0
            try { $sum = (Get-ChildItem -LiteralPath $folder -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum } catch { }
            if ($sum) { $bytes += [long]$sum }
            Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction Stop
            $removed++
        } catch {
            $failed++
            $kept.Add($it)
        }
    }
    return @{ Items = $kept.ToArray(); Removed = $removed; Failed = $failed; Bytes = $bytes }
}

function Repair-BrokenItems([object[]]$Items) {
 # The second half of the one-click repair. A Workshop folder that
 # downloaded without any mod.info (and is not a content pack) is a
 # broken/incomplete download: the game cannot load it and no tool can
 # rebuild a missing mod.info from nothing. The honest repair is to
 # delete the folder - Steam re-downloads subscribed items automatically
 # on the next start, this time (hopefully) complete. Called only from
 # the auto-fix paths, after a confirmation in the GUI.
    $kept = [System.Collections.Generic.List[object]]::new()
    $removed = 0
    $failed = 0
    $bytes = [long]0
    foreach ($it in $Items) {
        if ($null -eq $it) { continue }
        if (-not $it['Broken']) { $kept.Add($it); continue }
        $folder = [string]$it['Folder']
        try {
            $sum = 0
            try { $sum = (Get-ChildItem -LiteralPath $folder -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum } catch { }
            if ($sum) { $bytes += [long]$sum }
            Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction Stop
            $removed++
        } catch {
            $failed++
            $kept.Add($it)
        }
    }
    return @{ Items = $kept.ToArray(); Removed = $removed; Failed = $failed; Bytes = $bytes }
}

# =============================================================================
# First-run settings + one-click auto-repair (the autopilot)
# =============================================================================
# =============================================================================
# First-run settings (stored in %LOCALAPPDATA%\PZWorkshopDoctor - a
# fixed place that does not depend on where the Zomboid folder is; the old
# <Zomboid>\pzwd.settings.json is read once and migrated)
# =============================================================================
function Get-SettingsDir {
    if ($env:LOCALAPPDATA) { return (Join-Path $env:LOCALAPPDATA 'PZWorkshopDoctor') }
    try {
        $tmp = [System.IO.Path]::GetTempPath()
        if ($tmp) { return (Join-Path $tmp 'PZWorkshopDoctor') }
    } catch { }
    return (Join-Path (Split-Path -Parent $PSCommandPath) '.pzwd-settings')
}

function Get-SettingsPath {
    $d = Get-SettingsDir
    try {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    } catch { }
    return (Join-Path $d 'pzwd.settings.json')
}

function Get-LegacySettingsPath {
 # Older builds kept the settings inside the Zomboid folder itself.
    try {
        $zr = Join-Path $env:USERPROFILE 'Zomboid'
        if (Test-Path -LiteralPath $zr) { return (Join-Path $zr 'pzwd.settings.json') }
    } catch { }
    return ''
}

function Test-FirstRun {
    $p = Get-SettingsPath
    if (-not $p) { return $true }
    if (Test-Path -LiteralPath $p) { return $false }
    $lp = Get-LegacySettingsPath
    if ($lp -and (Test-Path -LiteralPath $lp)) { return $false }
    return $true
}

function Save-Settings {
    $p = Get-SettingsPath
    if (-not $p) { return }
    try {
        $zd = ''
        if ($Script:ZomboidDir) {
            $zd = [string]$Script:ZomboidDir
        } elseif ($Script:ZomboidRootCache) {
            $zrc = [string]$Script:ZomboidRootCache
            if ($zrc -and (Test-Path -LiteralPath $zrc)) { $zd = $zrc }
        }
        $o = [pscustomobject]@{
            firstRunDone = $true
            lang         = [string]$Script:Lang
            version      = [string]$Script:Version
            zomboidDir   = $zd
        }
        $json = ConvertTo-Json -InputObject $o -Compress
        [System.IO.File]::WriteAllText($p, $json, [System.Text.UTF8Encoding]::new($false))
    } catch { }
}

function Read-Settings {
    $p = Get-SettingsPath
    if ($p -and (Test-Path -LiteralPath $p)) {
        try { return ([System.IO.File]::ReadAllText($p) | ConvertFrom-Json) } catch { return $null }
    }
    $lp = Get-LegacySettingsPath
    if ($lp -and (Test-Path -LiteralPath $lp)) {
        try { return ([System.IO.File]::ReadAllText($lp) | ConvertFrom-Json) } catch { return $null }
    }
    return $null
}

function Get-RemainingSummary([int]$Cnt) {
 # The "problems left" line must tell the truth: duplicates, missing
 # mods, save leftovers - not a hard-coded guess.
    if (-not $Script:Analysis) { return [string]$Cnt }
    $f = [object[]]$Script:Analysis['Findings']
    $miss = @($f | Where-Object { $_['Code'] -eq 'REQ_MISSING' }).Count
    $noti = @($f | Where-Object { $_['Code'] -eq 'MOD_NOT_INSTALLED' }).Count
    $dup = @($f | Where-Object { $_['Code'] -eq 'DUP_MODID' }).Count
    $other = $Cnt - $miss - $noti - $dup
    $parts = [System.Collections.Generic.List[string]]::new()
    if ($dup -gt 0) { $parts.Add([string]((Get-T 'left_dup') -f $dup)) }
    if ($miss -gt 0) { $parts.Add([string]((Get-T 'left_miss') -f $miss)) }
    if ($noti -gt 0) { $parts.Add([string]((Get-T 'left_notinst') -f $noti)) }
    if ($other -gt 0) { $parts.Add([string]((Get-T 'left_other') -f $other)) }
    if ($parts.Count -eq 0) { return [string](Get-T 'done_clean') }
    return ($parts.ToArray() -join ' · ')
}

function Get-ProblemCount($Analysis) {
 # One honest number for a schoolkid: every finding of the analysis
 # (duplicates, quarantine, broken items, missing/not-enabled mods).
    if (-not $Analysis) { return 0 }
    return ([object[]]$Analysis['Findings']).Count
}
function Repair-SyncSaves([object[]]$Items, [object[]]$Saves) {
 # The repairable half of the problem list, applied per save:
 # 1) mods the save itself references (its workshopMods.txt lists the
 # WorkshopID) but that went missing from mods.txt -> restored;
 # 2) requirements (require=) of the save's own mods that are installed
 # but not enabled in that save -> restored.
 # Every rewrite goes through Write-ModsTxt (a .bak file is created first).
 # Mods you disabled on purpose are never added: only what the save itself
 # asks for via WorkshopIDs, plus required mods of what is already in it.
    $report = [System.Collections.Generic.List[string]]::new()
    $fixedSaves = 0
    $added = 0
    $reqMap = @{}
 # case-insensitive on purpose: mod.info spells the same mod as "amclub"
 # in one item and "AmClub" in another - the game does not care, and
 # neither does the fix (the old case-sensitive set silently skipped
 # exactly those "installed but not enabled" requirements)
    $installed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($it in $Items) {
        if ($null -eq $it) { continue }
        if ($it['Quarantined'] -or $it['Broken']) { continue }
        foreach ($sub in $it['Mods']) {
            $id = [string]$sub['Id']
            if (-not $id) { continue }
            [void]$installed.Add($id)
            if (-not $reqMap.ContainsKey($id)) { $reqMap[$id] = [string[]]$sub['Requires'] }
        }
    }
    foreach ($s in $Saves) {
        $list = [System.Collections.Generic.List[string]]::new()
        $listSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($m in [string[]]$s['Mods']) { if ($m) { $list.Add($m); [void]$listSet.Add($m) } }
        $origCount = $list.Count
        $wids = [string[]]$s['WorkshopIds']
        $guard = 0
        while ($guard -lt 6) {
            $guard++
            $newThisRound = 0
 # rule 2: installed requirements of the save's own mods
            $snapshot = [string[]]$list.ToArray()
            foreach ($m in $snapshot) {
                if (-not $reqMap.ContainsKey($m)) { continue }
                foreach ($r0 in [string[]]$reqMap[$m]) {
                    $r = Get-NormalizedModId $r0
                    if ($r -and $installed.Contains($r) -and (-not $listSet.Contains($r))) {
                        $list.Add($r); [void]$listSet.Add($r); $newThisRound++
                    }
                }
            }
 # rule 1: mods the save references by WorkshopID
            if ($wids.Count -gt 0) {
                foreach ($it in $Items) {
                    if ($null -eq $it) { continue }
                    if ($it['Quarantined'] -or $it['Broken']) { continue }
                    $wid = [string]$it['WorkshopId']
                    $match = $false
                    if ($wid -and ($wid -match '^\d+$')) {
                        foreach ($w in $wids) { if ($w -eq $wid) { $match = $true; break } }
                    }
                    if (-not $match) { continue }
                    foreach ($mid0 in [string[]]$it['ModIds']) {
                        $mid = Get-NormalizedModId $mid0
                        if ($mid -and (-not $listSet.Contains($mid))) { $list.Add($mid); [void]$listSet.Add($mid); $newThisRound++ }
                    }
                }
            }
            if ($newThisRound -eq 0) { break }
        }
        if ($list.Count -gt $origCount) {
            $sortedArr = [string[]](Sort-ByDependencies ([string[]]$list.ToArray()) $Items)
            $bak = Write-ModsTxt ([string]$s['Path']) $sortedArr
            $s['Mods'] = $sortedArr
            $fixedSaves++
            $addedNow = $sortedArr.Count - $origCount
            $added += $addedNow
            $report.Add([string]((Get-T 'wiz_save_fixed') -f [string]$s['Label'], $addedNow, (Split-Path -Leaf $bak)))
        }
    }
    return @{ SavesFixed = $fixedSaves; Added = $added; Lines = $report.ToArray() }
}

# Kahn-style topological sort using require= lines
function Sort-ByDependencies([string[]]$Mods, [object[]]$Items) {
    $reqMap = @{}
    foreach ($it in $Items) {
        if ($null -eq $it) { continue }
        foreach ($sub in $it['Mods']) {
            $id = [string]$sub['Id']
            if ($id -and -not $reqMap.ContainsKey($id)) {
                $reqMap[$id] = [string[]]$sub['Requires']
            }
        }
    }
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($m in $Mods) { [void]$set.Add($m) }
    $sorted = [System.Collections.Generic.List[string]]::new()
    $sortedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $remaining = [System.Collections.Generic.List[string]]::new()
    foreach ($m in $Mods) { $remaining.Add($m) }
    $guard = 0
    while ($remaining.Count -gt 0 -and $guard -lt 10000) {
        $guard++
        $moved = $false
        $i = 0
        while ($i -lt $remaining.Count) {
            $m = $remaining[$i]
            $pending = @()
            if ($reqMap.ContainsKey($m)) {
                $pending = @($reqMap[$m] | Where-Object { $set.Contains($_) -and (-not $sortedSet.Contains($_)) })
            }
            if ($pending.Count -eq 0) {
                $sorted.Add($m); [void]$sortedSet.Add($m)
                $remaining.RemoveAt($i)
                $moved = $true
            } else {
                $i++
            }
        }
        if (-not $moved) { break }
    }
    foreach ($m in $remaining) { $sorted.Add($m) }
    return , $sorted.ToArray()
}

# =============================================================================
# System info / optimization advice (advisory only - nothing is ever changed)
# =============================================================================
# =============================================================================
# System info / REAL optimization (the program does not advise anymore -
# it patches the game's own memory file, writes Steam launch options and
# cleans junk logs itself; every change has a timestamped backup)
# =============================================================================
function Get-SystemInfo {
    $ram = 0.0
    $cores = 0
    $cpu = ''
    $gpu = ''
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $ram = [math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 1)
        $cores = [int]$cs.NumberOfLogicalProcessors
    } catch { }
    if ($cores -le 0) { try { $cores = [int][Environment]::ProcessorCount } catch { } }
    if ($ram -le 0) {
        try {
            $line = @(Get-Content -LiteralPath '/proc/meminfo' -TotalCount 1 -ErrorAction Stop)[0]
            if ($line -match 'MemTotal:\s+(\d+)\s*kB') { $ram = [math]::Round([double]$Matches[1] / (1024 * 1024), 1) }
        } catch { }
    }
    try { $cpu = [string]((Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1).Name) } catch { }
    try { $gpu = [string]((Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | Select-Object -First 1).Name) } catch { }
    return @{ RamGB = $ram; Cores = $cores; Cpu = $cpu.Trim(); Gpu = $gpu.Trim() }
}

function Get-OptimalXmx([double]$RamGB, [int]$ModCount) {
 # B41/B42 ship with a ~3 GB Java heap. The tiers give the game more
 # room only when the machine actually has it, and never more than half
 # of the total RAM - the OS, Steam and the browser need the rest.
    $xmx = 2048
    if ($RamGB -ge 32) { $xmx = 8192 }
    elseif ($RamGB -ge 24) { $xmx = 6144 }
    elseif ($RamGB -ge 16) { $xmx = 4096 }
    elseif ($RamGB -ge 8) { $xmx = 3072 }
    if ($ModCount -ge 80 -and $RamGB -ge 16 -and $xmx -lt 6144) { $xmx = 6144 }
    if ($RamGB -gt 0) {
        $cap = [int]([math]::Floor($RamGB / 2) * 1024)
        if ($cap -lt 2048) { $cap = 2048 }
        if ($xmx -gt $cap) { $xmx = $cap }
    }
    return [int]$xmx
}

function Set-GameJsonMemory([string]$GameDir, [int]$XmxMB) {
 # The game's own memory setting lives in ProjectZomboid64.json in the
 # game folder ("-Xmx3072m" by default) - the one proven tweak for big
 # mod lists. A timestamped backup sits next to the file.
    $res = @{ Applied = $false; AlreadyOk = $false; OldMB = 0; NewMB = [int]$XmxMB; Backup = ''; Missing = $false }
    if (-not $GameDir) { $res['Missing'] = $true; return $res }
    $jsonPath = Join-Path $GameDir 'ProjectZomboid64.json'
    if (-not (Test-Path -LiteralPath $jsonPath)) { $res['Missing'] = $true; return $res }
    $json = Read-TextSmart $jsonPath
    $m = [regex]::Match($json, '-Xmx(\d+)[mM]')
    if (-not $m.Success) {
        try {
            $o = $json | ConvertFrom-Json
            $hadVmArgs = $false
            if ($null -ne $o.vmArgs) { $hadVmArgs = $true }
            $list = [System.Collections.Generic.List[string]]::new()
            if ($hadVmArgs -and ($o.vmArgs -is [array])) { foreach ($a in $o.vmArgs) { $list.Add([string]$a) } }
            $list.Add(('-Xmx{0}m' -f [int]$XmxMB))
            $o.vmArgs = [string[]]$list.ToArray()
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $bak = '{0}.pzwd-bak-{1}' -f $jsonPath, $stamp
            Copy-Item -LiteralPath $jsonPath -Destination $bak -Force
            $txt = ($o | ConvertTo-Json -Depth 12)
            [System.IO.File]::WriteAllText($jsonPath, $txt, [System.Text.UTF8Encoding]::new($false))
            $res['Applied'] = $true
            $res['Backup'] = $bak
            return $res
        } catch { return $res }
    }
    $old = [int]$m.Groups[1].Value
    $res['OldMB'] = $old
    if ($old -eq [int]$XmxMB) { $res['AlreadyOk'] = $true; return $res }
    $newJson = $json.Replace($m.Value, ('-Xmx{0}m' -f [int]$XmxMB))
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak = '{0}.pzwd-bak-{1}' -f $jsonPath, $stamp
    Copy-Item -LiteralPath $jsonPath -Destination $bak -Force
    [System.IO.File]::WriteAllText($jsonPath, $newJson, [System.Text.UTF8Encoding]::new($false))
    $res['Applied'] = $true
    $res['Backup'] = $bak
    return $res
}

function Remove-JunkLogs([string]$GameDir, [string]$ZomboidRoot) {
 # Java crash dumps (hs_err_pid*/replay_pid*) older than a month and an
 # overgrown console.txt are real disk eaters - the game recreates them.
    $removed = 0
    $bytes = [long]0
    $consoleBefore = [long]0
    $dirs = [System.Collections.Generic.List[string]]::new()
    if ($GameDir -and (Test-Path -LiteralPath $GameDir)) { $dirs.Add($GameDir) }
    if ($ZomboidRoot -and (Test-Path -LiteralPath $ZomboidRoot)) { $dirs.Add($ZomboidRoot) }
    $cutoff = (Get-Date).AddDays(-30)
    foreach ($d in $dirs.ToArray()) {
        try {
            foreach ($f in (Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'hs_err_pid*' -or $_.Name -like 'replay_pid*' })) {
                if ($f.LastWriteTime -lt $cutoff) {
                    try {
                        $bytes += [long]$f.Length
                        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                        $removed++
                    } catch { }
                }
            }
        } catch { }
    }
    if ($ZomboidRoot) {
        $cp = Join-Path $ZomboidRoot 'console.txt'
        try {
            if (Test-Path -LiteralPath $cp) {
                $consoleBefore = [long](Get-Item -LiteralPath $cp).Length
                if ($consoleBefore -gt 20MB) {
                    $old = Join-Path $ZomboidRoot 'console.old.txt'
                    try { if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue } } catch { }
                    Move-Item -LiteralPath $cp -Destination $old -Force -ErrorAction Stop
                }
            }
        } catch { }
    }
    return @{ Removed = $removed; Bytes = $bytes; ConsoleBefore = $consoleBefore }
}

function Invoke-RealOptimize([string]$SteamHint, [int]$ModCount) {
 # Real optimization, fully automatic, nothing for the user to
 # copy anywhere. Returns a plain-language log + the backups it made.
    $lines = [System.Collections.Generic.List[string]]::new()
    $backups = [System.Collections.Generic.List[object]]::new()
    $si = Get-SystemInfo
    $lines.Add(((Get-T 'opt_ram') -f [double]$si['RamGB'], [int]$si['Cores']))
    if ($si['Gpu']) { $lines.Add(((Get-T 'opt_sys_ram') -f [double]$si['RamGB'], [string]$si['Gpu'])) }
    $steam = $null
    try { $steam = Find-SteamRoot $SteamHint } catch { }
    $libs = [object[]]@()
    if ($steam) { $libs = [object[]](Get-SteamLibraries ([string]$steam)) }
    $game = $null
    try { $game = Find-PZInstall $libs } catch { }
    $xmx = Get-OptimalXmx ([double]$si['RamGB']) ([int]$ModCount)
    if ($game) {
        $r = Set-GameJsonMemory ([string]$game) ([int]$xmx)
        if ($r['Applied']) {
            $lines.Add(((Get-T 'opt_xmx_set') -f [int]$r['OldMB'], [int]$r['NewMB'], (Split-Path -Leaf ([string]$r['Backup']))))
            $backups.Add(@{ Path = (Join-Path ([string]$game) 'ProjectZomboid64.json'); Backup = [string]$r['Backup'] })
        } elseif ($r['AlreadyOk']) {
            $lines.Add(((Get-T 'opt_xmx_same') -f [int]$r['NewMB']))
        } elseif ($r['Missing']) {
            $lines.Add((Get-T 'opt_json_missing'))
        }
        $jl = Remove-JunkLogs ([string]$game) (Get-ZomboidRoot)
        if ([int]$jl['Removed'] -gt 0) {
            $mb = '{0:N1} MB' -f ([double]$jl['Bytes'] / 1MB)
            $lines.Add(((Get-T 'opt_logs_cleaned') -f [int]$jl['Removed'], $mb))
        }
        if ([long]$jl['ConsoleBefore'] -gt 20MB) {
            $lines.Add(((Get-T 'opt_console_trim') -f ('{0:N0}' -f ([double]$jl['ConsoleBefore'] / 1MB))))
        }
    } else {
        $lines.Add((Get-T 'opt_no_game'))
    }
    if ($steam) {
        $lo = Set-SteamLaunchOptionsForPZ ([string]$steam) ([int]$xmx)
        if ([int]$lo['Changed'] -gt 0) {
            $sample = Merge-LaunchOptions '' ([int]$xmx)
            $lines.Add(((Get-T 'opt_launch_set') -f $sample))
            foreach ($b in [object[]]$lo['Backups']) { $backups.Add($b) }
            if ($lo['SteamRunning']) { $lines.Add((Get-T 'opt_launch_skip')) }
        } else {
            $lines.Add((Get-T 'opt_launch_same'))
        }
    } else {
        $lines.Add((Get-T 'opt_no_steam'))
    }
    return @{
        Lines   = [string[]]$lines.ToArray()
        Backups = [object[]]$backups.ToArray()
        Xmx     = [int]$xmx
        GameDir = [string]$game
        Steam   = [string]$steam
        System  = $si
    }
}

function Invoke-RollbackOptimize([object[]]$Backups) {
    $ok = 0
    if (-not $Backups) { return 0 }
    foreach ($b in $Backups) {
        try {
            if ($b -and $b['Backup'] -and $b['Path'] -and (Test-Path -LiteralPath ([string]$b['Backup']))) {
                Copy-Item -LiteralPath ([string]$b['Backup']) -Destination ([string]$b['Path']) -Force
                $ok++
            }
        } catch { }
    }
    return $ok
}

# =============================================================================
# Workshop descriptions (the details panel shows each item's title,
# tags, size and description straight from the Steam Workshop page, fetched
# through Steam's own public API and cached locally so it works offline)
# =============================================================================
$Script:WsCache = @{}

function Get-WorkshopCachePath {
    return (Join-Path (Get-SettingsDir) 'pzwd.workshop.cache.json')
}

function Read-WorkshopCache {
    $Script:WsCache = @{}
    $p = Get-WorkshopCachePath
    if (-not (Test-Path -LiteralPath $p)) { return }
    try {
        $o = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json
        foreach ($prop in $o.PSObject.Properties) { $Script:WsCache[$prop.Name] = $prop.Value }
    } catch { }
}

function Save-WorkshopCache([hashtable]$Cache) {
    $p = Get-WorkshopCachePath
    try {
        [System.IO.File]::WriteAllText($p, (ConvertTo-Json -InputObject $Cache -Depth 6), [System.Text.UTF8Encoding]::new($false))
    } catch { }
}

function Get-WorkshopInfoBatch([string[]]$Ids) {
 # Steam's own public endpoint (no key required) - the same data the
 # Workshop page shows: title, description, tags, file size, updates.
    $out = @{}
    $todo = [System.Collections.Generic.List[string]]::new()
    foreach ($i in $Ids) {
        if ($i -match '^\d+$' -and -not $todo.Contains($i)) { $todo.Add($i) }
    }
    if ($todo.Count -eq 0) { return $out }
    $api = 'https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/'
    for ($off = 0; $off -lt $todo.Count; $off += 20) {
        $chunk = @($todo.ToArray() | Select-Object -Skip $off -First 20)
        $body = [System.Text.StringBuilder]::new()
        [void]$body.Append('itemcount=' + $chunk.Count)
        for ($k = 0; $k -lt $chunk.Count; $k++) { [void]$body.Append('&publishedfileids[' + $k + ']=' + $chunk[$k]) }
        try {
            $resp = Invoke-RestMethod -Method Post -Uri $api -Body $body.ToString() -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 15
            foreach ($d in @($resp.response.publishedfiledetails)) {
                if ([int]$d.result -eq 1) {
                    $tags = ''
                    try { $tags = ((@($d.tags) | ForEach-Object { [string]$_.tag }) -join ', ') } catch { }
                    $out[[string]$d.publishedfileid] = @{
                        title       = [string]$d.title
                        description = [string]$d.description
                        fileSize    = [long]$d.file_size
                        updated     = [long]$d.time_updated
                        tags        = $tags
                        fetched     = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
                    }
                }
            }
        } catch { }
    }
    return $out
}

function ConvertFrom-BBCode([string]$Text) {
 # Workshop descriptions arrive in BBCode; strip it down to plain
 # readable text (links keep their address, images disappear).
    if (-not $Text) { return '' }
    $t = [string]$Text
    $t = $t -replace '\[img\][^\[]*\[/img\]', ''
    $t = $t -replace '\[url=([^\]]*)\]([^\[]*)\[/url\]', '$2 ($1)'
    $t = $t -replace '\[url\]([^\[]*)\[/url\]', '$1'
    $t = $t -replace '\[/?(b|i|u|s|code|quote|h1|h2|h3|hr|list|olist|li|spoiler)\]', ''
    $t = $t -replace '\[/?(size|color)(=[^\]]*)?\]', ''
    $t = [regex]::Replace($t, '(\r?\n){3,}', "`n`n")
    return $t.Trim()
}

function Format-WorkshopDescription([string]$Id) {
 # A Workshop digest for the details panel: one header line, one meta
 # line, then the COMPLETE description (BBCode stripped). The panel wraps
 # and scrolls, and the splitter stretches it - the text is never cut.
    if (-not $Id -or -not $Script:WsCache -or -not $Script:WsCache.ContainsKey($Id)) { return '' }
    $w = $Script:WsCache[$Id]
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine((Get-T 'ws_desc_title'))
    $title = ''
    $tags = ''
    $size = [long]0
    $updated = [long]0
    $desc = ''
    try { $title = [string]$w.title } catch { }
    try { $tags = [string]$w.tags } catch { }
    try { $size = [long]$w.fileSize } catch { }
    try { $updated = [long]$w.updated } catch { }
    try { $desc = [string]$w.description } catch { }
    if ($title) { [void]$sb.AppendLine((' ' + (Get-T 'ws_name') + ': ' + $title)) }
    $dateStr = ''
    try {
        if ($updated -gt 0) {
            $dateStr = [DateTimeOffset]::FromUnixTimeSeconds($updated).LocalDateTime.ToString('yyyy-MM-dd')
        }
    } catch { }
    if ($size -gt 0 -and -not $dateStr) { $dateStr = '—' }
    if ($tags -or $size -gt 0) {
        [void]$sb.AppendLine((' ' + ((Get-T 'ws_meta') -f $tags, ('{0:N0}' -f ([double]$size / 1MB)), $dateStr)))
    }
    if ($desc) {
 # the full description, nothing cut off
        $plain = ConvertFrom-BBCode $desc
        if ($plain) { [void]$sb.AppendLine(' ' + $plain) }
    }
    return $sb.ToString()
}
# =============================================================================
# Missing-mod resolution: a bare modID ("damnlib") is turned into a Workshop
# item by searching the public community search (no key needed). Candidates
# are scored by how openly the item declares this exact modID.
# =============================================================================
function Find-WorkshopItemForMod([string]$ModId) {
    $res = @{ Wid = ''; Title = ''; Score = 0 }
    if (-not $ModId) { return $res }
    try {
        $q = [System.Uri]::EscapeDataString($ModId)
        $url = 'https://steamcommunity.com/workshop/browse/?appid=108600&browsesort=textsearch&section=readytouseitems&searchtext=' + $q
        $ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) PZWorkshopDoctor/' + $Script:Version
        $html = ''
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -UserAgent $ua
            $html = [string]$r.Content
        } catch { return $res }
        if (-not $html) { return $res }
        $wids = [System.Collections.Generic.List[string]]::new()
        foreach ($m in [regex]::Matches($html, 'data-publishedfileid="(\d+)"')) {
            $w = $m.Groups[1].Value
            if ($w -and -not $wids.Contains($w) -and $wids.Count -lt 12) { $wids.Add($w) }
        }
        foreach ($m in [regex]::Matches($html, 'id="Subscription(\d+)"')) {
            $w = $m.Groups[1].Value
            if ($w -and -not $wids.Contains($w) -and $wids.Count -lt 12) { $wids.Add($w) }
        }
        if ($wids.Count -eq 0) { return $res }
        $details = Get-WorkshopInfoBatch ([string[]]$wids.ToArray())
        $best = ''
        $bestTitle = ''
        $bestScore = 0
        $needle = [string]$ModId.ToLower()
        foreach ($kv in $details.GetEnumerator()) {
            $wid = [string]$kv.Key
            $title = ''
            $desc = ''
            try { $title = [string]$kv.Value.title } catch { }
            try { $desc = [string]$kv.Value.description } catch { }
            $tl = $title.ToLower()
            $dl = $desc.ToLower()
            $score = 0
            $rxNeedle = [regex]::Escape($needle)
            if ($dl -match ('mod\s*id\s*[:=]\s*\\?' + $rxNeedle + '\b')) { $score = 100 }
            elseif ($tl -eq $needle) { $score = 90 }
            elseif ($tl.Contains($needle)) { $score = 70 }
            elseif ($dl.Contains($needle)) { $score = 50 }
            if ($score -gt $bestScore) { $bestScore = $score; $best = $wid; $bestTitle = $title }
        }
        if ($bestScore -ge 70) {
            $res['Wid'] = $best; $res['Title'] = $bestTitle; $res['Score'] = $bestScore
        }
    } catch { }
    return $res
}

function Get-MissingRequirementIds([object[]]$Items, [string[]]$AllSaveMods, $Analysis) {
 # modIDs the saves (or their require= chains) ask for but that are not
 # installed anywhere: these are the auto-download candidates.
    $missing = [System.Collections.Generic.List[string]]::new()
    $byId = @{}
    if ($Analysis) { $byId = $Analysis['ById'] }
    foreach ($m in $AllSaveMods) {
        $m2 = Get-NormalizedModId $m
        if ($m2 -and (-not $byId.ContainsKey($m2)) -and (-not $missing.Contains($m2))) { $missing.Add($m2) }
    }
    $reqOf = @{}
    foreach ($it in $Items) {
        if ($null -eq $it) { continue }
        if ($it['Quarantined'] -or $it['Broken']) { continue }
        foreach ($sub in $it['Mods']) {
            $sid = Get-NormalizedModId ([string]$sub['Id'])
            if ($sid -and -not $reqOf.ContainsKey($sid)) { $reqOf[$sid] = [string[]]$sub['Requires'] }
        }
    }
    foreach ($m in $AllSaveMods) {
        $m2 = Get-NormalizedModId $m
        if (-not $m2 -or -not $reqOf.ContainsKey($m2)) { continue }
        foreach ($r0 in [string[]]$reqOf[$m2]) {
            $r = Get-NormalizedModId $r0
            if ($r -and (-not $byId.ContainsKey($r)) -and (-not $missing.Contains($r))) { $missing.Add($r) }
        }
    }
    return , $missing.ToArray()
}

function Get-MissingRequirementMap([object[]]$Items, [string[]]$AllSaveMods, $Analysis) {
 # missing modID -> the save-mods that ask for it. A mod that is
 # enabled in a save but installed nowhere maps to an EMPTY list (the
 # save itself is the demander); a requirement nobody installed maps
 # to the save-mods whose require= lines mention it.
    $map = @{}
    $byId = @{}
    if ($Analysis) { $byId = $Analysis['ById'] }
    foreach ($m in $AllSaveMods) {
        $m2 = Get-NormalizedModId $m
        if ($m2 -and (-not $byId.ContainsKey($m2)) -and (-not $map.ContainsKey($m2))) {
            $map[$m2] = [System.Collections.Generic.List[string]]::new()
        }
    }
    $reqOf = @{}
    foreach ($it in $Items) {
        if ($null -eq $it) { continue }
        if ($it['Quarantined'] -or $it['Broken']) { continue }
        foreach ($sub in $it['Mods']) {
            $sid = Get-NormalizedModId ([string]$sub['Id'])
            if ($sid -and -not $reqOf.ContainsKey($sid)) { $reqOf[$sid] = [string[]]$sub['Requires'] }
        }
    }
    foreach ($m in $AllSaveMods) {
        $m2 = Get-NormalizedModId $m
        if (-not $m2 -or -not $reqOf.ContainsKey($m2)) { continue }
        foreach ($r0 in [string[]]$reqOf[$m2]) {
            $r = Get-NormalizedModId $r0
            if (-not $r -or $byId.ContainsKey($r)) { continue }
            if (-not $map.ContainsKey($r)) { $map[$r] = [System.Collections.Generic.List[string]]::new() }
            if (-not $map[$r].Contains($m2)) { $map[$r].Add($m2) }
        }
    }
    return $map
}

function Get-DependentMods([string[]]$Roots, [object[]]$Items, [string[]]$AllSaveMods) {
 # every save-mod that (transitively) requires one of the roots: they
 # cannot load without them, so they are switched off together - that
 # is what keeps the next check from dragging them straight back in
    $reqOf = @{}
    foreach ($it in $Items) {
        if ($null -eq $it) { continue }
        if ($it['Quarantined'] -or $it['Broken']) { continue }
        foreach ($sub in $it['Mods']) {
            $sid = Get-NormalizedModId ([string]$sub['Id'])
            if ($sid -and -not $reqOf.ContainsKey($sid)) { $reqOf[$sid] = [string[]]$sub['Requires'] }
        }
    }
    $closure = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $queue = [System.Collections.Generic.List[string]]::new()
    foreach ($r in $Roots) {
        if ($r) {
            $r2 = Get-NormalizedModId $r
            if ($r2) { [void]$closure.Add($r2); $queue.Add($r2) }
        }
    }
    $guard = 0
    while ($queue.Count -gt 0 -and $guard -lt 200) {
        $guard++
        $cur = [string]$queue[0]
        $queue.RemoveAt(0)
        foreach ($m in $AllSaveMods) {
            $m2 = Get-NormalizedModId $m
            if (-not $m2 -or $closure.Contains($m2)) { continue }
            if (-not $reqOf.ContainsKey($m2)) { continue }
            foreach ($r0 in [string[]]$reqOf[$m2]) {
                $rr = Get-NormalizedModId $r0
                if ($rr -and $closure.Contains($rr)) {
                    [void]$closure.Add($m2)
                    $queue.Add($m2)
                    break
                }
            }
        }
    }
 # HashSet has no callable ToArray() from PowerShell (the toggle
 # crash was exactly this) - @() unwraps it instead
    return , [string[]]@($closure)
}

function Disable-ModsInSaves([string[]]$ModIds, [object[]]$Saves, [object[]]$Items) {
 # removes the given modIDs from every save's mods.txt (a .bak backup
 # is written first, exactly like the restore path does)
    $report = [System.Collections.Generic.List[string]]::new()
    $disabled = 0
    $drop = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($m in $ModIds) {
        if ($m) { [void]$drop.Add((Get-NormalizedModId $m)) }
    }
    foreach ($s in $Saves) {
        $before = [string[]]$s['Mods']
        $list = [System.Collections.Generic.List[string]]::new()
        foreach ($m in $before) {
            if ($m -and -not $drop.Contains((Get-NormalizedModId $m))) { $list.Add($m) }
        }
        if ($list.Count -lt $before.Count) {
            $sortedArr = [string[]](Sort-ByDependencies ([string[]]$list.ToArray()) $Items)
            $bak = Write-ModsTxt ([string]$s['Path']) $sortedArr
            $s['Mods'] = $sortedArr
 # the B42 workshopMods.txt loses its dead entries too -
 # the status must not keep saying "works" about a mod this
 # very loop just switched off
            try { [void](Sync-WorkshopIdsInSave $s $Items) } catch { }
            $disabled++
            $report.Add([string]((Get-T 'miss_save_disabled') -f [string]$s['Label'], (Split-Path -Leaf $bak)))
        }
    }
    return @{ Disabled = $disabled; Lines = $report.ToArray() }
}

function Invoke-MissingDisable([string]$MissingId) {
 # switches off (in every save, with backups) the mods whose
 # requirement does not exist in the Workshop - plus everything that
 # depends on them. Returns how many mods were switched off.
    $disabledCount = 0
    try {
        $items = [object[]]$Script:Items
        $allSave = [string[]]@()
        try { $allSave = [string[]]$Script:AllSaveMods.ToArray() } catch { }
        $requirers = [string[]]@()
        if ($Script:MissingMap -and $Script:MissingMap.ContainsKey($MissingId)) {
            $requirers = [string[]]$Script:MissingMap[$MissingId]
        }
        $doomed = [System.Collections.Generic.List[string]]::new()
        foreach ($r in $requirers) {
            if ($r -and -not $doomed.Contains($r)) { $doomed.Add($r) }
        }
        if ($MissingId -and $allSave -contains $MissingId -and -not $doomed.Contains($MissingId)) {
 # the save itself wants this mod and it cannot be downloaded
 # from anywhere: it goes too
            $doomed.Add($MissingId)
        }
        if ($doomed.Count -eq 0) { return 0 }
        $closure = [string[]](Get-DependentMods ([string[]]$doomed.ToArray()) $items $allSave)
        $res = Disable-ModsInSaves ([string[]]$closure) ([object[]]$Script:Saves) $items
        $disabledCount = [int]$res['Disabled']
        foreach ($ln in [string[]]$res['Lines']) { Add-HomeLine ([string]$ln) }
        Add-HomeLine ((Get-T 'miss_disabled') -f $MissingId, ($closure -join ', '))
 # the unions are rebuilt right away - the table must not
 # keep saying "works" about what this path just switched off
        try { Reset-SaveAggregates } catch { }
    } catch { }
    return $disabledCount
}

function Export-ItemsTsv([object[]]$Items, [string]$Path, [string[]]$SaveMods, $DupIds, $AllSaveMods, $AllWorkshops) {
    $sb = [System.Text.StringBuilder]::new()
    $header = @((Get-T 'col_num'), (Get-T 'col_name'), (Get-T 'col_ids'), (Get-T 'col_wid'), (Get-T 'col_link'), (Get-T 'col_status'))
    [void]$sb.AppendLine(($header -join "`t"))
    $i = 0
    foreach ($it in $Items) {
        $i++
        if ($null -eq $it) { continue }
        $name = ''
        if ($it['Broken']) { $name = Get-T 'no_modinfo' }
        elseif ($it['Kind'] -eq 'CONTENT') { $name = [string](Get-T 'content_name') }
        else { $name = [string]$it['Name'] }
        $dup = $false
        if ($DupIds) {
            foreach ($id in [string[]]$it['ModIds']) {
                if ($DupIds.ContainsKey($id)) { $dup = $true; break }
            }
        }
        $status = Get-ItemStatusText (Get-ItemStatus $it $SaveMods $AllSaveMods $AllWorkshops)
        if ($dup) { $status = $status + ' ' + (Get-T 'fl_dup') }
        $wid = [string]$it['WorkshopId']
        if (-not $wid) { $wid = Get-T 'wid_local' }
        $row = @([string]$i, (Clean-Tsv $name), (Clean-Tsv (([string[]]$it['ModIds']) -join ', ')), (Clean-Tsv $wid), (Clean-Tsv (Get-WorkshopUrl ([string]$it['WorkshopId']))), (Clean-Tsv $status))
        [void]$sb.AppendLine(($row -join "`t"))
    }
    $utf8Bom = [System.Text.UTF8Encoding]::new($true)
    [System.IO.File]::WriteAllText($Path, $sb.ToString(), $utf8Bom)
}

# =============================================================================
# CLI mode
# =============================================================================
function Show-Help {
    Write-Output ''
    Write-Output ("PZ Workshop Doctor v{0}" -f $Script:Version)
    Write-Output '================================='
    Write-Output 'GUI : powershell -ExecutionPolicy Bypass -File .\PZ-WorkshopDoctor.ps1'
    Write-Output 'CLI : add -Cli for console mode'
    Write-Output ''
    Write-Output 'Steam, saves and the interface language are detected automatically.'
    Write-Output 'The script can be run from any folder. Options below are overrides:'
    Write-Output ''
    Write-Output '  -Cli                     console mode (full report: table + conflicts)'
    Write-Output '  -Cli -Conflicts          print conflicts and problems only'
    Write-Output '  -Cli -AutoFix            one-click repair: quarantine + broken downloads'
    Write-Output '                          removed (Steam re-downloads them) + missing mods'
    Write-Output '                          restored into every save (with backups); mods the'
    Write-Output '                          saves need are looked up in the Workshop, then report'
    Write-Output '  -Cli -Export -OutFile F  export the mod list as TSV (with Workshop links)'
    Write-Output '  -Optimize                REAL optimization: game memory file, Steam launch options,'
    Write-Output '                          junk log cleanup - all with backups, no manual steps'
    Write-Output '  -CleanQuarantine         delete folders the game disabled (quarantine)'
    Write-Output '  -NoWizard                skip the first-launch autopilot wizard'
    Write-Output '  -SteamPath C:\Steam      Steam root (folder with steamapps)'
    Write-Output '  -SaveDir <world folder>  save folder (contains mods.txt); default: newest save'
    Write-Output '  -ZomboidDir <Zomboid>    custom Zomboid folder (saves + local mods),'
    Write-Output '                          for non-Steam game copies; default: %USERPROFILE%\Zomboid'
    Write-Output '  -Lang RU|EN              interface language (default: follows Windows)'
    Write-Output ''
}

function Get-ItemCliStatus([object]$Item, [string[]]$SaveMods, $AllSaveMods, $AllWorkshops) {
 # The CLI table shows the same human statuses as the GUI grid.
    return (Get-ItemStatusText (Get-ItemStatus $Item $SaveMods $AllSaveMods $AllWorkshops))
}

function Invoke-CliMode {
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
    Write-Output ''
    Write-Output ("PZ WORKSHOP DOCTOR v{0} — {1}" -f $Script:Version, (Get-T 'tagline'))

    if ($Optimize) {
        $cnt = 0
        try {
            $steamO = Find-SteamRoot $SteamPath
            $workO = [object[]]@()
            if ($steamO) { $workO = [object[]](Get-WorkshopItems (Get-SteamLibraries $steamO)) }
            $locO = [object[]](Get-LocalMods (Get-ZomboidRoot))
            $cnt = $workO.Count + $locO.Count
        } catch { }
        $res = Invoke-RealOptimize $SteamPath ([int]$cnt)
        Write-Output ''
        Write-Output (Get-T 'cli_opt_title')
        Write-Output ('-' * 60)
        foreach ($l in [string[]]$res['Lines']) { Write-Output $l }
        Write-Output ''
        Write-Output (Get-T 'cli_opt_done')
        Write-Output ''
        return
    }

 # Steam is optional now: a non-Steam game copy still has local mods
 # (Zomboid\mods) and saves worth diagnosing.
    $steam = Find-SteamRoot $SteamPath
    $items = [object[]]@()
    $libs = [object[]]@()
    if ($steam) {
        Write-Output ("Steam: {0}" -f $steam)
        $libs = [object[]](Get-SteamLibraries $steam)
        $items = [object[]](Get-WorkshopItems $libs)
    } else {
        Write-Output (Get-T 'msg_no_steam_local')
    }
    $game = $null
    try { $game = Find-PZInstall $libs } catch { }
    if ($game) { Write-Output ((Get-T 'cli_game') -f $game) } else { Write-Output (Get-T 'cli_game_no') }
    $local = [object[]](Get-LocalMods (Get-ZomboidRoot))
    if ($local.Count -gt 0) { Write-Output ((Get-T 'cli_local_note') -f $local.Count) }
    $items = Normalize-Items ($items + $local)
    if ($items.Count -eq 0) {
        Write-Output (Get-T 'cli_no_items_any')
        return
    }

    $saveMods = [string[]]@()
    $saveLabel = ''
    $modsTxtPath = $null
    $allSaves = [object[]](Get-PZSaves)
    if ($SaveDir) {
        $modsTxtPath = Resolve-SaveDir $SaveDir
    } elseif ($allSaves.Count -gt 0) {
        $modsTxtPath = [string]$allSaves[0]['Path']
        $saveLabel = [string]$allSaves[0]['Label']
    }
    if ($modsTxtPath) {
        if (-not $saveLabel) { $saveLabel = $modsTxtPath }
        $saveMods = [string[]](Read-ModsTxt $modsTxtPath)
    }
 # Status matching spans EVERY save (modIDs + B42 workshopMods.txt), so a
 # mod enabled in any world reads as enabled - that is what a user means
 # by "it is on in my game".
    $allSaveMods = [System.Collections.Generic.List[string]]::new()
    $allWorkshops = [System.Collections.Generic.List[string]]::new()
    foreach ($s in $allSaves) {
        foreach ($m in [string[]]$s['Mods']) { if ($m -and -not $allSaveMods.Contains($m)) { $allSaveMods.Add($m) } }
        foreach ($w in [string[]]$s['WorkshopIds']) { if ($w -and -not $allWorkshops.Contains($w)) { $allWorkshops.Add($w) } }
    }
    $allModsArr = [string[]]$allSaveMods.ToArray()
    $allWidsArr = [string[]]$allWorkshops.ToArray()
    $noSaves = ($allSaves.Count -eq 0)

 # Quarantine leftovers: folders the game renamed+disabled itself.
    $quarCount = @($items | Where-Object { $_['Quarantined'] }).Count
    if ($CleanQuarantine) {
        if ($quarCount -eq 0) {
            Write-Output (Get-T 'cli_quar_none')
        } else {
            $res = Remove-QuarantineItems $items
            $items = Normalize-Items $res['Items']
            $quarCount = @($items | Where-Object { $_['Quarantined'] }).Count
            $mb = '{0:N1} MB' -f ([double]$res['Bytes'] / 1MB)
            Write-Output ((Get-T 'cli_quar_cleaned') -f [int]$res['Removed'], $mb)
        }
    } elseif ($quarCount -gt 0) {
        Write-Output ((Get-T 'cli_quar_found') -f $quarCount)
    }

 # -AutoFix: the CLI twin of the GUI autopilot "Fix everything" button -
 # quarantine cleanup + broken downloads removed + missing mods restored
 # into every save (with backups), then the normal report below shows the
 # honest "after" state.
    if ($AutoFix) {
        Write-Output ''
        Write-Output (Get-T 'cli_autofix_title')
        Write-Output ('-' * 60)
        $pre = Invoke-Analysis $items $saveMods
        $beforeCnt = ([object[]]$pre['Findings']).Count
        Write-Output ((Get-T 'cli_autofix_before') -f $beforeCnt)
        if ($beforeCnt -eq 0) {
            Write-Output (Get-T 'cli_autofix_none')
        } else {
            $quarAf = @($items | Where-Object { $_['Quarantined'] })
            if ($quarAf.Count -gt 0) {
                $resAf = Remove-QuarantineItems $items
                $items = [object[]]$resAf['Items']
                $mbAf = '{0:N1} MB' -f ([double]$resAf['Bytes'] / 1MB)
                Write-Output ((Get-T 'cli_autofix_quar') -f [int]$resAf['Removed'], $mbAf)
            }
 # folders that downloaded without mod.info are broken
 # downloads - remove them so Steam fetches a fresh copy.
            $brokenAf = @($items | Where-Object { $_['Broken'] })
            if ($brokenAf.Count -gt 0) {
                $resB = Repair-BrokenItems $items
                $items = [object[]]$resB['Items']
                $mbB = '{0:N1} MB' -f ([double]$resB['Bytes'] / 1MB)
                Write-Output ((Get-T 'cli_autofix_broken') -f [int]$resB['Removed'], $mbB)
            }
            $syncAf = Repair-SyncSaves $items $allSaves
            foreach ($lnAf in [object[]]$syncAf['Lines']) { Write-Output ([string]$lnAf) }
 # mods the saves need but that are not installed: resolve them in
 # the Workshop and open the subscribe pages (Steam downloads the
 # moment the user clicks Subscribe)
            $allSaveModsArrAf = [string[]]$allSaveMods.ToArray()
            $missIdsAf = Get-MissingRequirementIds $items $allSaveModsArrAf $pre
            $mapAf = Get-MissingRequirementMap $items $allSaveModsArrAf $pre
            if ($missIdsAf.Count -gt 0) {
                $openedAf = 0
                foreach ($midAf in $missIdsAf) {
                    $rAf = Find-WorkshopItemForMod $midAf
                    if ($rAf['Wid']) {
                        $openedAf++
                        $urlAf = Get-WorkshopUrl ([string]$rAf['Wid'])
                        Write-Output ((Get-T 'miss_found') -f $midAf, [string]$rAf['Title'])
                        Write-Output ('  ' + $urlAf)
                        try { Start-Process -FilePath $urlAf } catch { }
                    } else {
 # not in the Workshop at all: switch the mods that
 # ask for it off in the saves (backup kept) - a
 # search page with nothing on it helps nobody
                        $requirersAf = [string[]]@()
                        if ($mapAf -and $mapAf.ContainsKey($midAf)) { $requirersAf = [string[]]$mapAf[$midAf] }
                        $doomedAf = [System.Collections.Generic.List[string]]::new()
                        foreach ($rAf in $requirersAf) {
                            if ($rAf -and -not $doomedAf.Contains($rAf)) { $doomedAf.Add($rAf) }
                        }
                        if ($allSaveModsArrAf -contains $midAf -and -not $doomedAf.Contains($midAf)) { $doomedAf.Add($midAf) }
                        if ($doomedAf.Count -eq 0) { $doomedAf.Add($midAf) }
                        $closureAf = [string[]](Get-DependentMods ([string[]]$doomedAf.ToArray()) $items ([string[]]$allSaveModsArrAf))
                        $disAf = Disable-ModsInSaves ([string[]]$closureAf) $allSaves $items
                        foreach ($lnDis in [string[]]$disAf['Lines']) { Write-Output ([string]$lnDis) }
                        Write-Output ((Get-T 'cli_autofix_disable') -f $midAf, ($closureAf -join ', '))
                    }
                }
                Write-Output ((Get-T 'cli_autofix_dl') -f $openedAf, $missIdsAf.Count)
            }
 # mods.txt files were rewritten: re-read the saves and the lists
            $allSaves = [object[]](Get-PZSaves)
            $allSaveMods.Clear()
            $allWorkshops.Clear()
            foreach ($sAf in $allSaves) {
                foreach ($mAf in [string[]]$sAf['Mods']) { if ($mAf -and -not $allSaveMods.Contains($mAf)) { $allSaveMods.Add($mAf) } }
                foreach ($wAf in [string[]]$sAf['WorkshopIds']) { if ($wAf -and -not $allWorkshops.Contains($wAf)) { $allWorkshops.Add($wAf) } }
            }
            $allModsArr = [string[]]$allSaveMods.ToArray()
            $allWidsArr = [string[]]$allWorkshops.ToArray()
            if ($modsTxtPath) { $saveMods = [string[]](Read-ModsTxt $modsTxtPath) }
            $post = Invoke-Analysis $items $saveMods
            Write-Output ((Get-T 'cli_autofix_after') -f ([object[]]$post['Findings']).Count)
        }
        Write-Output ''
    }

    $analysis = Invoke-Analysis $items $saveMods

    if ($Export) {
        if (-not $OutFile) { Write-Output (Get-T 'cli_outfile_req'); return }
        Export-ItemsTsv $items $OutFile $saveMods $analysis['DupIds'] $allModsArr $allWidsArr
        Write-Output ''
        Write-Output ((Get-T 'cli_exported') -f $OutFile)
        return
    }

    if (-not $Conflicts) {
        Write-Output ''
        Write-Output ((Get-T 'cli_header') -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
        Write-Output ((Get-T 'cli_intro') -f $items.Count)
        if ($modsTxtPath) { Write-Output ((Get-T 'cli_save_note') -f $saveLabel) }
        elseif ($noSaves) { Write-Output (Get-T 'cli_save_none') }
        Write-Output ''
        Write-Output ('{0,4}  {1,-44}  {2,-26}  {3,10}  {4}' -f (Get-T 'col_num'), (Get-T 'col_name'), (Get-T 'col_ids'), (Get-T 'col_wid'), (Get-T 'col_status'))
        Write-Output ('-' * 108)
        $i = 0
        foreach ($it in ($items | Sort-Object Name)) {
            $i++
            if ($null -eq $it) { continue }
            $name = ''
            if ($it['Broken']) { $name = Get-T 'no_modinfo' }
            elseif ($it['Kind'] -eq 'CONTENT') { $name = Limit-Text ([string](Get-T 'content_name')) 44 }
            else { $name = Limit-Text ([string]$it['Name']) 44 }
            $ids = Limit-Text (([string[]]$it['ModIds']) -join ', ') 26
            $st = Get-ItemCliStatus $it $saveMods $allModsArr $allWidsArr
            $wid = [string]$it['WorkshopId']
            if (-not $wid) { $wid = Get-T 'wid_local' }
            Write-Output ('{0,4}  {1,-44}  {2,-26}  {3,10}  {4}' -f $i, $name, $ids, $wid, $st)
        }
    }

    $findings = [object[]]$analysis['Findings']
    Write-Output ''
    if ($findings.Count -gt 0) {
        Write-Output ((Get-T 'cli_conflicts') -f $findings.Count)
        foreach ($f in $findings) {
            Write-Output ("  [{0}] {1}: {2}" -f [string]$f['Severity'], [string]$f['Code'], [string]$f['Text'])
        }
    } else {
        Write-Output (Get-T 'cli_none')
    }

    $cntActive = 0; $cntOrphan = 0; $cntQuar = 0; $cntNoInfo = 0; $cntContent = 0
    foreach ($it in $items) {
        switch (Get-ItemStatus $it $saveMods $allModsArr $allWidsArr) {
            'ACTIVE'     { $cntActive++ }
            'ORPHAN'     { $cntOrphan++ }
            'QUARANTINE' { $cntQuar++ }
            'NOINFO'     { $cntNoInfo++ }
            'CONTENT'    { $cntContent++ }
        }
    }
    Write-Output ''
    if ($noSaves) { Write-Output (Get-T 'cli_save_none') }
    else { Write-Output ((Get-T 'cli_totals') -f $cntActive, $cntOrphan, $cntQuar, $cntNoInfo, $findings.Count, $cntContent) }
    Write-Output ''
}

# =============================================================================
# GUI: XAML layout (ONE window, three views inside - Home, the manual
# workbench and the optimizer. Report/advice/wizard windows are gone: every
# result opens inside this same window, confirmations are inline panels.)
# =============================================================================
$Script:Xaml = @"
<Window x:Name="Wnd"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PZ Workshop Doctor"
        Height="780" Width="1210" MinWidth="980" MinHeight="600"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None" ResizeMode="CanResize"
        Background="#14160D" Foreground="#CDD3A5"
        FontFamily="Segoe UI" FontSize="13">
  <WindowChrome.WindowChrome>
 <!-- the banner IS the window's head now. The OS title bar is
         gone; the top strip drags natively, double-click maximizes, the
         six-pixel invisible border still resizes, and Win+arrows snapping
         keeps working. No hint anywhere in the interface. -->
    <WindowChrome CaptionHeight="52" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="0"/>
  </WindowChrome.WindowChrome>
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#262C19"/>
      <Setter Property="Foreground" Value="#CDD3A5"/>
      <Setter Property="BorderBrush" Value="#3A4128"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="HorizontalContentAlignment" Value="Center"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#333D22"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="ListBox">
      <Setter Property="Background" Value="#1A1D12"/>
      <Setter Property="BorderBrush" Value="#2E3320"/>
      <Setter Property="Foreground" Value="#C3CBA4"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#1A1D12"/>
      <Setter Property="BorderBrush" Value="#2E3320"/>
      <Setter Property="Foreground" Value="#B7BFA0"/>
      <Setter Property="CaretBrush" Value="#8A9A5B"/>
    </Style>
    <Style TargetType="Label">
      <Setter Property="Foreground" Value="#8A9A5B"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Margin" Value="0,8,0,2"/>
      <Setter Property="Padding" Value="0"/>
    </Style>
    <Style TargetType="DataGridColumnHeader">
      <Setter Property="Background" Value="#202416"/>
      <Setter Property="Foreground" Value="#8A9A5B"/>
      <Setter Property="BorderBrush" Value="#2E3320"/>
      <Setter Property="Padding" Value="6,4"/>
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>
    <Style TargetType="DataGridRow">
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="#2E3A1E"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="ListBoxItem">
      <Setter Property="Foreground" Value="#C3CBA4"/>
      <Setter Property="Padding" Value="6,3"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="#2E3A1E"/>
          <Setter Property="Foreground" Value="#CDD3A5"/>
        </Trigger>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#242A17"/>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>
  <Grid>
  <DockPanel>
    <Border x:Name="TopBar" DockPanel.Dock="Top" Background="#202416" BorderBrush="#2E3320" BorderThickness="0,0,0,1" Padding="14,10">
      <DockPanel>
        <StackPanel Orientation="Horizontal" DockPanel.Dock="Left">
          <TextBlock Text="PZ WORKSHOP DOCTOR" FontFamily="Consolas" FontSize="20" FontWeight="Bold" Foreground="#A3B06A" VerticalAlignment="Center"/>
          <TextBlock x:Name="VersionText" FontFamily="Consolas" FontSize="13" FontWeight="Bold" Foreground="#9FCC6B" VerticalAlignment="Center" Margin="8,0,0,2"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center" Margin="10,0,0,0" WindowChrome.IsHitTestVisibleInChrome="True">
          <Button x:Name="BtnWinMin" Content="—" Width="38" Height="28" Padding="0" Margin="0,0,6,0" FontSize="13" FontWeight="Bold"/>
          <Button x:Name="BtnWinMax" Content="□" Width="38" Height="28" Padding="0" Margin="0,0,6,0" FontSize="13" FontWeight="Bold"/>
          <Button x:Name="BtnWinClose" Content="✕" Width="44" Height="28" Padding="0" Background="#3A241E" BorderBrush="#5A3428" FontSize="13" FontWeight="Bold"/>
        </StackPanel>
        <ComboBox x:Name="LangBox" DockPanel.Dock="Right" Width="70" SelectedIndex="0" VerticalAlignment="Center" Background="#262C19" Foreground="#CDD3A5" WindowChrome.IsHitTestVisibleInChrome="True">
          <ComboBoxItem Content="RU"/>
          <ComboBoxItem Content="EN"/>
        </ComboBox>
        <TextBlock x:Name="TaglineText" VerticalAlignment="Center" Margin="16,0,16,0" Foreground="#8A9A5B"/>
      </DockPanel>
    </Border>
    <Border DockPanel.Dock="Top" Background="#1D2114" BorderBrush="#2E3320" BorderThickness="0,0,0,1" Padding="14,8,14,8">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Button x:Name="BtnMain" Grid.Column="0" MinWidth="255" Height="46" FontSize="15" FontWeight="Bold" Background="#2E4A1E" Margin="0,0,10,0"/>
        <Button x:Name="BtnManual" Grid.Column="1" MinWidth="250" Height="46" FontSize="15" FontWeight="Bold" Background="#3A2A26" Margin="0,0,10,0"/>
        <Button x:Name="BtnOptimize" Grid.Column="2" MinWidth="215" Height="46" FontSize="15" FontWeight="Bold" Background="#333D22" Margin="0,0,10,0"/>
      </Grid>
    </Border>
    <Border x:Name="AdvancedBar" DockPanel.Dock="Top" Background="#1D2114" BorderBrush="#2E3320" BorderThickness="0,0,0,1" Padding="10,4" Visibility="Collapsed">
      <WrapPanel>
        <Button x:Name="BtnSelectAll" MinWidth="130" Padding="9,4" Margin="0,2,6,2"/>
        <Button x:Name="BtnClearAll" MinWidth="110" Padding="9,4" Margin="0,2,6,2"/>
 <!-- two honest buttons replace the one mood-swinger - enable
             stays green, disable wears the horde red, and neither ever
             changes its mind about what today's click will do -->
        <Button x:Name="BtnToggle" MinWidth="170" Padding="9,4" Margin="0,2,6,2" FontWeight="Bold" Background="#2E4A1E"/>
        <Button x:Name="BtnToggleOff" MinWidth="170" Padding="9,4" Margin="0,2,0,2" FontWeight="Bold" Background="#4A2622"/>
      </WrapPanel>
    </Border>
    <Border x:Name="FooterStrip" DockPanel.Dock="Bottom" Background="#202416" BorderBrush="#2E3320" BorderThickness="0,1,0,0" Padding="14,4">
      <TextBlock x:Name="FooterText" Foreground="#6B7057" FontSize="11"/>
    </Border>
    <Border x:Name="StatusStrip" DockPanel.Dock="Bottom" Background="#171A10" BorderBrush="#2E3320" BorderThickness="0,1,0,0" Padding="14,3">
      <TextBlock x:Name="StatusText" Foreground="#C3CBA4" FontFamily="Consolas" FontSize="12"/>
    </Border>
    <Border x:Name="SceneStrip" DockPanel.Dock="Bottom" Background="#12150E" BorderBrush="#232819" BorderThickness="0,1,0,0" Height="92">
      <Grid>
        <Canvas x:Name="SceneCanvas" ClipToBounds="True"/>
        <Rectangle x:Name="SceneDeathBg" Fill="#4A0D0D" Opacity="0" Visibility="Collapsed" IsHitTestVisible="False"/>
        <TextBlock x:Name="SceneBanner" HorizontalAlignment="Center" VerticalAlignment="Center" FontFamily="Consolas" FontWeight="Bold" FontSize="15" Foreground="#9FCC6B" Visibility="Collapsed" IsHitTestVisible="False">
          <TextBlock.RenderTransform>
            <TranslateTransform x:Name="SceneBannerTt" X="0"/>
          </TextBlock.RenderTransform>
        </TextBlock>
        <TextBlock x:Name="SceneDeath" HorizontalAlignment="Center" VerticalAlignment="Center" FontFamily="Consolas" FontWeight="Bold" FontSize="19" Foreground="#D24A4A" Visibility="Collapsed" IsHitTestVisible="False"/>
      </Grid>
    </Border>
    <Grid Margin="10">

 <!-- ============ HOME: the program leads, the user presses at most one button ============ -->
      <Grid x:Name="HomeView">
        <Border x:Name="HomeCard" MaxWidth="800" VerticalAlignment="Center" HorizontalAlignment="Center"
                Background="#171A10" BorderBrush="#2E3320" BorderThickness="1" CornerRadius="10" Padding="40,30">
          <StackPanel>
            <TextBlock x:Name="SpIcon" Text="?" FontSize="44" FontWeight="Bold" Foreground="#8FBC6F" HorizontalAlignment="Center"/>
            <TextBlock x:Name="SpTitle" FontSize="26" FontWeight="Bold" Foreground="#A3B06A" HorizontalAlignment="Center" TextWrapping="Wrap" TextAlignment="Center" Margin="0,10,0,0"/>
            <TextBlock x:Name="SpStats" FontFamily="Consolas" FontSize="15" Foreground="#C3CBA4" HorizontalAlignment="Center" Margin="0,14,0,0"/>
            <Border Background="#14160D" BorderBrush="#2E3320" BorderThickness="1" Padding="14,10" Margin="0,16,0,0" CornerRadius="6" MaxHeight="250" MinHeight="44">
              <TextBox x:Name="SpDetail" IsReadOnly="True" IsUndoEnabled="False" Background="Transparent" BorderThickness="0" Padding="0"
                       FontFamily="Consolas" FontSize="12.5" Foreground="#8A9A5B" TextWrapping="Wrap"
                       VerticalScrollBarVisibility="Auto" SelectionBrush="#3E5A26" CaretBrush="#8A9A5B"/>
            </Border>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,18,0,0">
              <Button x:Name="SpBtn1" MinWidth="320" Height="50" FontSize="15" FontWeight="Bold" Background="#2E4A1E" Visibility="Collapsed"/>
              <Button x:Name="SpBtn2" MinWidth="200" Height="44" Margin="12,0,0,0" Visibility="Collapsed"/>
            </StackPanel>
            <Border x:Name="SpConfirm" Visibility="Collapsed" Background="#14160D" BorderBrush="#6B5A2E" BorderThickness="1" Padding="16,12" Margin="0,16,0,0" CornerRadius="6">
              <StackPanel>
                <TextBlock x:Name="SpConfirmText" TextWrapping="Wrap" Foreground="#C3CBA4" FontSize="12.5"/>
                <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                  <Button x:Name="SpConfirmYes" MinWidth="250" Height="42" Background="#4A3B1E" FontWeight="Bold"/>
                  <Button x:Name="SpConfirmNo" MinWidth="140" Height="42" Margin="10,0,0,0"/>
                </StackPanel>
              </StackPanel>
            </Border>
          </StackPanel>
        </Border>
      </Grid>

 <!-- ============ WORKBENCH: manual mod management ============ -->
      <Grid x:Name="WorkView" Visibility="Collapsed">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="280"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="230"/>
        </Grid.RowDefinitions>
        <ScrollViewer Grid.Column="0" Grid.Row="0" Margin="0,0,10,0" VerticalScrollBarVisibility="Auto">
          <StackPanel>
            <Label x:Name="LblSaves"/>
            <ListBox x:Name="SavesList" Height="150"/>
            <Label x:Name="LblSteam"/>
            <DockPanel>
              <Button x:Name="BtnBrowse" DockPanel.Dock="Right" Margin="6,0,0,0" Padding="8,3"/>
              <TextBox x:Name="PathBox" IsReadOnly="True" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap" MaxHeight="54"/>
            </DockPanel>
            <Button x:Name="BtnZomboid" Margin="0,6,0,0" HorizontalAlignment="Left" Padding="10,3"/>
            <Label x:Name="LblGame" Margin="0,10,0,2"/>
            <TextBox x:Name="GameBox" IsReadOnly="True" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap" MaxHeight="54"/>
          </StackPanel>
        </ScrollViewer>
        <DataGrid x:Name="Grid" Grid.Column="1" Grid.Row="0" AutoGenerateColumns="False"
                  CanUserAddRows="False" CanUserDeleteRows="False" CanUserSortColumns="True"
                  SelectionMode="Extended" SelectionUnit="FullRow"
                  Background="#171A10" BorderBrush="#2E3320" Foreground="#CDD3A5"
                  RowBackground="#191C11" AlternatingRowBackground="#1E2214"
                  GridLinesVisibility="Horizontal" HorizontalGridLinesBrush="#242A17"
                  FontFamily="Consolas" FontSize="12" ColumnHeaderHeight="26"
                  HeadersVisibility="Column" RowHeight="26">
          <DataGrid.CellStyle>
            <Style TargetType="DataGridCell">
              <Setter Property="BorderThickness" Value="0"/>
              <Setter Property="Focusable" Value="False"/>
              <Style.Triggers>
                <DataTrigger Binding="{Binding StatusKind}" Value="ACTIVE">
                  <Setter Property="Foreground" Value="#8FBC6F"/>
                </DataTrigger>
                <DataTrigger Binding="{Binding StatusKind}" Value="ORPHAN">
                  <Setter Property="Foreground" Value="#B7BFA0"/>
                </DataTrigger>
                <DataTrigger Binding="{Binding StatusKind}" Value="QUARANTINE">
                  <Setter Property="Foreground" Value="#C9963C"/>
                </DataTrigger>
                <DataTrigger Binding="{Binding StatusKind}" Value="NOINFO">
                  <Setter Property="Foreground" Value="#C9963C"/>
                </DataTrigger>
                <DataTrigger Binding="{Binding StatusKind}" Value="CONTENT">
                  <Setter Property="Foreground" Value="#7FA8C9"/>
                </DataTrigger>
                <DataTrigger Binding="{Binding StatusKind}" Value="NOSAVE">
                  <Setter Property="Foreground" Value="#7A8494"/>
                </DataTrigger>
                <DataTrigger Binding="{Binding Dup}" Value="True">
                  <Setter Property="Foreground" Value="#C05B4D"/>
                </DataTrigger>
              </Style.Triggers>
            </Style>
          </DataGrid.CellStyle>
          <DataGrid.Columns>
            <DataGridTemplateColumn Header="✓" Width="34" SortMemberPath="Sel" CanUserSort="True">
              <DataGridTemplateColumn.CellTemplate>
                <DataTemplate>
                  <CheckBox HorizontalAlignment="Center" Focusable="False" IsChecked="{Binding Sel, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}"/>
                </DataTemplate>
              </DataGridTemplateColumn.CellTemplate>
            </DataGridTemplateColumn>
            <DataGridTextColumn Header="No" Binding="{Binding Num}" Width="36" IsReadOnly="True"/>
            <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="290" IsReadOnly="True"/>
            <DataGridTextColumn Header="modID" Binding="{Binding ModIds}" Width="*" IsReadOnly="True"/>
            <DataGridTextColumn Header="WorkshopID" Binding="{Binding WorkshopId}" Width="90" IsReadOnly="True"/>
            <DataGridTemplateColumn Header="Link" Width="80" SortMemberPath="Url" CanUserSort="True">
              <DataGridTemplateColumn.CellTemplate>
                <DataTemplate>
                  <TextBlock HorizontalAlignment="Center">
                    <Hyperlink NavigateUri="{Binding Url}" Foreground="#7FB3D5" Cursor="Hand">
                      <Run Text="{Binding LinkText}"/>
                    </Hyperlink>
                  </TextBlock>
                </DataTemplate>
              </DataGridTemplateColumn.CellTemplate>
            </DataGridTemplateColumn>
            <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="175" IsReadOnly="True" SortMemberPath="StatusKind"/>
          </DataGrid.Columns>
        </DataGrid>
 <!-- draggable splitter: the details area can be made taller with
             the mouse, so nothing ever feels cut off -->
        <GridSplitter Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="2" Height="7" Margin="0,4,0,2"
                      HorizontalAlignment="Stretch" VerticalAlignment="Center"
                      Background="#242A17" BorderBrush="#2E3320" BorderThickness="1"
                      ResizeDirection="Rows" ResizeBehavior="PreviousAndNext" ShowsPreview="False" Cursor="SizeNS"/>
        <Grid Grid.Column="0" Grid.ColumnSpan="2" Grid.Row="2" Margin="0,6,0,0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="10"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <DockPanel Grid.Column="0">
            <Label x:Name="LblDetails" DockPanel.Dock="Top"/>
            <TextBox x:Name="DetailsBox" IsReadOnly="True" FontFamily="Consolas" FontSize="11.5" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" TextWrapping="Wrap"/>
          </DockPanel>
          <DockPanel Grid.Column="2">
            <Label x:Name="LblConflicts" DockPanel.Dock="Top"/>
            <TextBox x:Name="ConflictsBox" IsReadOnly="True" FontFamily="Consolas" FontSize="11.5" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" TextWrapping="Wrap" Foreground="#C3CBA4"/>
          </DockPanel>
        </Grid>
      </Grid>

 <!-- ============ OPTIMIZER: the program really optimizes, all by itself ============ -->
      <Grid x:Name="OptView" Visibility="Collapsed">
        <Border MaxWidth="820" VerticalAlignment="Center" HorizontalAlignment="Center"
                Background="#171A10" BorderBrush="#2E3320" BorderThickness="1" CornerRadius="10" Padding="40,30">
          <StackPanel>
            <TextBlock x:Name="OptTitle" FontSize="24" FontWeight="Bold" Foreground="#A3B06A" HorizontalAlignment="Center" TextWrapping="Wrap" TextAlignment="Center"/>
            <TextBlock x:Name="OptSys" FontFamily="Consolas" FontSize="14" Foreground="#C3CBA4" HorizontalAlignment="Center" Margin="0,14,0,0" TextWrapping="Wrap" TextAlignment="Center"/>
            <TextBlock x:Name="OptSys2" FontFamily="Consolas" FontSize="14" Foreground="#C3CBA4" HorizontalAlignment="Center" Margin="0,6,0,0" TextWrapping="Wrap" TextAlignment="Center"/>
            <TextBlock x:Name="OptPlan" FontSize="13.5" Foreground="#B7BFA0" TextWrapping="Wrap" Margin="0,16,0,0"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,18,0,0">
              <Button x:Name="OptRun" MinWidth="250" Height="50" FontSize="15" FontWeight="Bold" Background="#2E4A1E"/>
              <Button x:Name="OptBack" MinWidth="190" Height="44" Margin="12,0,0,0" Visibility="Collapsed"/>
            </StackPanel>
            <Border Background="#14160D" BorderBrush="#2E3320" BorderThickness="1" Padding="14,10" Margin="0,16,0,0" CornerRadius="6" MaxHeight="260" MinHeight="44">
              <TextBox x:Name="OptLog" IsReadOnly="True" IsUndoEnabled="False" Background="Transparent" BorderThickness="0" Padding="0"
                       FontFamily="Consolas" FontSize="12.5" Foreground="#8A9A5B" TextWrapping="Wrap"
                       VerticalScrollBarVisibility="Auto" SelectionBrush="#3E5A26" CaretBrush="#8A9A5B"/>
            </Border>
          </StackPanel>
        </Border>
      </Grid>

    </Grid>
  </DockPanel>
  </Grid>
</Window>
"@

# =============================================================================
# GUI: logic
# =============================================================================
class PZGridRow {
    [bool]$Sel
    [int]$Num
    [string]$Name
    [string]$ModIds
    [string]$WorkshopId
    [string]$Url
    [string]$LinkText
    [string]$Status
    [string]$StatusKind
    [bool]$Dup
    [string]$Folder
}

$Script:Items = [object[]]@()
$Script:Saves = [object[]]@()
$Script:Save = $null
$Script:SaveMods = [System.Collections.Generic.List[string]]::new()
$Script:AllSaveMods = [System.Collections.Generic.List[string]]::new()
$Script:AllWorkshops = [System.Collections.Generic.List[string]]::new()
$Script:Analysis = $null
$Script:Steam = $null
$Script:Ui = $null
$Script:Busy = $false
$Script:View = 'home'
$Script:HomeLines = [System.Collections.Generic.List[string]]::new()
$Script:HomeKind = 'idle'
$Script:GridSort = $null
$Script:FirstRun = $false
$Script:FixBefore = 0
$Script:SpAction1 = ''
$Script:SpAction2 = ''
$Script:ConfirmYes = $null
$Script:ConfirmNo = $null
$Script:PendingQuar = [object[]]@()
$Script:PendingBroken = [object[]]@()
$Script:Prefetch = $null
$Script:PrefetchTimer = $null
$Script:OptBackups = [object[]]@()
$Script:OptSysFilled = $false
$Script:MissingJob = $null
$Script:MissingTimer = $null
$Script:WatchTimer = $null
$Script:WatchWids = [string[]]@()
$Script:WatchRoots = [string[]]@()
$Script:WatchDeadline = [datetime]::MinValue
# The living street (top-down survivor vs zombies)
$Script:Scene = $null
$Script:SceneTimer = $null
$Script:SceneRand = [System.Random]::new(97331)
# shipped the variable but forgot the accessor: every scene call
# went through (Get-SceneRand) -> CommandNotFoundException right after
# the road was drawn. The street died before a single zombie walked.
function Get-SceneRand { return $Script:SceneRand }
$Script:SceneErrShown = $false
$Script:MissingMap = $null

function Set-StatusText([string]$Text) {
    if ($Script:Ui -and $Script:Ui.StatusText) { $Script:Ui.StatusText.Text = $Text }
}

function Invoke-Safe([scriptblock]$Body) {
    try {
        & $Body
    } catch {
        $msg = ''
        try { $msg = [string]$_.Exception.Message } catch { $msg = 'unknown' }
        try { Set-StatusText ((Get-T 'err_line') -f $msg) } catch { }
    }
}

function Update-Title {
    if ($Script:Ui -and $Script:Ui.Wnd) {
        $Script:Ui.Wnd.Title = ("PZ Workshop Doctor v{0}" -f $Script:Version)
    }
}

function Find-ItemByRow($Row) {
    $folder = [string]$Row.Folder
    foreach ($cand in $Script:Items) {
        if ($null -eq $cand) { continue }
        if ([string]$cand['Folder'] -eq $folder) { return $cand }
    }
    return $null
}

function Get-CheckedOrSelected {
 # checkboxes ONLY. A highlighted-but-unticked row is reading
 # material, not an action target - the enable/disable buttons never
 # act on a row the user did not tick.
    $rows = Get-Seq $Script:Ui.Grid.Items
    $checked = @($rows | Where-Object { $_.Sel })
    return , $checked
}

function Get-GridSortKey([object]$Row, [string]$Prop) {
 # the order a column MEANS, not the order its letters happen to be
 # in: status sorts works -> disabled -> trouble -> no data, and the
 # check column puts the ticked rows on top - they are the ones the
 # buttons act on. Everything else sorts by its own type.
    switch ($Prop) {
        'StatusKind' {
            switch ([string]$Row.StatusKind) {
                'ACTIVE'     { return 0 }
                'ORPHAN'     { return 1 }
                'QUARANTINE' { return 2 }
                'CONTENT'    { return 3 }
                'NOINFO'     { return 4 }
                'NOSAVE'     { return 5 }
            }
            return 9
        }
        'Sel' { if ($Row.Sel) { return 0 } else { return 1 } }
        'Num' { return [int]$Row.Num }
        default {
            $v = [string]$Row.$Prop
            if ($null -eq $v) { $v = '' }
            return $v
        }
    }
}

function Sort-GridRows([System.Collections.Generic.List[object]]$Rows) {
 # the chosen column order outlives every refresh: Update-Grid applies
 # it while rebuilding, a header click applies it to the rows already
 # on screen. "No" rides along as the tiebreaker, so equal keys never
 # shuffle the table.
    if (-not $Script:GridSort) { return }
    if ($null -eq $Rows -or $Rows.Count -lt 2) { return }
    $prop = [string]$Script:GridSort['Prop']
    if (-not $prop) { return }
    $desc = [bool]$Script:GridSort['Desc']
    try {
        $keys = @(
            @{ Expression = { Get-GridSortKey $_ $prop } },
            @{ Expression = { [int]$_.Num } }
        )
        $sorted = @($Rows.ToArray() | Sort-Object -Property $keys -Descending:$desc)
        $Rows.Clear()
        foreach ($r in $sorted) { if ($null -ne $r) { [void]$Rows.Add($r) } }
    } catch { Write-CrashLog ('grid-sort: ' + $prop) $_ }
}

function Invoke-GridSort([string]$Prop, [bool]$Desc) {
 # a header click: remember the column and direction, sort the rows
 # that are on screen right now and hand them back to the grid - no
 # rescan, no flicker, and every later rebuild keeps the same order.
    $Script:GridSort = @{ Prop = $Prop; Desc = $Desc }
    if (-not $Script:Ui -or -not $Script:Ui.Grid) { return }
    $live = [System.Collections.Generic.List[object]]::new()
    foreach ($r in (Get-Seq $Script:Ui.Grid.Items)) { if ($null -ne $r) { $live.Add($r) } }
    Sort-GridRows $live
    try { $Script:Ui.Grid.ItemsSource = $live.ToArray() } catch { Write-CrashLog 'grid-sort-assign' $_ }
}

function Update-Grid {
    param($CheckSet = $null, [switch]$Preserve)
    $prev = @{}
    if ($Preserve) {
        foreach ($r in (Get-Seq $Script:Ui.Grid.Items)) {
            if ($r.Sel) { $prev[[string]$r.Folder] = $true }
        }
    }
    $rows = [System.Collections.Generic.List[object]]::new()
    $i = 0
    foreach ($it in $Script:Items) {
        $i++
        if ($null -eq $it) { continue }
 # one poisoned row used to kill the WHOLE table - the loop
 # died mid-way, ItemsSource never got assigned and the user saw an
 # empty grid ("mods are not shown"). Each row now builds in its own
 # guard and the table is always assigned below, whatever happened
        try {
            $folder = [string]$it['Folder']
            $wid = [string]$it['WorkshopId']
            $name = ''
            if ($it['Broken']) { $name = Get-T 'no_modinfo' }
            elseif ($it['Kind'] -eq 'CONTENT') { $name = Get-T 'content_name' }
            else { $name = Limit-Text ([string]$it['Name']) 60 }
            $dup = $false
            if ($Script:Analysis) {
                foreach ($mid in [string[]]$it['ModIds']) {
                    if ($Script:Analysis['DupIds'].ContainsKey($mid)) { $dup = $true; break }
                }
            }
            $sel = $false
            if ($CheckSet) { $sel = $CheckSet.ContainsKey($folder) }
            elseif ($Preserve) { $sel = $prev.ContainsKey($folder) }
            $widDisplay = $wid
            if (-not $widDisplay) { $widDisplay = Get-T 'wid_local' }
            $url = Get-WorkshopUrl $wid
            $linkText = ''
            if ($url) { $linkText = Get-T 'col_link_open' }
            $stCode = Get-ItemStatus $it ([string[]]$Script:SaveMods.ToArray()) ([string[]]$Script:AllSaveMods.ToArray()) ([string[]]$Script:AllWorkshops.ToArray()) ((@($Script:Saves).Count -gt 0))
            $stText = Get-ItemStatusText $stCode
            if ($dup) { $stText = $stText + ' (' + (Get-T 'fl_dup') + ')' }
            $rows.Add([PZGridRow]@{
                Sel        = $sel
                Num        = $i
                Name       = $name
                ModIds     = Limit-Text (([string[]]$it['ModIds']) -join ', ') 40
                WorkshopId = $widDisplay
                Url        = $url
                LinkText   = $linkText
                Status     = $stText
                StatusKind = $stCode
                Dup        = $dup
                Folder     = $folder
            })
        } catch {
            Write-CrashLog ('grid-row: ' + [string]$it['Folder']) $_
        }
    }
 # the user's chosen column order survives the rebuild
    Sort-GridRows $rows
    try { $Script:Ui.Grid.ItemsSource = $rows.ToArray() } catch { Write-CrashLog 'grid-assign' $_ }
}

function Update-Conflicts {
    if (-not $Script:Analysis) { $Script:Ui.ConflictsBox.Text = ''; return }
    $f = [object[]]$Script:Analysis['Findings']
    if ($f.Count -eq 0) { $Script:Ui.ConflictsBox.Text = [string](Get-T 'cli_none'); return }
    $sb = [System.Text.StringBuilder]::new()
    foreach ($x in $f) {
        [void]$sb.AppendLine(('[{0}] {1}: {2}' -f [string]$x['Severity'], [string]$x['Code'], [string]$x['Text']))
    }
    $Script:Ui.ConflictsBox.Text = $sb.ToString()
}

function Update-Details {
    $sel = Get-Seq $Script:Ui.Grid.SelectedItems
    if ($sel.Count -eq 0) { $Script:Ui.DetailsBox.Text = ''; return }
    $sb = [System.Text.StringBuilder]::new()
    foreach ($row in $sel) {
        $it = Find-ItemByRow $row
        if (-not $it) { continue }
        $dn = [string]$it['Name']
        if (-not $dn) { $dn = Get-T 'no_modinfo' }
        [void]$sb.AppendLine(('== {0}  [{1}]' -f $dn, [string]$it['WorkshopId']))
        foreach ($sub in $it['Mods']) {
            [void]$sb.AppendLine(('  modID  : {0}' -f [string]$sub['Id']))
            [void]$sb.AppendLine(('  name   : {0}' -f [string]$sub['Name']))
            if ($sub['Url']) { [void]$sb.AppendLine(('  url    : {0}' -f [string]$sub['Url'])) }
            $reqs = [string[]]$sub['Requires']
            if ($reqs.Count -gt 0) { [void]$sb.AppendLine(('  require: {0}' -f ($reqs -join ', '))) }
        }
        if ($it['Quarantined']) { [void]$sb.AppendLine(('  status : ' + (Get-T 'st_quarantine'))) }
        $wsUrl = Get-WorkshopUrl ([string]$it['WorkshopId'])
        if ($wsUrl) { [void]$sb.AppendLine(('  workshop: {0}' -f $wsUrl)) }
        [void]$sb.AppendLine(('  path   : {0}' -f [string]$it['Folder']))
 # the Workshop page description, fetched and cached for the user
        $wid = [string]$it['WorkshopId']
        if ($wid -match '^\d+$') {
            $desc = Format-WorkshopDescription $wid
            if ($desc) {
                [void]$sb.AppendLine('')
                [void]$sb.Append($desc)
            } elseif ($Script:Prefetch) {
                [void]$sb.AppendLine('')
                [void]$sb.AppendLine(('  ' + (Get-T 'ws_none')))
            }
        }
        [void]$sb.AppendLine('')
    }
    $Script:Ui.DetailsBox.Text = $sb.ToString()
}

function Select-Save([object]$Sv) {
    $Script:Save = $Sv
    $Script:SaveMods = [System.Collections.Generic.List[string]]::new()
    if ($Sv) {
        $m = [string[]]$Sv['Mods']
        if ($m) { $Script:SaveMods.AddRange($m) }
    }
    $Script:Analysis = Invoke-Analysis $Script:Items ([string[]]$Script:SaveMods.ToArray())
    Update-Grid
    Update-Conflicts
}

# =============================================================================
# Navigation: everything happens inside THIS window - views swap in place
# =============================================================================
function Show-View([string]$Name) {
    $u = $Script:Ui
    if (-not $u) { return }
    $Script:View = [string]$Name
    $u.HomeView.Visibility = 'Collapsed'
    $u.WorkView.Visibility = 'Collapsed'
    $u.OptView.Visibility = 'Collapsed'
    $u.AdvancedBar.Visibility = 'Collapsed'
    switch ($Name) {
        'home' {
            $u.HomeView.Visibility = 'Visible'
            $u.BtnManual.Content = Get-T 'btn_manual'
        }
        'work' {
            $u.WorkView.Visibility = 'Visible'
            $u.AdvancedBar.Visibility = 'Visible'
            $u.BtnManual.Content = Get-T 'btn_manual_hide'
        }
        'opt' {
            Show-OptimizeView
            $u.BtnManual.Content = Get-T 'btn_manual'
        }
    }
}

# =============================================================================
# The home card: the program tells the story, one green button at most
# =============================================================================
function Add-HomeLine([string]$Line) {
    if (-not $Script:HomeLines) { $Script:HomeLines = [System.Collections.Generic.List[string]]::new() }
    if ($Line -ne '') { $Script:HomeLines.Add($Line) } else { $Script:HomeLines.Add('') }
    if ($Script:Ui -and $Script:Ui.SpDetail) { $Script:Ui.SpDetail.Text = ($Script:HomeLines.ToArray() -join "`n") }
}

function Clear-HomeLines {
    $Script:HomeLines = [System.Collections.Generic.List[string]]::new()
    if ($Script:Ui -and $Script:Ui.SpDetail) { $Script:Ui.SpDetail.Text = '' }
}

function Pump-Home([string]$StepText) {
    try {
        if ($StepText) { Add-HomeLine $StepText }
        if ($Script:Ui -and $Script:Ui.Wnd) {
 # the (DispatcherPriority, Delegate) overload RETURNS a
 # value (null for an action). A bare call writes that null to
 # the pipeline - and whatever this function leaked used to land
 # in the caller's return value. [void] keeps the pipe clean.
            [void]$Script:Ui.Wnd.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
        }
    } catch { }
}

function Set-HomeButtons([string]$Action1, [string]$Label1, [string]$Action2, [string]$Label2) {
    $u = $Script:Ui
    $Script:SpAction1 = [string]$Action1
    $Script:SpAction2 = [string]$Action2
    if ($Label1) { $u.SpBtn1.Content = $Label1; $u.SpBtn1.Visibility = 'Visible' } else { $u.SpBtn1.Visibility = 'Collapsed' }
    if ($Label2) { $u.SpBtn2.Content = $Label2; $u.SpBtn2.Visibility = 'Visible' } else { $u.SpBtn2.Visibility = 'Collapsed' }
}

function Set-Home([string]$Kind) {
    $Script:HomeKind = [string]$Kind
    Render-Home
}

function Render-Home {
    $u = $Script:Ui
    if (-not $u) { return }
    $kind = [string]$Script:HomeKind
    $u.SpConfirm.Visibility = 'Collapsed'
    $items = [object[]]$Script:Items
    if ($null -eq $items) { $items = [object[]]@() }
    $saves = [object[]]$Script:Saves
    if ($null -eq $saves) { $saves = [object[]]@() }
    $cnt = Get-ProblemCount $Script:Analysis
    $u.SpStats.Text = [string]((Get-T 'sp_stats') -f $items.Count, $saves.Count, $cnt)
 # the card is the message in every state - 'allgood' included:
 # the title says it, the check's own action log sits right below
    $u.HomeCard.Visibility = 'Visible'
    switch ($kind) {
        'welcome' {
            $u.SpIcon.Text = '!'
            $u.SpIcon.Foreground = '#C9963C'
            $u.SpTitle.Text = Get-T 'wiz_welcome'
            Add-HomeLine (Get-T 'wiz_sub')
            Set-HomeButtons '' $null '' $null
        }
        'scanning' {
            $u.SpIcon.Text = '…'
            $u.SpIcon.Foreground = '#8A9A5B'
            if ($Script:FirstRun) { $u.SpTitle.Text = Get-T 'wiz_welcome' }
            else { $u.SpTitle.Text = Get-T 'state_scanning' }
            Set-HomeButtons '' $null '' $null
        }
        'noitems' {
            $u.SpIcon.Text = '?'
            $u.SpIcon.Foreground = '#C9963C'
            $u.SpTitle.Text = Get-T 'wiz_noitems'
            Clear-HomeLines
            Add-HomeLine (Get-T 'sp_no_items')
            Set-HomeButtons '' $null '' $null
        }
        'allgood' {
 # the house-and-hearts cartoon is retired. The card
 # carries the good news itself: the big victory line on
 # top, the check's own action log right below it
            $u.SpIcon.Text = '✓'
            $u.SpIcon.Foreground = '#8FBC6F'
            $u.SpTitle.Text = Get-T 'fun_text'
            if ($saves.Count -eq 0) {
                Add-HomeLine ''
                Add-HomeLine (Get-T 'fun_note_nosaves')
                Set-HomeButtons 'zomboid' (Get-T 'btn_zomboid') '' $null
            } else {
                Set-HomeButtons '' $null '' $null
            }
        }
        'idle' {
            $u.SpIcon.Text = '1'
            $u.SpIcon.Foreground = '#8FBC6F'
            $u.SpTitle.Text = Get-T 'idle_title'
            Clear-HomeLines
            Add-HomeLine (Get-T 'idle_sub')
            Set-HomeButtons '' $null '' $null
        }
        'found' {
            $u.SpIcon.Text = '!'
            $u.SpIcon.Foreground = '#C9963C'
            $u.SpTitle.Text = [string]((Get-T 'sp_title_bad') -f $cnt)
            Clear-HomeLines
            if ($Script:Analysis) {
                foreach ($f in [object[]]$Script:Analysis['Findings']) {
                    if ($null -eq $f) { continue }
                    Add-HomeLine ('[{0}] {1}' -f [string]$f['Severity'], [string]$f['Text'])
                }
            }
            if ($saves.Count -eq 0) {
                Add-HomeLine ''
                Add-HomeLine (Get-T 'done_nosaves')
                Set-HomeButtons 'fix' (Get-T 'action_fix') 'zomboid' (Get-T 'btn_zomboid')
            } else {
                Set-HomeButtons 'fix' (Get-T 'action_fix') '' $null
            }
        }
        'fixing' {
            $u.SpIcon.Text = '…'
            $u.SpIcon.Foreground = '#8A9A5B'
            $u.SpTitle.Text = Get-T 'state_fixing'
            Set-HomeButtons '' $null '' $null
        }
        'done' {
            $u.SpIcon.Text = '!'
            $u.SpIcon.Foreground = '#C9963C'
            $u.SpTitle.Text = [string]((Get-T 'done_title') -f [int]$Script:FixBefore, $cnt)
            Add-HomeLine ''
            Add-HomeLine ((Get-T 'done_left') -f $cnt, (Get-RemainingSummary $cnt))
            if ($saves.Count -eq 0) {
                Add-HomeLine ''
                Add-HomeLine (Get-T 'done_nosaves')
                Set-HomeButtons 'recheck' (Get-T 'action_recheck') 'zomboid' (Get-T 'btn_zomboid')
            } else {
                Set-HomeButtons 'recheck' (Get-T 'action_recheck') '' $null
            }
        }
        default {
            $u.SpIcon.Text = '…'
            $u.SpIcon.Foreground = '#8A9A5B'
            $u.SpTitle.Text = Get-T 'state_scanning'
            Set-HomeButtons '' $null '' $null
        }
    }
 # a step that failed on a live machine stays visible on the
 # card no matter how often it re-renders - silence helps nobody
    if ($Script:FlowError) {
        Add-HomeLine ''
        Add-HomeLine $Script:FlowError
    }
}

# =============================================================================
# The merged flow: ONE button checks AND fixes
# =============================================================================
function Write-CrashLog([string]$Phase, $Err) {
 # the silent black box. The UI never shows it; the file keeps the
 # exact failing line and the full stack so the next "interrupted" report
 # is the last one. Lives next to the settings.
    try {
        $line = 0
        try { $line = [int]$Err.InvocationInfo.ScriptLineNumber } catch { }
        $stack = ''
        try { $stack = [string]$Err.ScriptStackTrace } catch { }
        $msg = ''
        try { $msg = [string]$Err.Exception.Message } catch { }
        $dir = Get-SettingsDir
        try {
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        } catch { }
        $p = Join-Path $dir 'pzwd-crash.log'
        $txt = ("[{0}] {1}: {2} (line {3})`r`n{4}`r`n" -f ([datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')), $Phase, $msg, $line, $stack)
        [System.IO.File]::AppendAllText($p, $txt, [System.Text.UTF8Encoding]::new($false))
    } catch { }
}

function Invoke-FullScan {
 # every discovery phase runs in its own guard. A live machine
 # kept throwing "Cannot index into a null array" at this step; whatever
 # dies here now costs one phase, never the whole check, and the black
 # box keeps the exact line for the next report. Null shapes are
 # normalized on the way in: an unwrapped empty return must never again
 # become a null that someone tries to index.
    $hint = ''
    $noSteamMsg = [string](Get-T 'msg_no_steam_local')
    if ($SteamPath) {
        $hint = $SteamPath
    } elseif ($Script:Ui.PathBox.Text -and ($Script:Ui.PathBox.Text.Trim() -ne $noSteamMsg)) {
        $hint = $Script:Ui.PathBox.Text.Trim()
    }
    $steam = $null
    $workshop = [object[]]@()
    $libs = [object[]]@()
    try {
        $steam = Find-SteamRoot $hint
    } catch {
        $steam = $null
        Write-CrashLog 'Find-SteamRoot' $_
    }
    if ($steam) {
        $Script:Steam = [string]$steam
        try { if ($Script:Ui.PathBox.Text -ne $steam) { $Script:Ui.PathBox.Text = [string]$steam } } catch { }
        Set-StatusText ((Get-T 'auto_steam') -f $steam)
        try {
            $libs = [object[]](Get-SteamLibraries $steam)
            if ($null -eq $libs) { $libs = [object[]]@() }
        } catch {
            $libs = [object[]]@()
            Write-CrashLog 'Get-SteamLibraries' $_
        }
        try {
            $workshop = [object[]](Get-WorkshopItems $libs)
            if ($null -eq $workshop) { $workshop = [object[]]@() }
        } catch {
            $workshop = [object[]]@()
            Write-CrashLog 'Get-WorkshopItems' $_
        }
    } else {
        $Script:Steam = $null
        try { $Script:Ui.PathBox.Text = $noSteamMsg } catch { }
        Set-StatusText $noSteamMsg
    }
    $game = $null
    try { $game = Find-PZInstall $libs } catch { }
    try {
        if ($game) { $Script:Ui.GameBox.Text = [string]$game } else { $Script:Ui.GameBox.Text = [string](Get-T 'msg_no_game') }
    } catch { }
    $local = [object[]]@()
    try {
        $local = [object[]](Get-LocalMods (Get-ZomboidRoot))
        if ($null -eq $local) { $local = [object[]]@() }
    } catch {
        $local = [object[]]@()
        Write-CrashLog 'Get-LocalMods' $_
    }
    if ($local.Count -gt 0) { Set-StatusText ((Get-T 'msg_local_added') -f $local.Count) }
 # normalize on the way in - leaked nulls and nested arrays die
 # here, before any consumer can trip over them
    $Script:Items = Normalize-Items ($workshop + $local)
    $Script:Saves = [object[]]@()
    try {
        $savesRead = [object[]](Get-PZSaves)
        if ($null -ne $savesRead -and $savesRead.Count -gt 0) { $Script:Saves = $savesRead }
    } catch {
        Write-CrashLog 'Get-PZSaves' $_
    }
 # the union of every save's mod lists lives in one function now
 # - it is rebuilt after every rewrite, not only at scan time
    Reset-SaveAggregates
    $labels = [System.Collections.Generic.List[string]]::new()
    foreach ($sv in $Script:Saves) {
        if ($null -eq $sv) { continue }
        try { $labels.Add([string]$sv['Label']) } catch { }
    }
    try { $Script:Ui.SavesList.ItemsSource = $labels.ToArray() } catch { }
    $firstSave = $null
    try {
        if ($Script:Saves.Count -gt 0 -and $null -ne $Script:Saves[0]) { $firstSave = $Script:Saves[0] }
    } catch { }
    if ($firstSave) {
        try { $Script:Ui.SavesList.SelectedIndex = 0 } catch { }
        try { Select-Save $firstSave } catch { Write-CrashLog 'Select-Save' $_ }
        try { Set-StatusText ((Get-T 'auto_save') -f [string]$firstSave['Label']) } catch { }
    } else {
        try { Select-Save $null } catch { Write-CrashLog 'Select-Save(null)' $_ }
        Set-StatusText (Get-T 'msg_no_saves')
    }
    try { Update-Grid } catch { Write-CrashLog 'Update-Grid' $_ }
    try { Update-Conflicts } catch { Write-CrashLog 'Update-Conflicts' $_ }
}

function Render-CheckResult {
    $items = [object[]]$Script:Items
    if ($null -eq $items) { $items = [object[]]@() }
    $saves = [object[]]$Script:Saves
    if ($null -eq $saves) { $saves = [object[]]@() }
    $cnt = Get-ProblemCount $Script:Analysis
    if ($items.Count -eq 0) {
        Set-Home 'noitems'
    } elseif ($cnt -le 0) {
 # Nothing to fix = the good-news card: the title on top, the
 # action log below (the missing-saves note and the folder
 # button ride along inside 'allgood' itself)
        Set-Home 'allgood'
    } else {
        Set-Home 'found'
    }
    Set-StatusText ((Get-T 'status_checked') -f $cnt)
    if ($Script:FlowError) {
 # the round died on a real error - the horde catches the
 # survivor and eats him right on the street, so the failure is
 # impossible to miss (the exact line is already on the card)
        Invoke-SceneDeath
    } else {
 # the walk ends with the round: the survivor reaches the end of the
 # road, celebrates, and the chasing horde drops dead behind him
        Invoke-SceneFinish $true ([string]((Get-T 'scene_checked') -f $cnt))
    }
}

function Invoke-CheckFlow {
    Invoke-Safe {
        if ($Script:Busy) { return }
        $Script:Busy = $true
        Stop-DownloadWatch
        $Script:FlowError = ''
        Clear-HomeLines
        Set-Home 'scanning'
 # the walk IS the progress bar: the survivor sets off along the
 # road with the horde at his heels, and reaches the end when the
 # round is over
        Start-SceneRun
        $stepName = (Get-T 'step_scan1')
        try {
            try { [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait } catch { }
            Set-StatusText (Get-T 'status_scan')
            Set-SceneProgress 0.04
            Pump-Home (Get-T 'step_scan1')
            Set-SceneProgress 0.10
            Invoke-FullScan
            $stepName = (Get-T 'step_scan2')
            Set-SceneProgress 0.85
            Pump-Home (Get-T 'step_scan2')
            $saveModsArr = [string[]]@()
            if ($Script:SaveMods) { $saveModsArr = [string[]]$Script:SaveMods.ToArray() }
            $Script:Analysis = Invoke-Analysis $Script:Items $saveModsArr
            $stepName = (Get-T 'step_scan3')
            Set-SceneProgress 0.95
            Pump-Home (Get-T 'step_scan3')
        } catch {
 # the failing LINE travels with the message, and the full
 # stack lands in the crash log - a named step alone was not
 # enough to finish this hunt. The line is sticky: card re-renders
 # must not wipe it away.
            $lineNo = 0
            try { $lineNo = [int]$_.InvocationInfo.ScriptLineNumber } catch { }
            Write-CrashLog ('check: ' + $stepName) $_
            $Script:FlowError = [string]((Get-T 'step_failed') -f $stepName, [string]$_.Exception.Message, $lineNo)
            try { Add-HomeLine $Script:FlowError } catch { }
            try { Set-StatusText ((Get-T 'err_line') -f [string]$_.Exception.Message) } catch { }
        } finally {
            $Script:Busy = $false
            try { [System.Windows.Input.Mouse]::OverrideCursor = $null } catch { }
        }
 # Workshop descriptions for the details panel (background, cached)
        $wids = [System.Collections.Generic.List[string]]::new()
        foreach ($it in $Script:Items) {
            if ($null -eq $it) { continue }
            $w = [string]$it['WorkshopId']
            if ($w -match '^\d+$' -and -not $wids.Contains($w)) { $wids.Add($w) }
        }
        Start-WorkshopPrefetch ([string[]]$wids.ToArray())
        Render-CheckResult
 # something always moves after an action: the street gets a fresh
 # wave right now
        Invoke-SceneAction
    }
}

function Show-HomeConfirm([string]$Text, [string]$YesLabel, [scriptblock]$YesAction, [scriptblock]$NoAction) {
    $Script:ConfirmYes = $YesAction
    $Script:ConfirmNo = $NoAction
    $u = $Script:Ui
    $u.SpConfirmText.Text = $Text
    $u.SpConfirmYes.Content = $YesLabel
    $u.SpConfirmNo.Content = Get-T 'skip'
    $u.SpBtn1.Visibility = 'Collapsed'
    $u.SpBtn2.Visibility = 'Collapsed'
    $u.SpConfirm.Visibility = 'Visible'
}

function Invoke-FixFlow {
    Invoke-Safe {
        if ($Script:Busy) { return }
        if (@($Script:Items).Count -eq 0) { return }
        Stop-DownloadWatch
        $saveModsArr = [string[]]@()
        if ($Script:SaveMods) { $saveModsArr = [string[]]$Script:SaveMods.ToArray() }
        $Script:Analysis = Invoke-Analysis $Script:Items $saveModsArr
        $before = Get-ProblemCount $Script:Analysis
        if ($before -le 0) { Render-CheckResult; return }
        $Script:FixBefore = [int]$before
        $Script:Busy = $true
        try { [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait } catch { }
        Clear-HomeLines
        Set-Home 'fixing'
 # the repair round walks the same road: outrun the horde again
        Start-SceneRun
        Set-SceneProgress 0.08
        $quar = @($Script:Items | Where-Object { $_['Quarantined'] })
        if ($quar.Count -gt 0) {
            $Script:Busy = $false
            try { [System.Windows.Input.Mouse]::OverrideCursor = $null } catch { }
            $Script:PendingQuar = [object[]]$quar
            $names = [System.Text.StringBuilder]::new()
            foreach ($q in $quar) { [void]$names.AppendLine('  ' + [string]$q['Folder']) }
            $text = (Get-T 'quar_confirm') -f $quar.Count, "`n", $names.ToString()
            $yes = (Get-T 'quar_yes') -f $quar.Count
            Show-HomeConfirm $text $yes { Invoke-FixQuarantine $true } { Invoke-FixQuarantine $false }
            return
        }
        Invoke-FixBrokenStep
    }
}

function Invoke-FixQuarantine([bool]$Proceed) {
    Invoke-Safe {
        $quar = [object[]]$Script:PendingQuar
        $Script:PendingQuar = [object[]]@()
        $Script:Busy = $true
        try { [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait } catch { }
        try {
            if ($Proceed -and $quar.Count -gt 0) {
                $cleaned = Remove-QuarantineItems $Script:Items
                $Script:Items = Normalize-Items $cleaned['Items']
                $mb = '{0:N1} MB' -f ([double]$cleaned['Bytes'] / 1MB)
                Add-HomeLine ((Get-T 'quar_removed') -f [int]$cleaned['Removed'], $mb)
                Pump-Home ''
            }
        } finally { }
        Invoke-FixBrokenStep
    }
}

function Invoke-FixBrokenStep {
    Invoke-Safe {
        $broken = @($Script:Items | Where-Object { $_['Broken'] })
        if ($broken.Count -gt 0) {
            $Script:Busy = $false
            try { [System.Windows.Input.Mouse]::OverrideCursor = $null } catch { }
            $Script:PendingBroken = [object[]]$broken
            $names = [System.Text.StringBuilder]::new()
            foreach ($b in $broken) { [void]$names.AppendLine('  ' + [string]$b['Folder']) }
            $text = (Get-T 'broken_confirm') -f $broken.Count, "`n", $names.ToString()
            $yes = (Get-T 'broken_yes') -f $broken.Count
            Show-HomeConfirm $text $yes { Invoke-FixBroken $true } { Invoke-FixBroken $false }
            return
        }
        Invoke-FixSyncStep
    }
}

function Invoke-FixBroken([bool]$Proceed) {
    Invoke-Safe {
        $broken = [object[]]$Script:PendingBroken
        $Script:PendingBroken = [object[]]@()
        $Script:Busy = $true
        try { [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait } catch { }
        if ($Proceed -and $broken.Count -gt 0) {
            $rb = Repair-BrokenItems $Script:Items
            $Script:Items = Normalize-Items $rb['Items']
            $mb = '{0:N1} MB' -f ([double]$rb['Bytes'] / 1MB)
            Add-HomeLine ((Get-T 'broken_removed') -f [int]$rb['Removed'], $mb)
            Pump-Home ''
        }
        Invoke-FixSyncStep
    }
}

function Invoke-FixSyncStep {
    Invoke-Safe {
        Set-SceneProgress 0.55
        try {
            $sync = Repair-SyncSaves $Script:Items $Script:Saves
            foreach ($ln in [object[]]$sync['Lines']) { Add-HomeLine ([string]$ln) }
            Pump-Home ''
            Invoke-FullScan
            $saveModsArr = [string[]]@()
            if ($Script:SaveMods) { $saveModsArr = [string[]]$Script:SaveMods.ToArray() }
            $Script:Analysis = Invoke-Analysis $Script:Items $saveModsArr
            $after = Get-ProblemCount $Script:Analysis
            Set-SceneProgress 0.9
            if ($after -lt [int]$Script:FixBefore) {
 # the street celebrates a real repair: zombies drop, the
 # score slides across the scene
                Invoke-SceneVictory ([int]$Script:FixBefore) ([int]$after)
            }
            Add-HomeLine ''
            Add-HomeLine ((Get-T 'sp_fixed_line') -f [int]$Script:FixBefore, $after, [int]$sync['Added'])
            if ($after -le 0) {
 # the score line is already in the action log above -
 # the allgood card shows it right where the user reads
                Set-Home 'allgood'
            } else {
 # mods that are still missing get looked up in the Workshop
 # and downloaded while the window stays alive
                Invoke-FixMissingStep
            }
            Set-StatusText ((Get-T 'status_checked') -f $after)
        } catch {
 # a repair that dies plays the death scene too - the
 # horde eats the survivor while the card keeps the exact line
            $lineNo = 0
            try { $lineNo = [int]$_.InvocationInfo.ScriptLineNumber } catch { }
            Write-CrashLog ('fix: sync step') $_
            $Script:FlowError = [string]((Get-T 'step_failed') -f (Get-T 'step_scan2'), [string]$_.Exception.Message, $lineNo)
            try { Add-HomeLine $Script:FlowError } catch { }
            try { Set-StatusText ((Get-T 'err_line') -f [string]$_.Exception.Message) } catch { }
            Invoke-SceneDeath
        } finally {
            $Script:Busy = $false
            try { [System.Windows.Input.Mouse]::OverrideCursor = $null } catch { }
        }
    }
}

# =============================================================================
# Missing mods: find them in the Workshop, open the subscribe pages, then
# watch the workshop folders - the moment Steam lands the files, the full
# check (and the rest of the fix chain) fires by itself.
# =============================================================================
function Invoke-FixMissingStep {
    Invoke-Safe {
        $items = [object[]]$Script:Items
        $allSave = [string[]]@()
        try { $allSave = [string[]]$Script:AllSaveMods.ToArray() } catch { }
        $missIds = [string[]](Get-MissingRequirementIds $items $allSave $Script:Analysis)
 # missing id -> the save-mods that demand it: needed to switch
 # off the ones whose requirement does not exist in the Workshop
        $Script:MissingMap = Get-MissingRequirementMap $items $allSave $Script:Analysis
        $byWid = @{}
        foreach ($it in $items) { $w = [string]$it['WorkshopId']; if ($w) { $byWid[$w] = $true } }
        $missWids = [System.Collections.Generic.List[string]]::new()
        try {
            foreach ($w in [string[]]$Script:AllWorkshops.ToArray()) {
                if ($w -match '^\d+$' -and -not $byWid.ContainsKey($w) -and -not $missWids.Contains($w)) { $missWids.Add($w) }
            }
        } catch { }
        if ($missIds.Count -eq 0 -and $missWids.Count -eq 0) {
            Set-Home 'done'
            Invoke-SceneFinish $true ([string]((Get-T 'scene_checked') -f (Get-ProblemCount $Script:Analysis)))
            return
        }
 # 'done' first: even if the background lookup never starts, the
 # card never stays stuck on "Fixing..."
        Set-Home 'done'
        Start-MissingResolver ([string[]]$missIds) ([string[]]$missWids.ToArray())
    }
}

function Start-MissingResolver([string[]]$ModIds, [string[]]$Wids) {
 # The Workshop lookup runs in a background runspace: the search page can
 # take seconds and the window must stay alive.
    Invoke-Safe {
        if ($Script:MissingJob) { return }
        Set-StatusText (Get-T 'miss_searching')
        $code = @'
param([string[]]$modIds, [string[]]$wids, [string]$version)
$ErrorActionPreference = 'SilentlyContinue'
$api = 'https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/'
function Get-Details([string[]]$ids) {
    $out = @{}
    for ($off = 0; $off -lt $ids.Count; $off += 20) {
        $chunk = @($ids | Select-Object -Skip $off -First 20)
        if ($chunk.Count -eq 0) { continue }
        $body = 'itemcount=' + $chunk.Count
        for ($k = 0; $k -lt $chunk.Count; $k++) { $body += '&publishedfileids[' + $k + ']=' + $chunk[$k] }
        try {
            $resp = Invoke-RestMethod -Method Post -Uri $api -Body $body -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 15
            foreach ($d in @($resp.response.publishedfiledetails)) {
                if ([int]$d.result -eq 1) { $out[[string]$d.publishedfileid] = @{ title = [string]$d.title; description = [string]$d.description } }
            }
        } catch {}
    }
    return $out
}
$results = @()
foreach ($mid in $modIds) {
    $entry = @{ kind = 'mod'; id = [string]$mid; wid = ''; title = '' }
    try {
        $q = [System.Uri]::EscapeDataString($mid)
        $url = 'https://steamcommunity.com/workshop/browse/?appid=108600&browsesort=textsearch&section=readytouseitems&searchtext=' + $q
        $ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) PZWorkshopDoctor/' + $version
        $html = ''
        try { $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -UserAgent $ua; $html = [string]$r.Content } catch {}
        if ($html) {
            $wids2 = [System.Collections.Generic.List[string]]::new()
            foreach ($m in [regex]::Matches($html, 'data-publishedfileid="(\d+)"')) {
                $w = $m.Groups[1].Value
                if ($w -and -not $wids2.Contains($w) -and $wids2.Count -lt 12) { $wids2.Add($w) }
            }
            foreach ($m in [regex]::Matches($html, 'id="Subscription(\d+)"')) {
                $w = $m.Groups[1].Value
                if ($w -and -not $wids2.Contains($w) -and $wids2.Count -lt 12) { $wids2.Add($w) }
            }
            if ($wids2.Count -gt 0) {
                $det = Get-Details ([string[]]$wids2.ToArray())
                $best = ''; $bestTitle = ''; $bestScore = 0
                $needle = [string]$mid.ToLower()
                foreach ($kv in $det.GetEnumerator()) {
                    $title = [string]$kv.Value.title
                    $desc = [string]$kv.Value.description
                    $tl = $title.ToLower(); $dl = $desc.ToLower()
                    $score = 0
                    $rx = [regex]::Escape($needle)
                    if ($dl -match ('mod\s*id\s*[:=]\s*\\?' + $rx + '\b')) { $score = 100 }
                    elseif ($tl -eq $needle) { $score = 90 }
                    elseif ($tl.Contains($needle)) { $score = 70 }
                    elseif ($dl.Contains($needle)) { $score = 50 }
                    if ($score -gt $bestScore) { $bestScore = $score; $best = [string]$kv.Key; $bestTitle = $title }
                }
                if ($bestScore -ge 70) { $entry.wid = $best; $entry.title = $bestTitle }
            }
        }
    } catch {}
    $results += $entry
}
$titles = @{}
if ($wids.Count -gt 0) { $titles = Get-Details $wids }
foreach ($w in $wids) {
    $t = ''
    try { $t = [string]$titles[$w].title } catch {}
    $results += @{ kind = 'wid'; id = [string]$w; wid = [string]$w; title = $t }
}
$results
'@
        $ps = [powershell]::Create()
        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $ps.Runspace = $rs
        [void]$ps.AddScript($code)
        [void]$ps.AddArgument([string[]]$ModIds)
        [void]$ps.AddArgument([string[]]$Wids)
        [void]$ps.AddArgument([string]$Script:Version)
        $Script:MissingJob = @{ Ps = $ps; Iar = $ps.BeginInvoke() }
        if (-not $Script:MissingTimer) {
            $Script:MissingTimer = [System.Windows.Threading.DispatcherTimer]::new()
            $Script:MissingTimer.Interval = [timespan]::FromMilliseconds(800)
            $Script:MissingTimer.Add_Tick({
                Invoke-Safe {
                    if (-not $Script:MissingJob) { return }
                    try {
                        if (-not $Script:MissingJob['Iar'].IsCompleted) { return }
                    } catch { $Script:MissingJob = $null; return }
                    $res = $null
                    try { $res = $Script:MissingJob['Ps'].EndInvoke($Script:MissingJob['Iar']) } catch { }
                    try { $Script:MissingJob['Ps'].Runspace.Close() } catch { }
                    try { $Script:MissingJob['Ps'].Dispose() } catch { }
                    $Script:MissingJob = $null
                    Invoke-MissingOpen $res
                }
            })
        }
        $Script:MissingTimer.Start()
    }
}

function Invoke-MissingOpen($Results) {
 # Runs on the UI thread once the lookup finishes: opens the subscribe
 # pages, logs what was found, and arms the download watch.
 # The runspace emits each entry as its own pipeline object, but the
 # collection still arrives double-wrapped on some PowerShell builds -
 # flatten it defensively so a bare array is never mistaken for an entry
 # (that produced the infamous 'Item ""' line with an empty name).
    Invoke-Safe {
        $entries = [System.Collections.Generic.List[object]]::new()
        foreach ($x in (Get-Seq $Results)) {
            if ($x -is [System.Collections.IDictionary]) { $entries.Add($x) }
            else { foreach ($y in (Get-Seq $x)) { $entries.Add($y) } }
        }
        $toOpen = [System.Collections.Generic.List[string]]::new()
        $toWatch = [System.Collections.Generic.List[string]]::new()
        $needRescan = $false
        foreach ($e in $entries) {
            try {
                $kind = [string]$e['kind']
                $id = [string]$e['id']
                $wid = [string]$e['wid']
                $title = [string]$e['title']
                if ($kind -eq 'mod') {
                    if ($wid) {
                        Add-HomeLine ((Get-T 'miss_found') -f $id, $title)
                        if (-not $toOpen.Contains($wid)) { $toOpen.Add($wid) }
                        if (-not $toWatch.Contains($wid)) { $toWatch.Add($wid) }
                    } else {
 # nothing in the Workshop matches this modID: the
 # requirement cannot be downloaded from anywhere.
 # The honest fix is to switch the mods that demand
 # it off in the saves (a .bak backup is kept) - a
 # search page with nothing on it helps nobody
                        $disabledNow = Invoke-MissingDisable $id
                        if ($disabledNow -gt 0) { $needRescan = $true }
                    }
                } else {
                    if (-not $wid) { continue }
                    $name = $title
                    if (-not $name) { $name = '#' + $wid }
                    Add-HomeLine ((Get-T 'miss_found_wid') -f $name)
                    if (-not $toOpen.Contains($wid)) { $toOpen.Add($wid); $toWatch.Add($wid) }
                }
            } catch { }
        }
        $opened = 0
        foreach ($u in $toOpen) {
            if ($opened -ge 10) { break }
            $url = ''
            if ($u -match '^\d+$') { $url = Get-WorkshopUrl $u } else { $url = $u }
            if (-not $url) { continue }
            try {
                Start-Process -FilePath $url
                $opened++
                Start-Sleep -Milliseconds 250
            } catch { }
        }
        if ($toOpen.Count -gt 0) {
            Add-HomeLine ''
            Add-HomeLine ((Get-T 'miss_opened') -f $opened)
        }
        if ($needRescan) {
 # mods were switched off in the saves: re-read everything and
 # re-count right away, so "problems left" tells the truth
            $beforeRescan = Get-ProblemCount $Script:Analysis
            Invoke-FullScan
            $saveModsArr2 = [string[]]@()
            if ($Script:SaveMods) { $saveModsArr2 = [string[]]$Script:SaveMods.ToArray() }
            $Script:Analysis = Invoke-Analysis $Script:Items $saveModsArr2
            $afterRescan = Get-ProblemCount $Script:Analysis
            Add-HomeLine ((Get-T 'miss_disable_done') -f $afterRescan)
            $Script:FixBefore = [int]$beforeRescan
            Set-Home 'done'
            Invoke-SceneVictory $beforeRescan $afterRescan
        } else {
 # the round is over either way: the walk ends in celebration
            Invoke-SceneFinish $true ([string]((Get-T 'scene_checked') -f (Get-ProblemCount $Script:Analysis)))
        }
 # the card is already 'done' (set before the lookup started) -
 # do not re-render it, or the summary line would duplicate
        if ($Script:HomeKind -ne 'done') { Set-Home 'done' }
        if ($toWatch.Count -gt 0) {
            Set-StatusText (Get-T 'miss_watch')
            Start-DownloadWatch ([string[]]$toWatch.ToArray())
        }
    }
}

function Start-DownloadWatch([string[]]$Wids) {
 # Polls the workshop folders every 10 s: the moment every waited item
 # has landed with its mod.info, the full check fires by itself and the
 # fix chain continues without a single extra click.
    try {
        Stop-DownloadWatch
        if ($Wids.Count -eq 0) { return }
        $roots = [System.Collections.Generic.List[string]]::new()
        $steam = $Script:Steam
        if (-not $steam -and $SteamPath) { $steam = $SteamPath }
        if ($steam) {
            foreach ($lib in [object[]](Get-SteamLibraries $steam)) {
                $c = Join-Path ([string]$lib) 'steamapps\workshop\content\108600'
                if (Test-Path -LiteralPath $c) { $roots.Add($c) }
            }
        }
        if ($roots.Count -eq 0) { return }
        $Script:WatchWids = [string[]]$Wids
        $Script:WatchRoots = [string[]]$roots.ToArray()
        $Script:WatchDeadline = [datetime]::UtcNow.AddMinutes(20)
        $t = [System.Windows.Threading.DispatcherTimer]::new()
        $t.Interval = [timespan]::FromSeconds(10)
        $t.Add_Tick({
            Invoke-Safe {
                if (-not $Script:WatchTimer) { return }
                if ($Script:Busy) { return }
                if ([datetime]::UtcNow -gt $Script:WatchDeadline) { Stop-DownloadWatch; return }
                $ready = $true
                foreach ($w in $Script:WatchWids) {
                    $found = $false
                    foreach ($root in $Script:WatchRoots) {
                        $folder = Join-Path $root $w
                        if (Test-Path -LiteralPath $folder) {
                            $mi = Get-ChildItem -LiteralPath $folder -Filter 'mod.info' -Recurse -Depth 5 -ErrorAction SilentlyContinue | Select-Object -First 1
                            if ($mi) { $found = $true; break }
                            if (Test-ContentPack $folder) { $found = $true; break }
                        }
                    }
                    if (-not $found) { $ready = $false; break }
                }
                if ($ready) {
                    Stop-DownloadWatch
 # everything landed: the check AND the rest of the fix
 # continue by themselves
                    Invoke-CheckFlow
                    $cntNow = Get-ProblemCount $Script:Analysis
                    if ($cntNow -gt 0) { Invoke-FixFlow }
                }
            }
        })
        $Script:WatchTimer = $t
        $t.Start()
    } catch { }
}

function Stop-DownloadWatch {
    try { if ($Script:WatchTimer) { $Script:WatchTimer.Stop() } } catch { }
    $Script:WatchTimer = $null
}

# =============================================================================
# The living street: a top-down survivor-vs-zombies scene that plays at the
# bottom of the window on EVERY page. No game assets are used (they belong
# to The Indie Stone) - the sprites are hand-built pixel rectangles in the
# game's own palette and camera view. One 33 ms DispatcherTimer drives the
# street; nothing here can block a click: the strip is IsHitTestVisible=False.
# =============================================================================
function Get-SceneW {
    $w = 900.0
    try { if ($Script:Ui -and $Script:Ui.SceneCanvas -and $Script:Ui.SceneCanvas.ActualWidth -gt 40) { $w = [double]$Script:Ui.SceneCanvas.ActualWidth } } catch { }
    return $w
}

function New-SceneSurvivor {
    $c = [System.Windows.Controls.Canvas]::new()
    $c.Width = 28.0
    $c.Height = 30.0
    [void](Add-FunRect $c 10 0 8 4 (New-FunBrush 0x2A 0x24 0x1C))    # hair
    [void](Add-FunRect $c 10 4 8 5 (New-FunBrush 0xC9 0xA8 0x8A))   # face
    [void](Add-FunRect $c 7 9 14 9 (New-FunBrush 0x5A 0x6E 0x3A))   # shirt
    [void](Add-FunRect $c 10 10 6 7 (New-FunBrush 0x44 0x56 0x2C))  # vest
    [void](Add-FunRect $c 21 10 4 7 (New-FunBrush 0x5A 0x6E 0x3A))  # right arm
    $legA = Add-FunRect $c 8 18 5 11 (New-FunBrush 0x2E 0x3A 0x50)   # jeans
    $legB = Add-FunRect $c 15 18 5 11 (New-FunBrush 0x2E 0x3A 0x50)
 # the bat: swings around the shoulder on its own rotate transform
    $bat = [System.Windows.Controls.Canvas]::new()
    $bat.Width = 6.0
    $bat.Height = 16.0
    [void](Add-FunRect $bat 1 0 3 11 (New-FunBrush 0x8A 0x62 0x38))
    [void](Add-FunRect $bat 0 11 6 4 (New-FunBrush 0xA9 0x7B 0x4F))
    [System.Windows.Controls.Canvas]::SetLeft($bat, 22)
    [System.Windows.Controls.Canvas]::SetTop($bat, 4)
    $batRot = [System.Windows.Media.RotateTransform]::new(0)
    $bat.RenderTransform = $batRot
    $bat.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.15)
    [void]$c.Children.Add($bat)
    $rot = [System.Windows.Media.RotateTransform]::new(0)
    $c.RenderTransform = $rot
    $c.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.95)
    return @{ El = $c; LegA = $legA; LegB = $legB; BatRot = $batRot; Rot = $rot }
}

function New-SceneZombie([double]$X, [double]$Y, [bool]$Fast) {
    $c = [System.Windows.Controls.Canvas]::new()
    $c.Width = 26.0
    $c.Height = 28.0
    $skin = New-FunBrush 0x8A 0x9A 0x6B
    [void](Add-FunRect $c 9 0 8 3 (New-FunBrush 0x23 0x28 0x19))    # hair
    [void](Add-FunRect $c 9 3 8 5 $skin)                            # face
    [void](Add-FunRect $c 6 8 14 8 (New-FunBrush 0x3A 0x3D 0x2E))   # torn shirt
    [void](Add-FunRect $c 20 9 6 3 $skin)                           # arms reach forward
    [void](Add-FunRect $c 0 9 6 3 $skin)
    $legA = Add-FunRect $c 7 16 5 10 (New-FunBrush 0x50 0x5C 0x40)
    $legB = Add-FunRect $c 14 16 5 10 (New-FunBrush 0x50 0x5C 0x40)
    if ($Fast) {
 # the runner: darker, faster, rarer - the one that ends runs
        [void](Add-FunRect $c 6 8 14 8 (New-FunBrush 0x2E 0x31 0x24))
    }
    $rot = [System.Windows.Media.RotateTransform]::new(0)
    $c.RenderTransform = $rot
    $c.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.95)
    [System.Windows.Controls.Canvas]::SetLeft($c, $X)
    [System.Windows.Controls.Canvas]::SetTop($c, $Y)
    [void]$Script:Ui.SceneCanvas.Children.Add($c)
    $speed = 9.0 + (Get-SceneRand).NextDouble() * 7.0
    if ($Fast) { $speed = 24.0 + (Get-SceneRand).NextDouble() * 8.0 }
    return @{ El = $c; LegA = $legA; LegB = $legB; Rot = $rot; X = $X; Y = $Y; Dir = 1.0; Speed = $speed; St = 'walk'; T0 = 0.0; Hits = 0; AttackT = 0.0 }
}

function New-SceneBlood([double]$X, [double]$Y, [int]$N) {
    if (-not $Script:Scene) { return }
    for ($k = 0; $k -lt $N; $k++) {
        $r = [System.Windows.Shapes.Rectangle]::new()
        $r.Width = 3.0
        $r.Height = 3.0
        $r.Fill = New-FunBrush 0x8A 0x26 0x26 0.9
        [System.Windows.Controls.Canvas]::SetLeft($r, $X)
        [System.Windows.Controls.Canvas]::SetTop($r, $Y)
        [void]$Script:Ui.SceneCanvas.Children.Add($r)
        $vx = ([double]((Get-SceneRand).Next(-90, 90)) / 10.0)
        $vy = -([double]((Get-SceneRand).Next(20, 130)) / 10.0)
        [void]$Script:Scene['Blood'].Add(@{ El = $r; X = $X; Y = $Y; Vx = $vx; Vy = $vy; T0 = $Script:Scene['T'] })
    }
 # a dark pool grows under the body and slowly dries out
    $pool = [System.Windows.Shapes.Ellipse]::new()
    $pool.Width = 8.0
    $pool.Height = 3.0
    $pool.Fill = New-FunBrush 0x6E 0x1E 0x1E 0.75
    [System.Windows.Controls.Canvas]::SetLeft($pool, ($X - 4))
    [System.Windows.Controls.Canvas]::SetTop($pool, ($Y + 22))
    [void]$Script:Ui.SceneCanvas.Children.Add($pool)
    [void]$Script:Scene['Pools'].Add(@{ El = $pool; X = $X; T0 = $Script:Scene['T'] })
}

function Build-AmbientScene {
 # (Re)draws the street: grass, a fence, asphalt with dashes and cracks,
 # the sidewalk - then parks the survivor and resets the crowd. Called
 # once at startup and again whenever the window is resized.
    if (-not $Script:Ui -or -not $Script:Ui.SceneCanvas) { return }
    try {
        $c = $Script:Ui.SceneCanvas
        $w = Get-SceneW
        $c.Children.Clear()
        [void](Add-FunRect $c 0 0 $w 16 (New-FunBrush 0x23 0x2B 0x18))          # back grass
        for ($x = 6.0; $x -lt $w; $x += 34.0) {
            [void](Add-FunRect $c $x 10 3 8 (New-FunBrush 0x4A 0x40 0x30))      # fence posts
            if (($x + 30.0) -lt $w) { [void](Add-FunRect $c ($x + 3.0) 12 28 2 (New-FunBrush 0x3E 0x36 0x28)) }
        }
        [void](Add-FunRect $c 0 16 $w 3 (New-FunBrush 0x19 0x1D 0x12))          # curb
        [void](Add-FunRect $c 0 19 $w 54 (New-FunBrush 0x33 0x36 0x2B))         # asphalt
        for ($x = 10.0; $x -lt $w; $x += 44.0) {
            [void](Add-FunRect $c $x 44 20 3 (New-FunBrush 0xC3 0xCB 0x8F 0.5)) # centre dashes
        }
        for ($k = 0; $k -lt 14; $k++) {
            $cx = [double]((Get-SceneRand).Next(0, [int][math]::Max(20, [int]$w)))
            $cy = [double]((Get-SceneRand).Next(21, 70))
            [void](Add-FunRect $c $cx $cy 3 2 (New-FunBrush 0x26 0x29 0x21))    # cracks
        }
        [void](Add-FunRect $c 0 73 $w 2 (New-FunBrush 0x26 0x2A 0x1E))          # far curb
        [void](Add-FunRect $c 0 75 $w 17 (New-FunBrush 0x3E 0x42 0x34))         # sidewalk
        $surv = New-SceneSurvivor
        [System.Windows.Controls.Canvas]::SetLeft($surv['El'], ($w * 0.28))
        [System.Windows.Controls.Canvas]::SetTop($surv['El'], 42.0)
        [void]$c.Children.Add($surv['El'])
        $Script:Scene = @{
            W = $w; T = 0.0; Last = [datetime]::UtcNow; Mode = 'fight'; DiedT = 0.0
            NextWave = 1.2; BannerUntil = 0.0; BannerT0 = 0.0
            Prog = 0.0; RunLast = [datetime]::UtcNow; FinishT0 = 0.0; CeleT0 = 0.0
            DecalLast = [datetime]::UtcNow; FrameLast = [datetime]::UtcNow; EatFed = 0.0
            Hearts = [System.Collections.Generic.List[object]]::new()
            Surv = @{ El = $surv['El']; LegA = $surv['LegA']; LegB = $surv['LegB']; BatRot = $surv['BatRot']; Rot = $surv['Rot']
                      X = ($w * 0.28); Y = 42.0; St = 'idle'; Swing = 0.0; Cooldown = 0.0; Home = ($w * 0.28) }
            Zoms = [System.Collections.Generic.List[object]]::new()
            Blood = [System.Collections.Generic.List[object]]::new()
            Pools = [System.Collections.Generic.List[object]]::new()
        }
    } catch {
 # taught the lesson: a silent catch here left the user
 # with a dead road and no clue. The next failure shows itself.
        if (-not $Script:SceneErrShown) {
            $Script:SceneErrShown = $true
            try { Add-HomeLine ((Get-T 'scene_err') -f [string]$_.Exception.Message) } catch { }
        }
    }
}

function Reset-Scene {
    $sc = $Script:Scene
    if (-not $sc) { return }
    try {
        foreach ($z in @($sc['Zoms'].ToArray())) { try { $Script:Ui.SceneCanvas.Children.Remove($z['El']) } catch { } }
        foreach ($b in @($sc['Blood'].ToArray())) { try { $Script:Ui.SceneCanvas.Children.Remove($b['El']) } catch { } }
        foreach ($pp in @($sc['Pools'].ToArray())) { try { $Script:Ui.SceneCanvas.Children.Remove($pp['El']) } catch { } }
        $sc['Zoms'].Clear(); $sc['Blood'].Clear(); $sc['Pools'].Clear()
        foreach ($hh in @($sc['Hearts'].ToArray())) { try { $Script:Ui.SceneCanvas.Children.Remove($hh['El']) } catch { } }
        $sc['Hearts'].Clear()
        $sc['Prog'] = 0.0
        $sc['Surv']['Rot'].Angle = 0
        $sc['Surv']['El'].Opacity = 1
        $sc['Surv']['X'] = $sc['Surv']['Home']
        $sc['Surv']['St'] = 'idle'
        $sc['Mode'] = 'fight'
        $sc['NextWave'] = $sc['T'] + 1.0
        $Script:Ui.SceneDeath.Visibility = 'Collapsed'
        $Script:Ui.SceneDeathBg.Visibility = 'Collapsed'
    } catch { }
}

function Invoke-SceneAction {
 # something just happened (a check finished): give the street a fresh
 # wave right now instead of waiting for the calm timer
    if (-not $Script:Scene) { return }
    $alive = 0
    foreach ($z in $Script:Scene['Zoms']) { if ($z['St'] -eq 'walk' -or $z['St'] -eq 'hit') { $alive++ } }
    if ($alive -lt 2) { $Script:Scene['NextWave'] = $Script:Scene['T'] + 0.2 }
}

function Invoke-SceneVictory([int]$Before, [int]$After) {
 # a repair round really fixed something: the survivor finishes his
 # walk at the end of the road, every zombie drops dead and the score
 # slides across the scene
    Invoke-SceneFinish $true ([string]((Get-T 'scene_fixed') -f $Before, $After))
}

function Step-AmbientScene {
    try {
        $sc = $Script:Scene
        if (-not $sc -or -not $Script:Ui) { return }
        $now = [datetime]::UtcNow
        $dt = ($now - $sc['Last']).TotalSeconds
        $sc['Last'] = $now
        if ($dt -lt 0) { $dt = 0 }
        if ($dt -gt 0.12) { $dt = 0.12 }
        $sc['T'] = [double]$sc['T'] + $dt
        $t = [double]$sc['T']
        $W = [double]$sc['W']
 # --- the victory banner slides in, holds, fades out ---
        if ($Script:Ui.SceneBanner.Visibility -eq 'Visible') {
            if ($t -ge [double]$sc['BannerUntil']) {
                $Script:Ui.SceneBanner.Visibility = 'Collapsed'
            } else {
                $age = $t - [double]$sc['BannerT0']
                $slide = 240.0 * (1.0 - ([math]::Min(0.35, $age) / 0.35))
                $Script:Ui.SceneBannerTt.X = [double]$slide
                $remain = [double]$sc['BannerUntil'] - $t
                $Script:Ui.SceneBanner.Opacity = [math]::Min(1.0, ($remain / 0.5))
            }
        }
 # --- death sequence: the horde eats him where he fell ---
        if ($sc['Mode'] -eq 'died') {
            $k = $t - [double]$sc['DiedT']
 # the survivor falls on his back (slower now - a body is heavy)
            $sc['Surv']['Rot'].Angle = [math]::Min(88.0, ($k / 0.45) * 88.0)
            $Script:Ui.SceneDeathBg.Opacity = [double](0.30 + 0.18 * [math]::Sin(2.0 * [math]::PI * $t / 1.1))
 # every live zombie rushes to the body and feasts
            $bodyX = [double]$sc['Surv']['X']
            $bodyY = [double]$sc['Surv']['Y']
            foreach ($z in $sc['Zoms']) {
                $st = [string]$z['St']
                if ($st -eq 'gone') { continue }
                if ($st -eq 'fall') {
                    $age = $t - [double]$z['T0']
                    $z['Rot'].Angle = [math]::Min(84.0, (($age / 0.35) * 84.0))
                    if ($age -gt 2.6) { try { $Script:Ui.SceneCanvas.Children.Remove($z['El']) } catch { }; $z['St'] = 'gone' }
                    continue
                }
                $dz = $bodyX - [double]$z['X']
                if ([math]::Abs($dz) -gt 15.0) {
 # hungry shuffle to the feast
                    $dir = 1.0
                    if ($dz -lt 0) { $dir = -1.0 }
                    $z['X'] = [double]$z['X'] + ($dir * [math]::Min(([math]::Abs($dz) - 14.0), (46.0 * $dt)))
                    $z['Rot'].Angle = 0.0
                    $wf = [math]::Floor(($t / 0.3) * 2.0) % 2.0
                    if ($wf -lt 1.0) { $z['LegA'].Visibility = 'Visible'; $z['LegB'].Visibility = 'Collapsed' }
                    else { $z['LegA'].Visibility = 'Collapsed'; $z['LegB'].Visibility = 'Visible' }
                } else {
 # feasting: hunched over the body, chewing
                    $z['Rot'].Angle = [double](26.0 + 9.0 * [math]::Sin(2.0 * [math]::PI * $t / 0.42 + [double]$z['Y']))
                    $z['LegA'].Visibility = 'Visible'
                    $z['LegB'].Visibility = 'Visible'
                }
                $zbob = 1.2 * [math]::Sin(2.0 * [math]::PI * $t / 0.55 + [double]$z['Y'])
                [System.Windows.Controls.Canvas]::SetLeft($z['El'], ([double]$z['X'] - 13.0))
                [System.Windows.Controls.Canvas]::SetTop($z['El'], ([double]$z['Y'] + $zbob * 0.7))
            }
 # the pool keeps growing while they eat
            if (($k -gt 0.8) -and (($k - [double]$sc['EatFed']) -gt 0.9)) {
                $sc['EatFed'] = $k
                New-SceneBlood $bodyX $bodyY 3
            }
            Step-SceneDecals
            if ($k -gt 5.4) { Reset-Scene }
            return
        }
 # the progress walk and the finish celebration run their own frames
        if ($sc['Mode'] -eq 'run') { Step-SceneRunFrame $dt; return }
        if ($sc['Mode'] -eq 'finish') { Step-SceneFinishFrame; return }
        $surv = $sc['Surv']
 # --- the survivor ---
        $nearest = $null
        $nearD = 1e9
        foreach ($z in $sc['Zoms']) {
            if ($z['St'] -ne 'walk' -and $z['St'] -ne 'hit') { continue }
            $d = [math]::Abs([double]$z['X'] - [double]$surv['X'])
            if ($d -lt $nearD) { $nearD = $d; $nearest = $z }
        }
        if ($surv['Cooldown'] -gt 0) { $surv['Cooldown'] = [double]$surv['Cooldown'] - $dt }
        if ($surv['St'] -eq 'swing') {
            $surv['Swing'] = [double]$surv['Swing'] + $dt
            $k2 = [math]::Min(0.42, [double]$surv['Swing'])
 # wind-up then the strike, one smooth arc
            if ($k2 -lt 0.2) { $surv['BatRot'].Angle = [double](-80.0 * ($k2 / 0.2)) }
            else { $surv['BatRot'].Angle = [double](-80.0 + 150.0 * (($k2 - 0.2) / 0.22)) }
            if ($surv['Swing'] -ge 0.22 -and $surv['Swing'] - $dt -lt 0.22 -and $nearest) {
 # contact: the zombie takes the hit
                $nearest['Hits'] = [int]$nearest['Hits'] + 1
                $nearest['St'] = 'hit'
                $nearest['T0'] = $t
                $dir = 1.0
                if ([double]$nearest['X'] -lt [double]$surv['X']) { $dir = -1.0 }
                $nearest['X'] = [double]$nearest['X'] + ($dir * 10.0)
                New-SceneBlood ([double]$nearest['X']) ([double]$nearest['Y']) 5
                if ($nearest['Hits'] -ge 2) { $nearest['St'] = 'fall'; $nearest['T0'] = $t }
            }
            if ($surv['Swing'] -ge 0.42) { $surv['St'] = 'idle'; $surv['Cooldown'] = 0.22; $surv['BatRot'].Angle = 0 }
        } elseif ($nearest -and $nearD -le 34.0 -and $surv['Cooldown'] -le 0) {
            $surv['St'] = 'swing'
            $surv['Swing'] = 0.0
            $surv['LegA'].Visibility = 'Visible'
            $surv['LegB'].Visibility = 'Visible'
        } elseif ($nearest) {
            $dir = 1.0
            if ([double]$nearest['X'] -lt [double]$surv['X']) { $dir = -1.0 }
            $surv['X'] = [double]$surv['X'] + ($dir * 18.0 * $dt)
            $surv['BatRot'].Angle = 0
            $wf = [math]::Floor(($t / 0.42) * 2.0) % 2.0
            if ($wf -lt 1.0) { $surv['LegA'].Visibility = 'Visible'; $surv['LegB'].Visibility = 'Collapsed' }
            else { $surv['LegA'].Visibility = 'Collapsed'; $surv['LegB'].Visibility = 'Visible' }
        } else {
 # calm: walk back home and breathe
            $surv['BatRot'].Angle = 0
            $home = [double]$surv['Home']
            if ([math]::Abs([double]$surv['X'] - $home) -gt 5.0) {
                $d2 = 1.0
                if ($home -lt [double]$surv['X']) { $d2 = -1.0 }
                $surv['X'] = [double]$surv['X'] + ($d2 * 14.0 * $dt)
                $wf = [math]::Floor(($t / 0.44) * 2.0) % 2.0
                if ($wf -lt 1.0) { $surv['LegA'].Visibility = 'Visible'; $surv['LegB'].Visibility = 'Collapsed' }
                else { $surv['LegA'].Visibility = 'Collapsed'; $surv['LegB'].Visibility = 'Visible' }
            } else {
                $surv['LegA'].Visibility = 'Visible'
                $surv['LegB'].Visibility = 'Visible'
            }
        }
        $bob = 1.0 * [math]::Sin(2.0 * [math]::PI * $t / 2.0)
        [System.Windows.Controls.Canvas]::SetLeft($surv['El'], ([double]$surv['X'] - 14.0))
        [System.Windows.Controls.Canvas]::SetTop($surv['El'], ([double]$surv['Y'] + $bob * 0.8))
 # --- the zombies ---
        $zKeep = [System.Collections.Generic.List[object]]::new()
        foreach ($z in $sc['Zoms']) {
            $st = [string]$z['St']
            if ($st -eq 'gone') { continue }
            if ($st -eq 'fall') {
                $age = $t - [double]$z['T0']
                $z['Rot'].Angle = [math]::Min(84.0, (($age / 0.35) * 84.0))
                if ($age -gt 1.6) { $z['El'].Opacity = [math]::Max(0.0, (1.0 - (($age - 1.6) / 0.9))) }
                if ($age -gt 2.6) { try { $Script:Ui.SceneCanvas.Children.Remove($z['El']) } catch { }; $z['St'] = 'gone'; continue }
            } elseif ($st -eq 'hit') {
                if (($t - [double]$z['T0']) -gt 0.18) { $z['St'] = 'walk' }
            } else {
 # walk toward the survivor; attack if close enough for long
                $dir = 1.0
                if ([double]$surv['X'] -lt [double]$z['X']) { $dir = -1.0 }
                $z['Dir'] = $dir
                $z['X'] = [double]$z['X'] + ($dir * [double]$z['Speed'] * $dt)
                $wf = [math]::Floor(($t / 0.46) * 2.0) % 2.0
                if ($wf -lt 1.0) { $z['LegA'].Visibility = 'Visible'; $z['LegB'].Visibility = 'Collapsed' }
                else { $z['LegA'].Visibility = 'Collapsed'; $z['LegB'].Visibility = 'Visible' }
                $dxz = [math]::Abs([double]$z['X'] - [double]$surv['X'])
                if ($dxz -le 16.0) {
                    if ([double]$z['AttackT'] -le 0) { $z['AttackT'] = $t }
                    if (($t - [double]$z['AttackT']) -gt 0.9) {
 # the zombie got him: the horde eats him where he fell
                        $sc['Mode'] = 'died'
                        $sc['DiedT'] = $t
                        $sc['EatFed'] = 0.0
                        $surv['St'] = 'idle'
                        try {
                            $Script:Ui.SceneDeath.Text = [string](Get-T 'scene_died')
                            $Script:Ui.SceneDeath.Visibility = 'Visible'
                            $Script:Ui.SceneDeathBg.Visibility = 'Visible'
                        } catch { }
                        New-SceneBlood ([double]$surv['X']) ([double]$surv['Y']) 6
                    }
                } else {
                    $z['AttackT'] = 0.0
                }
            }
            $zbob = 1.2 * [math]::Sin(2.0 * [math]::PI * $t / 1.3 + [double]$z['Y'])
            [System.Windows.Controls.Canvas]::SetLeft($z['El'], ([double]$z['X'] - 13.0))
            [System.Windows.Controls.Canvas]::SetTop($z['El'], ([double]$z['Y'] + $zbob * 0.7))
            [void]$zKeep.Add($z)
        }
        $sc['Zoms'] = $zKeep
        Step-SceneDecals
 # --- the next wave ---
        if ($t -ge [double]$sc['NextWave'] -and $sc['Mode'] -eq 'fight') {
            $alive = 0
            foreach ($z in $sc['Zoms']) { if ($z['St'] -eq 'walk' -or $z['St'] -eq 'hit') { $alive++ } }
            if ($alive -eq 0 -and $sc['Zoms'].Count -lt 5) {
                $n = 2 + (Get-SceneRand).Next(0, 3)
                if ($n -gt 4) { $n = 4 }
                for ($k = 0; $k -lt $n; $k++) {
                    $side = (Get-SceneRand).Next(0, 2)
                    $zx = -18.0
                    if ($side -eq 1) { $zx = $W + 18.0 }
                    $zy = [double](38 + (Get-SceneRand).Next(0, 10))
                    $fast = ((Get-SceneRand).NextDouble() -lt 0.12)
                    [void]$sc['Zoms'].Add((New-SceneZombie $zx $zy $fast))
                }
                $sc['NextWave'] = $t + 6.0 + (Get-SceneRand).NextDouble() * 4.0
            } else {
                $sc['NextWave'] = $t + 1.5
            }
        }
    } catch { }
}

# =============================================================================
# The progress walk (): while a check or a repair round runs, the
# survivor walks the road with the horde at his heels - his position IS
# the progress bar. When the round ends he reaches the end of the road,
# celebrates, and the zombies die. The flow itself pushes the positions at
# every step (Set-SceneProgress / Invoke-SceneFinish), so the bar works even
# on a machine where the animation timer never fires.
# =============================================================================
function Step-ScenePump {
 # a mid-scan breath for the window: pumps the dispatcher so the street
 # (and the whole UI) keeps moving while workshop folders are being read
    try {
        if ($Script:Ui -and $Script:Ui.Wnd) {
 # THE ROOT CAUSE of the step-2 crash: this very call used
 # to run bare. The (DispatcherPriority, Delegate) overload of
 # Dispatcher.Invoke returns the delegate's result - $null for
 # an [action]. PowerShell writes a bare .NET method's return
 # value straight into the pipeline, so every 6th workshop
 # folder leaked one $null into Get-WorkshopItems's output.
 # Those nulls rode into $Script:Items and killed first the grid
 # ("mods are not shown"), then Invoke-Analysis at the famous
 # "line 1033: Cannot index into a null array". [void] swallows
 # the return; the scan's own array stays the only output.
            [void]$Script:Ui.Wnd.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
        }
    } catch { }
    try {
        if ($Script:Scene -and $Script:Scene['Mode'] -eq 'run') {
 # wall-clock creep between the real progress events: the walk
 # never stalls even when the phase boundaries are far apart
            $now = [datetime]::UtcNow
            $sec = ($now - [datetime]$Script:Scene['RunLast']).TotalSeconds
            if ($sec -gt 0.22) {
                $Script:Scene['RunLast'] = $now
                $p = [double]$Script:Scene['Prog'] + 0.016
                if ($p -gt 0.75) { $p = 0.75 }
                Set-SceneProgress $p
            }
        }
    } catch { }
}

function Set-SceneProgress([double]$P) {
 # called by the check/fix flow itself, not only by the timer: the walk
 # advances even on a machine where the animation timer never fires
    if (-not $Script:Scene) { return }
    try {
        if ($P -lt 0.0) { $P = 0.0 }
        if ($P -gt 1.0) { $P = 1.0 }
        if ($P -lt [double]$Script:Scene['Prog']) { return }
        $Script:Scene['Prog'] = $P
 # while the street frames run, the survivor WALKS to the new
 # position at a bounded pace - the road takes seconds, not one
 # frame. Only a dead timer (no frames for 0.6 s) falls back to the
 # instant snap, so the bar still works on a frozen machine.
        $stale = $true
        try { $stale = (([datetime]::UtcNow - [datetime]$Script:Scene['FrameLast']).TotalSeconds -gt 0.6) } catch { }
        if (-not $stale) { return }
        $sc = $Script:Scene
        $surv = $sc['Surv']
        $W = [double]$sc['W']
        $x = 34.0 + ($P * ($W - 84.0))
        if ($x -gt [double]$surv['X']) {
            $surv['X'] = $x
            try { [System.Windows.Controls.Canvas]::SetLeft($surv['El'], ($x - 14.0)) } catch { }
            foreach ($z in $sc['Zoms']) {
                if ($z['St'] -eq 'gone' -or $z['St'] -eq 'fall') { continue }
                $zx = $x - [double]$z['Lag']
                if ($zx -lt -40.0) { $zx = -40.0 }
                $z['X'] = $zx
                try { [System.Windows.Controls.Canvas]::SetLeft($z['El'], ($zx - 13.0)) } catch { }
            }
        }
    } catch { }
}

function Start-SceneRun {
 # a check/fix round begins: the survivor lines up at the start of the
 # road, the horde pours in behind him, and off they go
    if (-not $Script:Ui -or -not $Script:Ui.SceneCanvas) { return }
    try {
        if (-not $Script:Scene) { Start-AmbientEngine }
        if (-not $Script:Scene) { return }
        Reset-Scene
        $sc = $Script:Scene
        $surv = $sc['Surv']
        $surv['Home'] = 34.0
        $surv['X'] = 34.0
        $sc['Mode'] = 'run'
        $sc['Prog'] = 0.0
        $sc['RunLast'] = [datetime]::UtcNow
 # three shamblers chase at a fixed lag behind him
 # they were drawn but never added to Zoms - the walk ran
 # alone and the finish had nobody to kill. Now the horde is real:
 # it chases at his heels and drops dead when he celebrates.
 # Each one is armed in its own guard: a sprite hiccup may cost one
 # shambler, never the whole horde.
        $k = 0
        foreach ($lag in @(74.0, 122.0, 172.0)) {
            $zy = 40.0 + (7.0 * $k)
            try {
                $z = New-SceneZombie (34.0 - $lag) $zy $false
                $z['Lag'] = $lag
                [void]$sc['Zoms'].Add($z)
            } catch { }
            $k++
        }
        try { [System.Windows.Controls.Canvas]::SetLeft($surv['El'], 20.0) } catch { }
    } catch { }
}

function Step-SceneDecals {
 # blood drops fly, pools grow and dry - shared by every scene mode
    try {
        $sc = $Script:Scene
        if (-not $sc) { return }
        $now = [datetime]::UtcNow
        $dt = ($now - [datetime]$sc['DecalLast']).TotalSeconds
        $sc['DecalLast'] = $now
        if ($dt -lt 0) { $dt = 0 }
        if ($dt -gt 0.12) { $dt = 0.12 }
        $t = [double]$sc['T']
        $bKeep = [System.Collections.Generic.List[object]]::new()
        foreach ($b in $sc['Blood']) {
            $age = $t - [double]$b['T0']
            if ($age -gt 0.6) { try { $Script:Ui.SceneCanvas.Children.Remove($b['El']) } catch { }; continue }
            $b['Vy'] = [double]$b['Vy'] + (500.0 * $dt)
            $b['X'] = [double]$b['X'] + ([double]$b['Vx'] * $dt)
            $b['Y'] = [double]$b['Y'] + ([double]$b['Vy'] * $dt)
            if ([double]$b['Y'] -gt 70.0) { $b['Y'] = 70.0; $b['Vy'] = 0.0; $b['Vx'] = 0.0 }
            [System.Windows.Controls.Canvas]::SetLeft($b['El'], [double]$b['X'])
            [System.Windows.Controls.Canvas]::SetTop($b['El'], [double]$b['Y'])
            $b['El'].Opacity = [double](1.0 - ($age / 0.6))
            [void]$bKeep.Add($b)
        }
        $sc['Blood'] = $bKeep
        $pKeep = [System.Collections.Generic.List[object]]::new()
        foreach ($pp in $sc['Pools']) {
            $age = $t - [double]$pp['T0']
            if ($age -gt 7.0) { try { $Script:Ui.SceneCanvas.Children.Remove($pp['El']) } catch { }; continue }
            $gw = [math]::Min(20.0, (8.0 + ($age * 6.0)))
            $pp['El'].Width = [double]$gw
            $pp['El'].Height = [double][math]::Min(6.0, (3.0 + ($age * 1.6)))
            [System.Windows.Controls.Canvas]::SetLeft($pp['El'], ([double]$pp['X'] - ($pp['El'].Width / 2.0)))
            if ($age -gt 4.0) { $pp['El'].Opacity = [double](0.75 * (1.0 - (($age - 4.0) / 3.0))) }
            [void]$pKeep.Add($pp)
        }
        $sc['Pools'] = $pKeep
    } catch { }
}

function Step-SceneRunFrame([double]$Dt) {
 # one frame of the progress walk: the survivor advances along the road
 # with the horde a fixed step behind - no attacks, no death, just the
 # chase that the bar tells
    try {
        $sc = $Script:Scene
        if (-not $sc) { return }
        $sc['FrameLast'] = [datetime]::UtcNow
        $t = [double]$sc['T']
        $W = [double]$sc['W']
        $surv = $sc['Surv']
        $target = 34.0 + ([double]$sc['Prog'] * ($W - 84.0))
        $dx = $target - [double]$surv['X']
 # a real walking pace - capped speed per second, so the
 # road takes seconds instead of a couple of frames. A huge gap
 # (a dead timer that just woke up) still snaps.
        if ([math]::Abs($dx) -gt 300.0) {
            $surv['X'] = $target
        } else {
            $step = 105.0 * $Dt
            if ($step -gt [math]::Abs($dx)) { $step = [math]::Abs($dx) }
            if ($dx -lt 0) { $step = -$step }
            $surv['X'] = [double]$surv['X'] + $step
        }
        if ([double]$surv['X'] -lt 34.0) { $surv['X'] = 34.0 }
        if ([double]$surv['X'] -gt ($W - 50.0)) { $surv['X'] = $W - 50.0 }
        if ([math]::Abs($target - [double]$surv['X']) -gt 1.5) {
 # on the move: alternate the legs, bat over the shoulder
            $wf = [math]::Floor(($t / 0.4) * 2.0) % 2.0
            if ($wf -lt 1.0) { $surv['LegA'].Visibility = 'Visible'; $surv['LegB'].Visibility = 'Collapsed' }
            else { $surv['LegA'].Visibility = 'Collapsed'; $surv['LegB'].Visibility = 'Visible' }
            $surv['BatRot'].Angle = [double](-18.0 * (0.5 + 0.5 * [math]::Sin(2.0 * [math]::PI * $t / 1.1)))
        } else {
 # stalled on a long phase: breathe, keep the bat ready
            $surv['LegA'].Visibility = 'Visible'
            $surv['LegB'].Visibility = 'Visible'
            $surv['BatRot'].Angle = [double](-35.0 + 8.0 * [math]::Sin(2.0 * [math]::PI * $t / 1.4))
        }
        $bob = 1.0 * [math]::Sin(2.0 * [math]::PI * $t / 2.0)
        [System.Windows.Controls.Canvas]::SetLeft($surv['El'], ([double]$surv['X'] - 14.0))
        [System.Windows.Controls.Canvas]::SetTop($surv['El'], ([double]$surv['Y'] + $bob * 0.8))
        foreach ($z in $sc['Zoms']) {
            $st = [string]$z['St']
            if ($st -eq 'gone') { continue }
            if ($st -eq 'fall') {
                $age = $t - [double]$z['T0']
                $z['Rot'].Angle = [math]::Min(84.0, (($age / 0.35) * 84.0))
                if ($age -gt 1.6) { $z['El'].Opacity = [math]::Max(0.0, (1.0 - (($age - 1.6) / 0.9))) }
                if ($age -gt 2.6) { try { $Script:Ui.SceneCanvas.Children.Remove($z['El']) } catch { }; $z['St'] = 'gone'; continue }
                [System.Windows.Controls.Canvas]::SetLeft($z['El'], ([double]$z['X'] - 13.0))
                [System.Windows.Controls.Canvas]::SetTop($z['El'], [double]$z['Y'])
                continue
            }
            $lag = [double]$z['Lag']
            $zx = [double]$surv['X'] - $lag + (4.0 * [math]::Sin(2.0 * [math]::PI * $t / 0.9 + $lag))
            if ($zx -lt -40.0) { $zx = -40.0 }
            $z['X'] = $zx
            $wf = [math]::Floor(($t / 0.46) * 2.0) % 2.0
            if ($wf -lt 1.0) { $z['LegA'].Visibility = 'Visible'; $z['LegB'].Visibility = 'Collapsed' }
            else { $z['LegA'].Visibility = 'Collapsed'; $z['LegB'].Visibility = 'Visible' }
            $zbob = 1.2 * [math]::Sin(2.0 * [math]::PI * $t / 1.3 + [double]$z['Y'])
            [System.Windows.Controls.Canvas]::SetLeft($z['El'], ($zx - 13.0))
            [System.Windows.Controls.Canvas]::SetTop($z['El'], ([double]$z['Y'] + $zbob * 0.7))
        }
        Step-SceneDecals
    } catch { }
}

function Step-SceneFinishFrame {
 # the round is over: the survivor closes the last meters of the road,
 # hops for joy while pixel hearts pop, and the horde drops dead
    try {
        $sc = $Script:Scene
        if (-not $sc) { return }
        $sc['FrameLast'] = [datetime]::UtcNow
        $t = [double]$sc['T']
        $W = [double]$sc['W']
        $surv = $sc['Surv']
        $endX = $W - 50.0
        $age = $t - [double]$sc['FinishT0']
        if ([double]$surv['X'] -lt ($endX - 2.0) -and $age -lt 4.0) {
 # the last calm walk to the end of the road (a human
 # pace - the finish is to be SEEN, not blinked away)
            $step = ($endX - [double]$surv['X']) * 0.12
            if ($step -lt 8.0) { $step = 8.0 }
            if ($step -gt 15.0) { $step = 15.0 }
            $surv['X'] = [double]$surv['X'] + $step
            if ([double]$surv['X'] -gt $endX) { $surv['X'] = $endX }
            $wf = [math]::Floor(($t / 0.36) * 2.0) % 2.0
            if ($wf -lt 1.0) { $surv['LegA'].Visibility = 'Visible'; $surv['LegB'].Visibility = 'Collapsed' }
            else { $surv['LegA'].Visibility = 'Collapsed'; $surv['LegB'].Visibility = 'Visible' }
            $surv['BatRot'].Angle = 0
            [System.Windows.Controls.Canvas]::SetTop($surv['El'], [double]$surv['Y'])
        } else {
 # the celebration: hop, bat held high, hearts pop
            $surv['X'] = $endX
            $hop = [math]::Max(0.0, [math]::Sin(2.0 * [math]::PI * (($t - [double]$sc['CeleT0']) / 0.8)))
            [System.Windows.Controls.Canvas]::SetTop($surv['El'], ([double]$surv['Y'] - ($hop * 11.0)))
            $surv['LegA'].Visibility = 'Visible'
            $surv['LegB'].Visibility = 'Visible'
            $surv['BatRot'].Angle = [double](-98.0 + 9.0 * [math]::Sin(2.0 * [math]::PI * $t / 0.7))
            foreach ($hh in $sc['Hearts']) {
                $ph = ((($t - [double]$sc['CeleT0']) / 2.6) + [double]$hh['Phase']) % 1.0
                [System.Windows.Controls.Canvas]::SetTop($hh['El'], [double](26.0 - 20.0 * $ph))
                $hh['El'].Opacity = [double](1.0 - $ph)
            }
        }
        [System.Windows.Controls.Canvas]::SetLeft($surv['El'], ([double]$surv['X'] - 14.0))
 # the horde dies off behind him
        foreach ($z in $sc['Zoms']) {
            $st = [string]$z['St']
            if ($st -eq 'gone') { continue }
            if ($st -ne 'fall') {
                $z['St'] = 'fall'
                $z['T0'] = $t
                New-SceneBlood ([double]$z['X']) ([double]$z['Y']) 4
            }
            $zage = $t - [double]$z['T0']
            $z['Rot'].Angle = [math]::Min(84.0, (($zage / 0.35) * 84.0))
            if ($zage -gt 1.6) { $z['El'].Opacity = [math]::Max(0.0, (1.0 - (($zage - 1.6) / 0.9))) }
            if ($zage -gt 2.6) { try { $Script:Ui.SceneCanvas.Children.Remove($z['El']) } catch { }; $z['St'] = 'gone'; continue }
            [System.Windows.Controls.Canvas]::SetLeft($z['El'], ([double]$z['X'] - 13.0))
            [System.Windows.Controls.Canvas]::SetTop($z['El'], [double]$z['Y'])
        }
        Step-SceneDecals
 # back to the everyday street after the celebration
        if ($age -gt 11.0) { Reset-Scene }
    } catch { }
}

function Invoke-SceneFinish([bool]$Victory, [string]$BannerText) {
 # the walk ends HERE: the survivor is put on the end of the road in his
 # victory pose right now (works with a dead timer too), the horde drops
 # dead, and the timer-driven frames keep it all moving after that
    if (-not $Script:Ui -or -not $Script:Ui.SceneCanvas) { return }
    try {
        if (-not $Script:Scene) { Start-AmbientEngine }
        if (-not $Script:Scene) { return }
        $sc = $Script:Scene
        $W = [double]$sc['W']
        $sc['Mode'] = 'finish'
        $sc['FinishT0'] = [double]$sc['T']
        $sc['CeleT0'] = [double]$sc['T']
 # every standing zombie drops dead on the spot - one at a time,
 # so a sprite hiccup can never save the rest of the horde
        foreach ($z in @($sc['Zoms'].ToArray())) {
            if ($z['St'] -eq 'gone' -or $z['St'] -eq 'fall') { continue }
            try {
                $z['St'] = 'fall'
                $z['T0'] = [double]$sc['T']
                $z['Rot'].Angle = 84.0
                New-SceneBlood ([double]$z['X']) ([double]$z['Y']) 4
            } catch { }
        }
 # pixel hearts over the victor (no fonts involved) - cosmetic,
 # so they live in their own guard: a heart glitch must never eat
 # the banner that tells the user the round is over
        try {
            foreach ($old in @($sc['Hearts'].ToArray())) { try { $Script:Ui.SceneCanvas.Children.Remove($old['El']) } catch { } }
            $sc['Hearts'].Clear()
            $endX = $W - 50.0
            $k = 0
            foreach ($off in @(-16.0, 4.0, 22.0)) {
            $hc = [System.Windows.Controls.Canvas]::new()
            $hc.Width = 10.0
            $hc.Height = 8.0
            $red = New-FunBrush 0xC0 0x5B 0x4D
            [void](Add-FunRect $hc 0 0 4 3 $red)
            [void](Add-FunRect $hc 6 0 4 3 $red)
            [void](Add-FunRect $hc 0 3 10 2 $red)
            [void](Add-FunRect $hc 2 5 6 2 $red)
            [void](Add-FunRect $hc 4 7 2 1 $red)
            [System.Windows.Controls.Canvas]::SetLeft($hc, ($endX + $off))
            [System.Windows.Controls.Canvas]::SetTop($hc, 26.0)
            [void]$Script:Ui.SceneCanvas.Children.Add($hc)
                [void]$sc['Hearts'].Add(@{ El = $hc; Phase = ([double]$k * 0.33) })
                $k++
            }
        } catch { }
        if ($BannerText -and $Script:Ui.SceneBanner) {
            $Script:Ui.SceneBanner.Text = [string]$BannerText
            $Script:Ui.SceneBanner.Visibility = 'Visible'
            $sc['BannerUntil'] = [double]$sc['T'] + 4.2
            $sc['BannerT0'] = [double]$sc['T']
        }
    } catch { }
}

function Invoke-SceneDeath {
 # the round died on an error - the horde catches the survivor
 # and eats him right on the street, so a failure is impossible to miss.
 # Dinner guests are guaranteed: an empty street gets two zombies
 # delivered next to the body.
    if (-not $Script:Ui -or -not $Script:Ui.SceneCanvas) { return }
    try {
        if (-not $Script:Scene) { Start-AmbientEngine }
        if (-not $Script:Scene) { return }
        $sc = $Script:Scene
        if ($sc['Mode'] -eq 'died') { return }
        $sc['Mode'] = 'died'
        $sc['DiedT'] = [double]$sc['T']
        $sc['EatFed'] = 0.0
        $sc['Surv']['St'] = 'idle'
        $sc['Surv']['BatRot'].Angle = 0
        $sc['BannerUntil'] = 0.0
        try { $Script:Ui.SceneBanner.Visibility = 'Collapsed' } catch { }
        try {
            $Script:Ui.SceneDeath.Text = [string](Get-T 'scene_died')
            $Script:Ui.SceneDeath.Visibility = 'Visible'
            $Script:Ui.SceneDeathBg.Visibility = 'Visible'
        } catch { }
        New-SceneBlood ([double]$sc['Surv']['X']) ([double]$sc['Surv']['Y']) 6
 # dinner guests: at least two live walkers near the body
        $walkers = 0
        foreach ($z in $sc['Zoms']) { if ($z['St'] -eq 'walk' -or $z['St'] -eq 'hit') { $walkers++ } }
        if ($walkers -lt 2) {
            $W = [double]$sc['W']
            $bx = [double]$sc['Surv']['X']
            foreach ($off in @(-90.0, 70.0)) {
                $zx = $bx + $off
                if ($zx -lt -10.0) { $zx = $bx + 110.0 }
                if ($zx -gt ($W + 10.0)) { $zx = $bx - 110.0 }
                try { [void]$sc['Zoms'].Add((New-SceneZombie $zx 46.0 $false)) } catch { }
            }
        }
    } catch { }
}

function Start-AmbientEngine {
 # one timer for the whole show: the street below.
 # It starts with the window and runs until the window dies.
    Invoke-Safe {
        if (-not $Script:Ui -or -not $Script:Ui.SceneCanvas) { return }
        Build-AmbientScene
        if ($Script:SceneTimer) { return }
        $t = [System.Windows.Threading.DispatcherTimer]::new()
        $t.Interval = [timespan]::FromMilliseconds(33)
        $t.Add_Tick({ Invoke-Safe { Step-AmbientScene } })
        $Script:SceneTimer = $t
        $t.Start()
    }
}

# =============================================================================
# Workshop descriptions: background prefetch + cache
# =============================================================================
function Start-WorkshopPrefetch([string[]]$Ids) {
    try {
        if ($Script:Prefetch) { return }
        $todo = [System.Collections.Generic.List[string]]::new()
        foreach ($i in $Ids) {
            if ($i -match '^\d+$' -and -not $Script:WsCache.ContainsKey($i)) { $todo.Add($i) }
        }
        if ($todo.Count -eq 0) { return }
        Set-StatusText (Get-T 'ws_fetching')
        $cachePath = Get-WorkshopCachePath
        $cacheIn = '{}'
        try { if (Test-Path -LiteralPath $cachePath) { $cacheIn = [System.IO.File]::ReadAllText($cachePath) } } catch { }
        $code = @'
param([string[]]$ids, [string]$cacheJson, [string]$cachePath)
$ErrorActionPreference = 'SilentlyContinue'
$cache = @{}
try {
    $o = $cacheJson | ConvertFrom-Json
    foreach ($p in $o.PSObject.Properties) { $cache[$p.Name] = $p.Value }
} catch {}
$api = 'https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/'
for ($off = 0; $off -lt $ids.Count; $off += 20) {
    $chunk = @($ids | Select-Object -Skip $off -First 20)
    if ($chunk.Count -eq 0) { continue }
    $body = 'itemcount=' + $chunk.Count
    for ($k = 0; $k -lt $chunk.Count; $k++) { $body += '&publishedfileids[' + $k + ']=' + $chunk[$k] }
    try {
        $resp = Invoke-RestMethod -Method Post -Uri $api -Body $body -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 15
        foreach ($d in @($resp.response.publishedfiledetails)) {
            if ([int]$d.result -eq 1) {
                $tags = ''
                try { $tags = ((@($d.tags) | ForEach-Object { [string]$_.tag }) -join ', ') } catch {}
                $cache[[string]$d.publishedfileid] = @{
                    title       = [string]$d.title
                    description = [string]$d.description
                    fileSize    = [long]$d.file_size
                    updated     = [long]$d.time_updated
                    tags        = $tags
                    fetched     = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
                }
            }
        }
    } catch {}
}
try {
    $json = ConvertTo-Json -InputObject $cache -Depth 6
    [System.IO.File]::WriteAllText($cachePath, $json, [System.Text.UTF8Encoding]::new($false))
} catch {}
'@
        $ps = [powershell]::Create()
        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $ps.Runspace = $rs
        [void]$ps.AddScript($code)
        [void]$ps.AddArgument([string[]]$todo.ToArray())
        [void]$ps.AddArgument([string]$cacheIn)
        [void]$ps.AddArgument([string]$cachePath)
        $Script:Prefetch = @{ Ps = $ps; Iar = $ps.BeginInvoke(); Ids = [string[]]$todo.ToArray() }
        if (-not $Script:PrefetchTimer) {
            $Script:PrefetchTimer = [System.Windows.Threading.DispatcherTimer]::new()
            $Script:PrefetchTimer.Interval = [timespan]::FromMilliseconds(900)
            $Script:PrefetchTimer.Add_Tick({
                Invoke-Safe {
                    if (-not $Script:Prefetch) { return }
                    try {
                        if (-not $Script:Prefetch['Iar'].IsCompleted) { return }
                    } catch { $Script:Prefetch = $null; return }
                    $req = [string[]]$Script:Prefetch['Ids']
                    try { $null = $Script:Prefetch['Ps'].EndInvoke($Script:Prefetch['Iar']) } catch { }
                    try { $Script:Prefetch['Ps'].Runspace.Close() } catch { }
                    try { $Script:Prefetch['Ps'].Dispose() } catch { }
                    $Script:Prefetch = $null
                    Read-WorkshopCache
                    $hit = 0
                    foreach ($i in $req) { if ($Script:WsCache.ContainsKey($i)) { $hit++ } }
                    if ($req.Count -gt 0) { Set-StatusText ((Get-T 'ws_fetched') -f $hit, $req.Count) }
                    Update-Details
                }
            })
        }
        $Script:PrefetchTimer.Start()
    } catch {
        $Script:Prefetch = $null
    }
}

# =============================================================================
# The cheerful "all good" scene (house, survivor, falling zombie)
# =============================================================================
function New-FunBrush([int]$R, [int]$G, [int]$B, [double]$Opacity = 1.0) {
    $col = [System.Windows.Media.Color]::FromRgb([byte]$R, [byte]$G, [byte]$B)
    $br = [System.Windows.Media.SolidColorBrush]::new($col)
    $br.Opacity = $Opacity
    return $br
}

function Add-FunRect($Canvas, [double]$X, [double]$Y, [double]$W, [double]$H, $Brush) {
    $r = [System.Windows.Shapes.Rectangle]::new()
    $r.Width = $W
    $r.Height = $H
    $r.Fill = $Brush
    [System.Windows.Controls.Canvas]::SetLeft($r, $X)
    [System.Windows.Controls.Canvas]::SetTop($r, $Y)
    [void]$Canvas.Children.Add($r)
    return $r
}

# =============================================================================
# Optimizer view: the program really optimizes, by itself
# =============================================================================
function Show-OptimizeView {
    $u = $Script:Ui
    if (-not $u) { return }
    $u.OptView.Visibility = 'Visible'
    if (-not $Script:OptSysFilled) {
        $si = Get-SystemInfo
        $u.OptSys.Text = [string]((Get-T 'opt_sys_cpu') -f [string]$si['Cpu'], [int]$si['Cores'])
        $u.OptSys2.Text = [string]((Get-T 'opt_sys_ram') -f [double]$si['RamGB'], [string]$si['Gpu'])
        $Script:OptSysFilled = $true
    }
}

# =============================================================================
# Enable/disable write straight into the save (backup included) - no extra
# "write to save" button, no confirmations to click through
# =============================================================================
function Invoke-ApplySelection([bool]$Enable) {
    if (-not $Script:Save) { Set-StatusText (Get-T 'msg_no_save'); return }
    $rows = Get-CheckedOrSelected
    if (@($rows).Count -eq 0) { Set-StatusText (Get-T 'msg_no_sel'); return }
    $changed = 0
 # what the user switched off is kept apart from the dependents
 # that will follow it into the dark - only the checked mods go into the
 # report headline, the followers get a line of their own
    $doomed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $doomedHit = [System.Collections.Generic.List[string]]::new()
 # the save's current set, compared case-insensitively (mod.info spells
 # the same mod differently in different items - the game does not care)
    $saveSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($m in [string[]]$Script:SaveMods.ToArray()) { if ($m) { [void]$saveSet.Add($m) } }
    foreach ($row in $rows) {
        $it = Find-ItemByRow $row
        if ($it) {
            foreach ($id0 in [string[]]$it['ModIds']) {
                $id = Get-NormalizedModId $id0
                if ($Enable) {
                    if ($id -and (-not $saveSet.Contains($id))) { [void]$saveSet.Add($id); $changed++ }
                } else {
                    if ($id) {
                        [void]$doomed.Add($id)
                        if ($saveSet.Contains($id)) { [void]$saveSet.Remove($id); $changed++; $doomedHit.Add($id) }
                    }
                }
            }
        }
    }
    $dragged = [string[]]@()
    if (-not $Enable -and $doomedHit.Count -gt 0) {
 # the mirror of the enable path's requirement pull: switching a mod
 # off takes every save-mod that cannot live without it along, so
 # "mod X needs mod Y" warnings never follow the user's own click
        $closure = [string[]](Get-DependentMods ([string[]]$doomedHit.ToArray()) $Script:Items ([string[]]$Script:SaveMods.ToArray()))
        foreach ($dep0 in $closure) {
            $dep = Get-NormalizedModId $dep0
            if (-not $dep -or $doomed.Contains($dep)) { continue }
            if ($saveSet.Contains($dep)) {
                [void]$saveSet.Remove($dep); $changed++
                $dragged += $dep
            }
        }
    }
    if ($Enable) {
 # enabling a mod pulls its installed requirements along - the
 # "mod X needs mod Y" warnings must never appear right after the
 # user's own click
        $installed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $reqOf = @{}
        foreach ($it2 in $Script:Items) {
            if ($null -eq $it2) { continue }
            if ($it2['Quarantined'] -or $it2['Broken']) { continue }
            foreach ($sub in $it2['Mods']) {
                $sid = Get-NormalizedModId ([string]$sub['Id'])
                if (-not $sid) { continue }
                [void]$installed.Add($sid)
                if (-not $reqOf.ContainsKey($sid)) { $reqOf[$sid] = [string[]]$sub['Requires'] }
            }
        }
        $queue = [System.Collections.Generic.List[string]]::new()
        foreach ($row2 in $rows) {
            $it3 = Find-ItemByRow $row2
            if ($it3) { foreach ($id3 in [string[]]$it3['ModIds']) { $q3 = Get-NormalizedModId $id3; if ($q3) { $queue.Add($q3) } } }
        }
        $qi = 0
        while ($qi -lt $queue.Count) {
            $cur = $queue[$qi]; $qi++
            if (-not $reqOf.ContainsKey($cur)) { continue }
            foreach ($r0 in [string[]]$reqOf[$cur]) {
                $r = Get-NormalizedModId $r0
                if (-not $r) { continue }
                if ($installed.Contains($r) -and (-not $saveSet.Contains($r))) {
                    [void]$saveSet.Add($r); $changed++
                    $queue.Add($r)
                }
            }
        }
    }
    if ($changed -eq 0) { Set-StatusText (Get-T 'status_ready'); return }
    $sortedArr = [string[]](Sort-ByDependencies ([string[]]@($saveSet)) $Script:Items)
    $bak = Write-ModsTxt ([string]$Script:Save['Path']) $sortedArr
    $Script:Save['Mods'] = $sortedArr
    if (-not $Enable) {
 # B42 keeps its own workshopMods.txt - a dead entry there
 # kept the row "works" long after the mod itself was switched off.
 # The sync reads Sv['Mods'], so it must run AFTER the save's own
 # list has been replaced with what was just written
        try { [void](Sync-WorkshopIdsInSave $Script:Save $Script:Items) } catch { }
    }
    $Script:SaveMods = [System.Collections.Generic.List[string]]::new()
    $Script:SaveMods.AddRange($sortedArr)
 # the union of every save's lists is REBUILT from the live
 # saves now - the old code only ever added to it, so a disabled mod
 # stayed "works" in the table forever, and the disable button then
 # had nothing left to remove
    Reset-SaveAggregates
    $Script:Analysis = Invoke-Analysis $Script:Items ([string[]]$Script:SaveMods.ToArray())
    Update-Grid -Preserve
    Update-Conflicts
    if ($dragged.Count -gt 0) {
 # the horde went along - every name gets said out loud
        Set-StatusText ((Get-T 'status_disabled_deps') -f (([string[]]$doomedHit.ToArray()) -join ', '), ($dragged -join ', '), (Split-Path -Leaf $bak))
    } else {
        Set-StatusText ((Get-T 'status_saved') -f (Split-Path -Leaf $bak))
    }
}

function Invoke-PickZomboidFolder {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Zomboid'
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $Script:ZomboidDir = [string]$dlg.SelectedPath
        $Script:ZomboidRootCache = ''
        try { Save-Settings } catch { }
        Invoke-CheckFlow
    }
}

# =============================================================================
# UI strings (single window, both languages)
# =============================================================================
function Set-UiStrings {
    $u = $Script:Ui
    $u.TaglineText.Text = Get-T 'tagline'
    $u.FooterText.Text = Get-T 'footer'
    $u.LblSaves.Content = Get-T 'lbl_saves'
    $u.LblSteam.Content = Get-T 'lbl_steam'
    $u.LblDetails.Content = Get-T 'lbl_details'
    $u.LblConflicts.Content = Get-T 'lbl_conflicts'
    $u.LblGame.Content = Get-T 'lbl_game'
    $u.BtnMain.Content = Get-T 'btn_main'
    if ($Script:View -eq 'work') { $u.BtnManual.Content = Get-T 'btn_manual_hide' } else { $u.BtnManual.Content = Get-T 'btn_manual' }
    $u.BtnOptimize.Content = Get-T 'btn_opt'
    $u.BtnSelectAll.Content = Get-T 'btn_select_all'
    $u.BtnClearAll.Content = Get-T 'btn_clear_all'
    $u.BtnToggle.Content = Get-T 'btn_toggle_on'
    $u.BtnToggleOff.Content = Get-T 'btn_toggle_off'
    $u.BtnBrowse.Content = Get-T 'btn_browse'
    $u.BtnZomboid.Content = Get-T 'btn_zomboid'
    $u.OptTitle.Text = Get-T 'opt_title'
    $u.OptPlan.Text = (Get-T 'opt_plan_head') + "`n" + (Get-T 'opt_plan_json') + "`n" + (Get-T 'opt_plan_launch') + "`n" + (Get-T 'opt_plan_logs')
    $u.OptRun.Content = Get-T 'opt_do'
    $u.OptBack.Content = Get-T 'opt_rollback'
    $u.SpConfirmNo.Content = Get-T 'skip'
    $u.StatusText.Text = Get-T 'status_ready'
    $u.VersionText.Text = 'v' + $Script:Version
 # blind $c[N] indexing was a perfect "Cannot index into a
 # null array" at first paint (property sets on $null stay silent, an
 # index does not). Guard the collection, then localize every column.
    try {
        $c = $u.Grid.Columns
        $heads = @((Get-T 'col_sel'), (Get-T 'col_num'), (Get-T 'col_name'), (Get-T 'col_ids'), (Get-T 'col_wid'), (Get-T 'col_link'), (Get-T 'col_status'))
        for ($ci = 0; $ci -lt $heads.Count; $ci++) {
            if ($ci -lt $c.Count) { $c[$ci].Header = $heads[$ci] }
        }
    } catch { }
    Update-Title
    Render-Home
}

# =============================================================================
# GUI mode
# =============================================================================
function Invoke-GuiMode {
    $apartment = [System.Threading.Thread]::CurrentThread.GetApartmentState()
    if ($apartment -ne [System.Threading.ApartmentState]::STA) {
        $argLine = ('-STA -NoProfile -ExecutionPolicy Bypass -File "{0}" -Lang {1}' -f $PSCommandPath, $Script:Lang)
        if ($NoWizard) { $argLine += ' -NoWizard' }
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argLine
        return
    }
    try {
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName WindowsBase
        Add-Type -AssemblyName System.Windows.Forms
    } catch {
        Write-Host ('Failed to load WPF: ' + $_.Exception.Message)
        return
    }

 # crash shield, part 1: the window itself must survive whatever
 # a live machine throws at the UI thread. Unhandled dispatcher errors
 # are logged into the home card and marked handled - the app never
 # vanishes and never shows a raw PowerShell dump.
    $reader = New-Object System.IO.StringReader($Script:Xaml)
    try {
        $wnd = [Windows.Markup.XamlReader]::Load([System.Xml.XmlReader]::Create($reader))
    } catch {
        try {
            [System.Windows.MessageBox]::Show(('PZ Workshop Doctor: ' + [string]$_.Exception.Message), 'PZ Workshop Doctor', 'Ok', 'Error') | Out-Null
        } catch { Write-Host ('XAML load failed: ' + $_.Exception.Message) }
        return
    }
    try {
        $wnd.Dispatcher.add_UnhandledException({
            param($sender, $dea)
            try {
                if ($dea) { $dea.Handled = $true }
                $msg = 'unknown'
                try { $msg = [string]$dea.Exception.Message } catch { }
                try { Add-HomeLine ((Get-T 'scene_shield') -f $msg) } catch { }
                try { Set-StatusText ((Get-T 'err_line') -f $msg) } catch { }
            } catch { }
        })
    } catch { }

    $Script:Ui = @{}
    $Script:Ui['Wnd'] = $wnd
    foreach ($n in @('TopBar', 'BtnWinMin', 'BtnWinMax', 'BtnWinClose', 'StatusStrip', 'FooterStrip', 'TaglineText', 'VersionText', 'FooterText', 'StatusText', 'LangBox', 'BtnMain', 'BtnManual', 'BtnOptimize', 'AdvancedBar', 'HomeView', 'SpIcon', 'SpTitle', 'SpStats', 'SpDetail', 'SpBtn1', 'SpBtn2', 'SpConfirm', 'SpConfirmText', 'SpConfirmYes', 'SpConfirmNo', 'HomeCard', 'WorkView', 'LblSaves', 'SavesList', 'LblSteam', 'PathBox', 'BtnBrowse', 'BtnZomboid', 'LblGame', 'GameBox', 'Grid', 'LblDetails', 'DetailsBox', 'LblConflicts', 'ConflictsBox', 'BtnSelectAll', 'BtnClearAll', 'BtnToggle', 'BtnToggleOff', 'OptView', 'OptTitle', 'OptSys', 'OptSys2', 'OptPlan', 'OptRun', 'OptBack', 'OptLog', 'SceneStrip', 'SceneCanvas', 'SceneBanner', 'SceneBannerTt', 'SceneDeath', 'SceneDeathBg')) {
        $Script:Ui[$n] = $wnd.FindName($n)
    }

    $u = $Script:Ui
    try { Read-WorkshopCache } catch { }

 # the banner is the window's own head (WindowChrome): the top
 # strip drags and double-clicks natively. The old DragMove handlers
 # stay as a fallback for the bottom bars - and for the top bar too,
 # in case WindowChrome ever fails to apply on an exotic machine.
    foreach ($dragName in @('TopBar', 'StatusStrip', 'FooterStrip', 'SceneStrip')) {
        $dragBar = $Script:Ui[$dragName]
        if (-not $dragBar) { continue }
        $dragBar.Add_MouseLeftButtonDown({
            try {
                if ($Script:Ui -and $Script:Ui.Wnd -and $Script:Ui.Wnd.WindowState -ne 'Maximized') {
                    $Script:Ui.Wnd.DragMove()
                }
            } catch { }
        })
    }

 # --- the window's own controls, living in the banner itself ---
    $u.BtnWinMin.Add_Click({
        Invoke-Safe { try { $Script:Ui.Wnd.WindowState = 'Minimized' } catch { } }
    })
    $u.BtnWinMax.Add_Click({
        Invoke-Safe {
            try {
                if ($Script:Ui.Wnd.WindowState -eq 'Maximized') { $Script:Ui.Wnd.WindowState = 'Normal' }
                else { $Script:Ui.Wnd.WindowState = 'Maximized' }
            } catch { }
        }
    })
    $u.BtnWinClose.Add_Click({
        Invoke-Safe { try { $Script:Ui.Wnd.Close() } catch { } }
    })
 # the maximize glyph follows the real state: the caption can be
 # double-clicked and Win+Up does the same without touching the button
    try {
        $wnd.Add_StateChanged({
            Invoke-Safe {
                try {
                    if ($Script:Ui.BtnWinMax) {
                        if ($Script:Ui.Wnd.WindowState -eq 'Maximized') { $Script:Ui.BtnWinMax.Content = '▣' }
                        else { $Script:Ui.BtnWinMax.Content = '□' }
                    }
                } catch { }
            }
        })
    } catch { }

 # --- the ONE big button: check AND fix, the program leads ---
    $u.BtnMain.Add_Click({
        Invoke-Safe {
            Show-View 'home'
            Invoke-CheckFlow
        }
    })

    $u.BtnManual.Add_Click({
        Invoke-Safe {
            if ($Script:View -eq 'work') { Show-View 'home' } else { Show-View 'work' }
        }
    })

    $u.BtnOptimize.Add_Click({
        Invoke-Safe { Show-View 'opt' }
    })

    $u.OptRun.Add_Click({
        if ($Script:Busy) { return }
        Invoke-Safe {
            $Script:Busy = $true
            $u.OptRun.IsEnabled = $false
            $Script:FlowError = ''
 # the optimizer walks the same road as the check - the
 # survivor sets off, and the street tells how it ended: the
 # victory banner on success, the horde FEASTS on an error.
            Start-SceneRun
            Set-SceneProgress 0.10
            try {
                $hint = ''
                if ($Script:Steam) { $hint = [string]$Script:Steam } elseif ($SteamPath) { $hint = $SteamPath }
 # let the walk take a breath before the optimizer starts
 # reading the machine: ~0.4 s of real street frames
                for ($breathe = 0; $breathe -lt 12; $breathe++) {
                    try { [System.Threading.Thread]::Sleep(33) } catch { }
                    try { [void]$Script:Ui.Wnd.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{}) } catch { }
                }
                Set-SceneProgress 0.45
                $res = Invoke-RealOptimize $hint ([int]@($Script:Items).Count)
                if (-not $res) { $res = @{ Lines = [string[]]@(); Backups = [object[]]@() } }
                $lines = [string[]]$res['Lines']
                $u.OptLog.Text = ((Get-T 'opt_log_head') + "`n`n" + ($lines -join "`n"))
                $Script:OptBackups = [object[]]$res['Backups']
                if (@($Script:OptBackups).Count -gt 0) {
                    $u.OptBack.Visibility = 'Visible'
                } else {
                    $u.OptBack.Visibility = 'Collapsed'
                    $u.OptLog.Text = $u.OptLog.Text + "`n`n" + (Get-T 'opt_back_none')
                }
                Set-StatusText (Get-T 'cli_opt_done')
                Set-SceneProgress 0.92
                Invoke-SceneFinish $true (Get-T 'scene_optimized')
            } catch {
 # the horde eats him: an optimizer failure is impossible
 # to miss, the log below still tells the exact reason
                $lineNo = 0
                try { $lineNo = [int]$_.InvocationInfo.ScriptLineNumber } catch { }
                Write-CrashLog ('optimize') $_
                $Script:FlowError = [string]((Get-T 'step_failed') -f (Get-T 'opt_do'), [string]$_.Exception.Message, $lineNo)
                try { Set-StatusText ((Get-T 'err_line') -f [string]$_.Exception.Message) } catch { }
                Invoke-SceneDeath
            } finally {
                $u.OptRun.IsEnabled = $true
                $Script:Busy = $false
            }
        }
    })

    $u.OptBack.Add_Click({
        Invoke-Safe {
            $null = Invoke-RollbackOptimize ([object[]]$Script:OptBackups)
            $Script:OptBackups = [object[]]@()
            $u.OptBack.Visibility = 'Collapsed'
            $u.OptLog.Text = (Get-T 'opt_back_done')
        }
    })

 # --- home card actions (one green button + occasional secondary) ---
    $u.SpBtn1.Add_Click({
        if ($Script:Busy) { return }
        Invoke-Safe {
            switch ($Script:SpAction1) {
                'fix'     { Invoke-FixFlow }
                'recheck' { Invoke-CheckFlow }
                'zomboid' { Invoke-PickZomboidFolder }
                default   { }
            }
        }
    })

    $u.SpBtn2.Add_Click({
        if ($Script:Busy) { return }
        Invoke-Safe {
            switch ($Script:SpAction2) {
                'fix'     { Invoke-FixFlow }
                'recheck' { Invoke-CheckFlow }
                'zomboid' { Invoke-PickZomboidFolder }
                default   { }
            }
        }
    })

    $u.SpConfirmYes.Add_Click({
        Invoke-Safe {
            $yes = $Script:ConfirmYes
            $Script:ConfirmYes = $null
            $Script:ConfirmNo = $null
            $Script:Ui.SpConfirm.Visibility = 'Collapsed'
            if ($yes) { & $yes }
        }
    })

    $u.SpConfirmNo.Add_Click({
        Invoke-Safe {
            $no = $Script:ConfirmNo
            $Script:ConfirmYes = $null
            $Script:ConfirmNo = $null
            $Script:Ui.SpConfirm.Visibility = 'Collapsed'
            if ($no) { & $no }
        }
    })

    $u.BtnBrowse.Add_Click({
        if ($Script:Busy) { return }
        Invoke-Safe {
            $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
            $dlg.Description = 'Steam'
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $Script:Ui.PathBox.Text = $dlg.SelectedPath
                Invoke-CheckFlow
            }
        }
    })

    $u.BtnZomboid.Add_Click({
        if ($Script:Busy) { return }
        Invoke-Safe { Invoke-PickZomboidFolder }
    })

    $u.BtnSelectAll.Add_Click({
        Invoke-Safe {
            if ($Script:Items.Count -eq 0) { Set-StatusText (Get-T 'msg_no_items'); return }
            $set = @{}
            foreach ($it in $Script:Items) { if ($null -ne $it) { $set[[string]$it['Folder']] = $true } }
            Update-Grid -CheckSet $set
            Set-StatusText ((Get-T 'msg_marked') -f $set.Count)
        }
    })

 # a resize rebuilds the street so it always spans the whole window -
 # but never mid-action: wiping a running walk would look broken
    $u.SceneStrip.Add_SizeChanged({
        Invoke-Safe {
            $busyScene = ($Script:Scene -and $Script:Scene['Mode'] -ne 'fight')
            if (-not $busyScene) { Build-AmbientScene }
        }
    })

    $u.BtnClearAll.Add_Click({
        Invoke-Safe {
            Update-Grid -CheckSet @{}
        }
    })

 # Workshop page links in the grid column open the default browser.
    $u.Grid.AddHandler([System.Windows.Documents.Hyperlink]::RequestNavigateEvent, [System.Windows.RoutedEventHandler]{
        param($sender, $e)
        try {
            if ($e.Uri -and $e.Uri.AbsoluteUri) {
                Start-Process -FilePath ([string]$e.Uri.AbsoluteUri)
                $e.Handled = $true
            }
        } catch {
            try { Set-StatusText ((Get-T 'err_line') -f [string]$_.Exception.Message) } catch { }
        }
    })

    $u.SavesList.Add_SelectionChanged({
        if ($Script:Busy) { return }
        Invoke-Safe {
            $i = [int]$Script:Ui.SavesList.SelectedIndex
            if ($i -ge 0 -and $i -lt $Script:Saves.Count) {
                Select-Save $Script:Saves[$i]
            }
        }
    })

    $u.Grid.Add_SelectionChanged({
        if ($Script:Busy) { return }
        Invoke-Safe { Update-Details }
    })

 # a click on a column header sorts the table. The built-in view sort
 # dies with the next ItemsSource rebuild anyway, so the order is kept
 # by us: the click remembers column+direction and re-sorts the rows
 # that are already on screen; every later rebuild applies it again.
    $u.Grid.Add_Sorting({
        param($s, $e)
        Invoke-Safe {
 # Handled cancels the built-in ListCollectionView sort - the order
 # comes from Sort-GridRows, not from the view
            $e.Handled = $true
            $prop = [string]$e.Column.SortMemberPath
            if (-not $prop) { return }
            $desc = $false
            if ($Script:GridSort -and ([string]$Script:GridSort['Prop'] -eq $prop)) {
                $desc = -not [bool]$Script:GridSort['Desc']
            }
            Invoke-GridSort $prop $desc
 # the little arrow in the clicked header tells the truth again
            try {
                foreach ($c in (Get-Seq $Script:Ui.Grid.Columns)) { $c.SortDirection = $null }
                if ($desc) {
                    $e.Column.SortDirection = [System.ComponentModel.ListSortDirection]::Descending
                } else {
                    $e.Column.SortDirection = [System.ComponentModel.ListSortDirection]::Ascending
                }
            } catch { }
        }
    })

 # TWO buttons where the mood-swinger used to be. A tick in a
 # checkbox fires no event the old label ever listened to, so the label
 # went stale and the click did the opposite of what was written. Now
 # each button does exactly what it says - forever.
    $u.BtnToggle.Add_Click({
        if ($Script:Busy) { return }
        Invoke-Safe { Invoke-ApplySelection $true }
    })

    $u.BtnToggleOff.Add_Click({
        if ($Script:Busy) { return }
        Invoke-Safe { Invoke-ApplySelection $false }
    })

    $u.LangBox.Add_SelectionChanged({
        if ($Script:Busy) { return }
        Invoke-Safe {
            $idx = [int]$Script:Ui.LangBox.SelectedIndex
            if ($idx -lt 0) { return }
            $newLang = 'RU'
            if ($idx -eq 1) { $newLang = 'EN' }
            if ($newLang -ne $Script:Lang) {
                $Script:Lang = $newLang
                Set-UiStrings
                Update-Grid -Preserve
                Update-Conflicts
                Update-Details
            }
        }
    })

    $u.Wnd.Add_Closing({
 # remember the language (and the Zomboid folder) for the next start
        try { Save-Settings } catch { }
        try {
            if ($Script:PrefetchTimer) { $Script:PrefetchTimer.Stop() }
            if ($Script:MissingTimer) { $Script:MissingTimer.Stop() }
            if ($Script:WatchTimer) { $Script:WatchTimer.Stop() }
            if ($Script:SceneTimer) { $Script:SceneTimer.Stop() }
            if ($Script:Prefetch) {
                try { $Script:Prefetch['Ps'].Runspace.Close() } catch { }
                try { $Script:Prefetch['Ps'].Dispose() } catch { }
                $Script:Prefetch = $null
            }
            if ($Script:MissingJob) {
                try { $Script:MissingJob['Ps'].Runspace.Close() } catch { }
                try { $Script:MissingJob['Ps'].Dispose() } catch { }
                $Script:MissingJob = $null
            }
        } catch { }
    })

    $u.Wnd.Add_ContentRendered({
        Invoke-Safe {
            $Script:FirstRun = (Test-FirstRun) -and (-not $NoWizard)
 # the street fight is part of the program's face: it starts with
 # the window and never stops while the window is alive
            Start-AmbientEngine
 # nothing runs by itself anymore. The check waits for
 # the big green button - on start the card just says what
 # pressing it will do (the first-run wizard keeps its card).
            if ($Script:FirstRun) {
                Set-Home 'welcome'
                Save-Settings
            } else {
                Set-Home 'idle'
            }
        }
    })

    Set-UiStrings
    if ($SteamPath) { $u.PathBox.Text = $SteamPath }

 # sync the language combo with the auto-detected language
    $Script:Busy = $true
    try {
        if ($Script:Lang -eq 'EN') { $u.LangBox.SelectedIndex = 1 } else { $u.LangBox.SelectedIndex = 0 }
    } finally {
        $Script:Busy = $false
    }

 # crash shield, part 2: even a total ShowDialog failure leaves
 # the user a readable message instead of a window that blinks out.
    try {
        [void]$u.Wnd.ShowDialog()
    } catch {
        try {
            [System.Windows.MessageBox]::Show(('PZ Workshop Doctor: ' + [string]$_.Exception.Message), 'PZ Workshop Doctor', 'Ok', 'Error') | Out-Null
        } catch { }
    }
}
# =============================================================================
# Entry point
# =============================================================================
# Language remembered from the previous run (the settings file is written
# by the first-run wizard and on every window close).
if (-not $Lang) {
    $st = Read-Settings
    if ($st -and $st.lang) {
        $savedLang = [string]$st.lang
        if ($savedLang -eq 'RU' -or $savedLang -eq 'EN') { $Script:Lang = $savedLang }
    }
}

if ($Help) { Show-Help; return }
if ($Cli -or $Optimize -or $CleanQuarantine -or $AutoFix) { Invoke-CliMode; return }
Invoke-GuiMode

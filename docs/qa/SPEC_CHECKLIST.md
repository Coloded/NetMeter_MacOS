# Независимый контроль ТЗ NetMeter

Дата: 2026-11-16. Контролёр: spec_control. Основание: `docs/RELIABILITY_SPEC.md`.

**Различаем проверку кода, автоматические runtime-тесты и физический GUI/HW E2E.**
Ниже REVIEW означает: реализация соответствует проверенному коду, но финальная независимая QA-доказательная база ещё дополняется. Это не заявление о live E2E.

| ID | Проверка реализации | Доказательства / границы |
|---|---|---|
| P0-NET-01 | REVIEW; критический первоначальный дефект исправлен | Production IFMIB_IFDATA/IFDATA_GENERAL вместо фактически32битного NET_RT_IFLIST2; QA bracketed netstat en0 RX/TX >2^32 PASS. NetworkRateTracker monotonic, независимые downAvailable/upAvailable; график разрывает invalid направление, status/tooltip показывают —. Valid deltas отдельно учитываются. Pure regression tests PASS; sustained wire-load не выполнялся. |
| P0-SET-01 | REVIEW | SettingsStore сохраняет старые ключи, freeze legacy fallback при индивидуальном изменении network; global действие записывает только свойство всем графикам. changeCheck не меняет несвязанные свойства, context меню graph-scoped, restore через store. QA isolated migration/reopen/independence PASS; настоящий пользовательский restart не выполнялся. |
| P1-MET-01 | REVIEW | MetricsCollector serial background, inFlight guard, callback main; main discovery cache-only. Common-mode timer, NSWorkspace didWake reset, gap clear, selection generation guard. Language/units вызывают refreshPresentation без дополнительного sample. BoundedCommand исправлен после QA descendant pipe FAIL, process-group cleanup/limited reads, QA 8 assertions PASS. |
| P1-MET-02 | REVIEW | GPU перечитывается и availability обновляется; disk invalid handle освобождается, retry discovery ограничен5s; wake resets baselines. GPU core count берётся из того же устройства, что usage; max-device семантика явно описана EN/RU README. Реальная сменаGPU/загрузочногоустройства не проверена. |
| P1-LOG-01 | REVIEW | DiagnosticCenter OSLog, bounded200 events, repeat limiting, категории/codes/detail whitelist; SettingsStore diagnosticSummary enum whitelist. Пользовательский NSSavePanel, JSON atomic write, никакой отправки. Sparkle delegate records numerical error. QA expanded privacy retest ожидается. |
| P1-UPD-01 | REVIEW | Единый updates/sparkle.json pin2.10.1/SHA, shared sparkle_config helper; prepare/verify/publish/CI используют immutable vVERSION archive URL. RequireSignedFeed/VerifyBeforeExtraction сохранены. Runtime подписи/negative fixtures проверяет root/QA; реальная установка апдейта не разрешена. |
| P1-BLD-01 | REVIEW | Temp fresh bundle, copy sync removes stale files without following destination symlinks, flock lock. QA copier7/lock3 fixtures PASS. Universal --no-install/typecheck PASS по исполнителю; финальные codesign/minOS/architectures подтверждаются QA/root. Новый CI read-only, только локальный файл, remote запуск не выполнен. |
| P2-UI-01 | REVIEW | Общий GraphTextLayout fit width+height+clip, network one line, resource/core tooltip, font-dependent min sizes; замечание о overlap48pt исправлено bounds allocation. Палитры синхронизируются. Визуальный RTL/light-dark/multiscreen E2E не подтверждён; нужны QA geometry/render результаты. |
| P2-SYS-01 | REVIEW | AX bounded matching identifiers/titles/descriptions, исключён process-table traversal, коды действий проверяются; повторная помощь из меню и bounded explanation. Screen containment observer, прежняя склейка/Option-detach сохранены по коду. AX permissions/multi-monitor drag E2E не выполнялись. |
| P2-RAM-01 | REVIEW | GiB при1024³, swap из vm.swapusage, pressure из kern.memorystatus_vm_pressure_level; unknown explicit, не inference из процента. Формула used memory и отличие отActivityMonitor описаны EN/RU. QA live/details assertions ожидаются. |
| P2-QA-01 | REVIEW | 123 keys/four catalogs PASS поQA; старые тесты сохранены, новые regression файлы покрывают найденные реальные FAIL/retest. EN/RU README и updates guide обновлены. Финальная приёмка после актуального TEST_REPORT. |

## Замечания, переданные и исправленные в ходе контроля

- Reset-направление сначала отображалось как0: добавлены directional availability flags и downstream обработка.
- Language/units сначала запускали лишний tick: теперь только refresh cached presentation.
- Stale selection/ABA: добавлен generation guard.
- Main discovery мог запускать external process: main теперь cache-only.
- Экспорт сохранял произвольные settings/details: enum/symbol whitelist вместо regex-only privacy.
- AX traversal мог исчерпать500 budget в process rows: таблицы/outline/row/cell исключены.
- Font48/no-auto-fit мог перекрывать memory строки: добавлены min geometry и bounded/clipped rows.

## Ограничения приёмки

Никаких публикаций, смены ключей/версии, прав macOS, автозапуска или рабочего app со стороны контролёра не выполнялось.
Локальные пять прежних GPU-файлов сохранены в доработках. P3 не реализуется.
Пока нет оснований объявлять PASS для физического Intel/eGPU, настоящего sleep/wake,
AX переключения, нескольких экранов, login-start и реальной установки Sparkle.
Это внешние/интерактивные проверки; код и модели не заменяют их доказательство.

## Независимые финальные результаты QA

По актуальному `TEST_REPORT.md` и прямым сообщениям QA: core82 PASS;
command runner10 PASS (включая continuous output/descendant cleanup); diagnosticprivacy17 PASS;
collector14 PASS (off-main/main completion/coalescing/wake/simulated GPU recovery);
layout60 PASS (четыре scripts, fonts6/12/48, width/height/min policy);
copybundle7 PASS; buildlock3 PASS; localization123 keys PASS;
live64bit interface counters bracketed netstat PASS;
live memory4 PASS (swap/kernel pressure); disposable-key signed-update8 PASS;
Universal/min13/Sparkle2.10.1/codesign/fresh locale bundle checks PASS.
Точные команды и величины — в отчёте QA; это не результаты live GUI.

**Статус приёмки:** P0-NET-01 и P0-SET-01 PASS по коду+wiring+runtime/live доступным
проверкам. P1-MET-01, P1-LOG-01, P1-UPD-01, P1-BLD-01 PASS по доступным автоматическим
проверкам; настоящее обновление работающей app не выполнялось. P1-MET-02 PASS по
моделям/коду, физическое переобнаружение GPU/диска BLOCKED отсутствием контролируемого
hardware сценария. P2-UI-01/P2-SYS-01 частично PASS (код/layout), live palette/AX,
смена мониторов и склейка BLOCKED: рабочее приложение не заменялось/не перезапускалось,
разрешения не менялись. P2-RAM-01 PASS по коду и kernel read-only. P2-QA-01 PASS по
наличию регрессий/отчётов/документации с указанными ограничениями.

Открытых воспроизведённых code-review critical/high дефектов не осталось. Финальный
артефакт после последнего узкого исправления startup должен быть повторно согласован
QA и координатором; до этого не считать приложенный старый bundle окончательно принятым.

## Завершение приёмки локальных артефактов

После узкого startup исправления (до первого snapshot показывается недоступность, а
не ложные нули) исполнитель выполнил финальную сборку. QA повторно подтвердил свежесть,
Universal arm64/x86_64, minimum macOS13, Sparkle2.10.1 и codesign; collector14 повторно PASS.
SHA-256 финального executable приведён полностью в `TEST_REPORT.md` (24c11158…ab59c).
CI дополнен collector/layout и offline disposable-key update tests после сборки;
реальные пользовательские defaults и hardware probes в CI не используются.

**Итог контролёра:** все11ID P0–P2 охвачены; воспроизведённых открытых source blockers
нет, локальные автоматические проверки приняты. Перечисленные выше GUI/HW проверки
остаются явно непроверенными/BLOCKED и не входят в заявление о live-прохождении.
P3 остаётся согласованным будущим планом. Установки/публикации не выполнялись.

## Дополнение: разрешённая интерактивная приёмка 1.1.5 / build 7

2026-11-16 пользователь отдельно разрешил выпуск, установку и GUI-проверки. Ограничение
«только локально, без замены рабочего приложения» в исходном ТЗ и предыдущих разделах
описывает прежний этап. Исходное ТЗ сохранено; данное дополнение фиксирует новый объём
авторизации. Контролёр сам UI, публикацию и изменение системных разрешений не выполнял.

**Независимая QA-приёмка текущего пакета:** `dist/release-v1.1.5-build7` принят:
manifest SHA256SUMS, реальные криптографические подписи feed/archive, immutable v1.1.5
URL, версия/build/размер, `hdiutil verify`, все 173 payload entries относительно staging
(хеши, modes, symlinks; AppleDouble исключены как metadata), deep strict codesign,
Universal arm64/x86_64 и minimum macOS 13 PASS. Команды и полные хеши находятся в
`TEST_REPORT.md`. Старый executable hash 24c11158…ab59c выше относится к исторической
сборке и не используется как идентификатор текущего релиза.

**Наблюдения координатора через CUA, не самостоятельный GUI-прогон контролёра:**

- P1-BLD-01: первоначальный отказ запуска был Taskgated/CODESIGNING до app frames.
  После atomic temporary sibling + replace обычный запуск и повторные перезапуски
  PASS; повторения отказа не наблюдалось. QA copier теперь 9/9 PASS, включая held-open
  inode и interrupted-copy preservation. Причину кеширования подписи не объявляем
  независимо доказанной; исправление и успешный повторный запуск подтверждены.
- P0-SET-01 / P2-UI-01: English и стиль macOS сохранялись после перезапуска.
  Нативная палитра с пипеткой доступна; GPU line yellow и label green независимы.
  Переключения en/ru/zh и Arabic RTL просмотрены. Временные language/style/color/
  geometry/visibility после проверки возвращены координатором к исходным значениям;
  накопленные traffic totals сохранены.
- P2-UI-01 / P2-SYS-01: CPU 14-core grid автоматически увеличивается, выключение режима
  возвращает компактный размер; screenshot PASS. Реальный GPU показывает 20 ядер.
- P2-RAM-01 / P1-MET-02: реальные экраны memory GiB/swap/pressure и disk0 просмотрены.
  Это не проверка физической замены GPU/диска.
- P0-NET-01 / P2-UI-01: после startup-before-first-snapshot найден и исправлен stale
  General network summary. QA статически проверил accepted snapshot/presentation/
  show/create call paths, latest interface, tooltip и отсутствие tick. Координатор
  после установки/перезапуска увидел правильные Ethernet/en0 и 1 Гбит/с, включая
  финальный русский экран. Исправление находится в принятом DMG.
- P2-SYS-01: с текущим отсутствующим AX permission Activity Monitor открывается с
  честным fallback; автоматический выбор нужной секции НЕ ПОДТВЕРЖДЁН. Новое разрешение
  не выдавалось. Native CUA drag завершился `windowNotFoundAtPosition`: настоящая
  склейка/отделение/перетаскивание остаются BLOCKED для live-приёмки, не PASS.

**Актуальный итог:** все 11 ID охвачены; открытых воспроизведённых source blockers
не осталось. Текущий пакет 1.1.5/build 7 принят в автоматическом объёме QA и перечисленном
live-объёме координатора. AX auto-selection, реальный drag/grouping, multi-monitor,
физический Intel/eGPU/recovery, настоящий sleep/wake/login-start и установка через
сам Sparkle остаются непроверенными; установка app вручную не заменяет Sparkle E2E.
P3 и его hardware/подпись/лицензия/долговременные ограничения не изменены.

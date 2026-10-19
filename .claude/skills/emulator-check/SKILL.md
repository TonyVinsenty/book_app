---
name: emulator-check
description: Запустить BookApp на эмуляторе Android Pixel_8, снять скриншот и проверить журнал на падения. Использовать после правок экрана или нативного кода, чтобы увидеть результат в настоящем приложении.
argument-hint: "[что проверить, например «экран библиотеки» или путь к книге для загрузки]"
allowed-tools: Bash(flutter build apk *) Bash(flutter devices) PowerShell(flutter build apk *) PowerShell(flutter devices)
---

Проверь BookApp на эмуляторе. Что смотреть: $ARGUMENTS (если пусто — просто запуск и первый экран).

Пути: `ADB=D:/Android/Sdk/platform-tools/adb.exe`, эмулятор `D:/Android/Sdk/emulator/emulator.exe`, AVD `Pixel_8`, пакет `com.tonyvinsenty.bookapp`. В Git Bash для путей вида `/sdcard/...` ставь `MSYS_NO_PATHCONV=1`. Скриншоты и логи клади в каталог scratchpad сессии, не в репозиторий.

1. **Эмулятор.** `$ADB devices` — если устройства `emulator-*` нет, запусти `emulator.exe -avd Pixel_8 -no-snapshot-save -no-boot-anim` **в фоне** (run_in_background), затем жди загрузки: `$ADB wait-for-device` и повторяй `$ADB shell getprop sys.boot_completed` (через Monitor/until-цикл, без sleep), пока не будет `1`.
2. **Сборка и установка.** `flutter build apk --debug --target-platform android-x64`, затем `$ADB install -r build/app/outputs/flutter-apk/app-debug.apk`.
3. **Запуск.** `$ADB logcat -c`, затем `$ADB shell am start -W -n com.tonyvinsenty.bookapp/.MainActivity`. Если в аргументах есть файл книги — сначала `$ADB push <файл> /sdcard/Download/` и опиши, где его искать в приложении.
4. **Что видно.** Подожди отрисовки (повтори `$ADB shell dumpsys window | grep mCurrentFocus`, пока фокус не на `com.tonyvinsenty.bookapp`), затем `MSYS_NO_PATHCONV=1 $ADB exec-out screencap -p > <scratchpad>/screen.png` и открой картинку инструментом Read. Для сценариев используй `$ADB shell input tap X Y`, `input swipe`, `input keyevent 4` (назад); после каждого действия — новый скриншот.
5. **Журнал.** `$ADB logcat -d -s flutter:V AndroidRuntime:E` и поиск `FATAL EXCEPTION`, `Exception`, `RenderFlex overflowed`, `ANR`. Ошибки покажи с объяснением.
6. **Итог владельцу** — 2–4 строки: что проверено, что видно на экране (тексты на русском, тема, нет ли обрезанных надписей), найденные ошибки. Эмулятор не выключай, если владелец не просил.

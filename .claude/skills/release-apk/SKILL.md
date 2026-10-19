---
name: release-apk
description: Собрать релизный APK BookApp, подписанный ключом владельца, проверить подпись и положить файл с понятным именем. Использовать, когда владелец просит APK для себя или друзей.
disable-model-invocation: true
argument-hint: "[all — APK для всех процессоров; по умолчанию только arm64]"
allowed-tools: Bash(flutter analyze *) Bash(flutter test *) Bash(flutter build apk *) Bash(git status *) Bash(git log *) PowerShell(flutter analyze *) PowerShell(flutter test *) PowerShell(flutter build apk *) PowerShell(git status *) PowerShell(git log *)
---

Собери релизный APK BookApp. Аргументы: $ARGUMENTS. Объясняй владельцу шаги просто, по-русски.

1. **Ключ.** Проверь, что переменная `BOOKAPP_KEYSTORE_PROPERTIES` задана и файл по этому пути существует (`test -f "$BOOKAPP_KEYSTORE_PROPERTIES"`). Содержимое файла и `.jks` **не читай**. Если переменной нет — остановись и отправь владельца к `docs/how-to-android-release.md` (часто помогает просто перезапустить VS Code после настройки).
2. **Проверки.** `git status --short` — если есть незакоммиченные изменения, предупреди (APK будет не из коммита). Затем `flutter analyze` и `flutter test`; при ошибке — остановись и покажи причину.
3. **Сборка.** По умолчанию: `flutter build apk --release --target-platform android-arm64` (все современные телефоны). Если в аргументах `all` — `flutter build apk --release` (больше файл, подходит и старым телефонам). Сборка идёт несколько минут — запускай с таймаутом 10 минут.
4. **Подпись.** `D:/Android/Sdk/build-tools/37.0.0/apksigner.bat verify --print-certs build/app/outputs/flutter-apk/app-release.apk` (если этой версии нет — возьми самую новую папку в `D:/Android/Sdk/build-tools/`). В строке `Signer #1 certificate DN` не должно быть `Android Debug`; покажи DN и SHA-256 владельцу. Если подпись отладочная — это ошибка, APK не отдавать.
5. **Файл.** Версию возьми из `pubspec.yaml` (`version: X.Y.Z+N`). Скопируй APK в `build/release/BookApp-X.Y.Z-N.apk` (папку создай) и назови владельцу полный путь, размер в МБ и коммит (`git log --oneline -1`).
6. **Как поставить.** Коротко: передать файл на телефон (Telegram «Избранное» и т. п.), открыть, разрешить установку из этого источника. Обновление встаёт поверх старой версии и сохраняет книги, пока ключ тот же. Напомни, что `versionCode` (число после `+` в `pubspec.yaml`) для следующего выпуска нужно увеличить.

Не делай `git push`, не меняй `build.gradle.kts` и подпись, не создавай ключей.

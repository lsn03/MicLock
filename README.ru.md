# MicLock

[English](README.md) · **Русский**

Крошечное приложение в меню-баре macOS, которое **лочит выбранный микрофон**.

По умолчанию macOS автоматически переключает системный вход на любое
новое Bluetooth- или USB-устройство. Воткнул наушники — и голос пошёл через
их микрофон, обычно сильно хуже основного.

MicLock это чинит. Один раз выбираешь нужный микрофон — приложение держит его
системным по умолчанию, что бы ты ни подключал. Звук (output) не трогается —
наушники всё так же играют.

## Установка

1. Скачай последний `.dmg` со страницы
   [Releases](https://github.com/lsn03/MicLock/releases).
2. Открой его и перетащи **MicLock** в папку **Applications**.
3. В `/Applications`: **правый клик по MicLock → Открыть → Открыть**.
   (Только при первом запуске — Gatekeeper ругается из-за ad-hoc подписи.)

В меню-баре появится иконка. Клик — выбираешь микрофон, галочка слева
показывает залоченный. Включи `Launch at Login`, чтобы запускалось вместе
с системой.

## Возможности

- Лочит дефолтный input между переподключениями устройств.
- Output оставляет автоматическим (наушники всё ещё играют).
- Меню не закрывается после выбора — удобно просматривать устройства;
  через 30 секунд бездействия закрывается само.
- Список устройств обновляется вживую, пока меню открыто.
- Автозапуск при входе через `SMAppService`.
- Чистый Swift + AppKit + CoreAudio. Без фонового демона и поллинга.

## Сборка из исходников

Требуется macOS 13+ и Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/lsn03/MicLock.git
cd MicLock
./build.sh                 # собирает build/MicLock.app
./release.sh               # собирает build/MicLock-<version>.dmg
```

Иконки генерируются из SVG через `rsvg-convert` + `iconutil`:

```bash
brew install librsvg
./design/build-icons.sh    # пересобирает Resources/AppIcon.icns + MicLockTemplate.pdf
```

## Структура проекта

```
Sources/MicLock/
  main.swift              точка входа
  AppDelegate.swift       статус-итем и меню
  AudioController.swift   слушатели CoreAudio и enforcement лока
  DeviceRowView.swift     кастомная строка меню (hover + не закрывает меню)
  CheckboxRowView.swift   то же для переключателей в Preferences
  Settings.swift          обёртка над UserDefaults
Resources/
  Info.plist              LSUIElement, SMAppService, иконка
  AppIcon.icns            иконка приложения
  MicLockTemplate.pdf     template-иконка для меню-бара
design/
  concepts/               исходные SVG
  build-icons.sh          SVG → icns/pdf
```

## Лицензия

MIT.

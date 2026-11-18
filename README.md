<div align="center">

<img src="promo/out/logo-1024.png" width="128" alt="Traart">

# Traart

**Бесплатный оффлайн-транскрибатор для macOS**

SOTA-модель GigaAM v3 (WER 8.3%) + диаризация pyannote. Локально, без облака, без подписок.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2013+-black?logo=apple)](https://traart.ru/download)
[![Release](https://img.shields.io/github/v/release/akuroglo/Traart?color=green)](https://github.com/akuroglo/Traart/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/akuroglo/Traart/total?color=purple)](https://github.com/akuroglo/Traart/releases)

[Скачать DMG](https://github.com/akuroglo/Traart/releases/latest/download/Traart.dmg) &nbsp;&middot;&nbsp; [Сайт](https://traart.ru) &nbsp;&middot;&nbsp; [Как работает](https://traart.ru/how-it-works) &nbsp;&middot;&nbsp; [Telegram](https://t.me/AIgobrr)

</div>

---

<div align="center">

<img src="assets/demo.gif" width="640" alt="Traart — демо">

</div>

## Возможности

| | Фича | Описание |
|---|---|---|
| **🎙** | **Записать заметку** | Записал голосом прямо из менюбара — текст автоматически в буфере обмена. Cmd+V в Cursor / Claude Code / ChatGPT |
| **✨** | **Транскрибация** | GigaAM v3 — лучшая точность для русской речи (WER 8.3%, INTERSPEECH 2025) |
| **👥** | **Диаризация** | Автоматическое разделение по спикерам (pyannote) |
| **🔒** | **100% оффлайн** | Все данные остаются на вашем Mac |
| **📁** | **Авто-мониторинг** | Следит за папками и транскрибирует новые файлы автоматически |
| **🎬** | **Все форматы** | MP3, WAV, M4A, OGG, FLAC, OPUS, MP4, MKV, WebM, MOV |
| **📝** | **Экспорт** | Markdown, TXT, JSON, SRT, VTT |
| **⌨️** | **Menu bar** | Живёт в строке меню, не мешает работе |

### Записать заметку — для вайбкодеров

```
[Менюбар] → "Записать заметку" (⌘R)
  → Говорите промпт / идею / коммит-месседж
  → Клик "Стоп"
  → Транскрибация (GigaAM v3)
  → Текст автоматически в clipboard
  → Cmd+V в Cursor / Claude Code / терминал
```

Ноль промежуточных шагов. Наговорил — вставил.

## Установка

### Скачать DMG

1. Скачайте [Traart.dmg](https://github.com/akuroglo/Traart/releases/latest/download/Traart.dmg)
2. Откройте DMG и перетащите Traart в Applications
3. Запустите — модели загрузятся автоматически (~2 ГБ при первом запуске)

Если загрузка GigaAM завершилась ошибкой, см. [восстановление установки и проверенные файлы модели](MODEL_DOWNLOAD.md).

### Homebrew (скоро)

```bash
brew install --cask traart
```

## Сборка из исходников

```bash
git clone https://github.com/akuroglo/Traart.git
cd Traart
./scripts/build.sh
# → build/Traart.app
```

<details>
<summary>Требования для сборки</summary>

- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`)
- Python 3.10+ (или `brew install python@3.12`)

</details>

## Системные требования

- **macOS** 13 (Ventura) или новее
- **Процессор:** Apple Silicon (M1 / M2 / M3 / M4) или Intel
- **RAM:** 8 ГБ (рекомендуется 16 ГБ)
- **Диск:** ~2 ГБ для моделей

## Архитектура

```
TraartApp/              Swift-приложение (SPM, AppKit)
├── Sources/TraartApp/  Menu bar controller, transcription manager,
│                       microphone recorder, file watcher, settings
engine/                 Python-движок
├── transcribe.py       GigaAM v3 ASR
├── diarize.py          pyannote speaker diarization
├── watcher.py          File system monitoring
└── setup_env.py        Авто-установка venv + моделей
scripts/                Сборка, DMG, установка
marketing/website/      Сайт traart.ru (статический HTML)
promo/                  Remotion промо-ролики
```

| Компонент | Технология |
|-----------|-----------|
| Приложение | Swift 5.9, SPM, AppKit |
| ASR | GigaAM v3 (Сбер, INTERSPEECH 2025) |
| Диаризация | pyannote.audio |
| ML Runtime | PyTorch + MPS (Apple Silicon GPU) |
| Аналитика | TelemetryDeck (opt-out) |
| Сайт | Статический HTML, Vercel |

## Лицензия

[MIT](LICENSE)

## Ссылки

- [traart.ru](https://traart.ru) — сайт
- [traart.ru/download](https://traart.ru/download) — скачать
- [traart.ru/use-case-vibecoders](https://traart.ru/use-case-vibecoders) — для вайбкодеров
- [Telegram: @AIgobrr](https://t.me/AIgobrr) — канал

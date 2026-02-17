# Traart

**Бесплатный транскрибатор для macOS** — расшифровка аудио и видео в текст оффлайн.

SOTA-модель GigaAM v3 (WER 8.3% на русском) + диаризация спикеров pyannote. Всё работает локально, без облака и подписок.

## Возможности

- **Транскрибация** — GigaAM v3, лучшая точность для русской речи
- **Диаризация** — автоматическое разделение по спикерам (pyannote)
- **100% оффлайн** — данные не покидают ваш Mac
- **Авто-мониторинг** — следит за папкой и транскрибирует новые файлы
- **Форматы** — MP3, WAV, M4A, OGG, FLAC, MP4, MKV, WebM, MOV
- **Экспорт** — Markdown, TXT, JSON
- **Menu bar** — живёт в строке меню, не мешает работе

## Системные требования

- macOS 13 (Ventura) или новее
- Apple Silicon (M1, M2, M3, M4)
- 8 ГБ RAM (рекомендуется 16 ГБ)
- ~2 ГБ для моделей (скачиваются при первом запуске)

## Установка

1. Скачайте .dmg со [страницы загрузки](https://traart.ru/download)
2. Перетащите Traart в Applications
3. Запустите — модели загрузятся автоматически

## Сборка из исходников

```bash
# Клонировать репо
git clone https://github.com/AKuroglosWorlds/Traart.git
cd Traart

# Собрать приложение
./scripts/build.sh

# Результат: build/Traart.app
```

### Требования для сборки

- Xcode Command Line Tools (`xcode-select --install`)
- Python 3.10+ (или Homebrew: `brew install python@3.12`)

## Структура проекта

```
TraartApp/          Swift-приложение (SPM)
engine/             Python-движок (transcribe, diarize, watcher)
scripts/            Скрипты сборки и установки
marketing/website/  Сайт traart.ru
promo/              Remotion промо-ролики
```

## Технологии

| Компонент | Технология |
|-----------|-----------|
| Приложение | Swift, SPM, AppKit |
| ASR | GigaAM v3 (Сбер) |
| Диаризация | pyannote.audio |
| ML Runtime | PyTorch + MPS (Apple Silicon) |
| Сайт | Статический HTML, Vercel |

## Лицензия

MIT — см. [LICENSE](LICENSE)

## Ссылки

- [traart.ru](https://traart.ru) — сайт
- [traart.ru/download](https://traart.ru/download) — скачать
- [traart.ru/how-it-works](https://traart.ru/how-it-works) — как работает

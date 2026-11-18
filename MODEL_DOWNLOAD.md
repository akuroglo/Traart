# Восстановление загрузки GigaAM в Traart

Если установка остановилась на `Failed to download v3_e2e_rnnt.ckpt after retries`,
установите [актуальный Traart](https://github.com/akuroglo/Traart/releases/latest/download/Traart.dmg)
и повторите настройку. Начиная с 1.1.6, установщик использует зеркало GitHub,
резервный CDN и проверяет SHA-256 модели и токенизатора. Проверка TLS включена.

## Восстановление без обновления приложения

Закройте Traart. Следующий блок можно целиком вставить в Terminal. Он скачивает
два файла во временную папку, проверяет закреплённые SHA-256 и только после
успешной проверки помещает оба файла в каталог моделей Traart.

```bash
(
  set -eu
  traart_tmp="$(mktemp -d)"
  trap 'rm -rf "$traart_tmp"' EXIT
  traart_models="$HOME/Library/Application Support/Traart/models/gigaam"
  traart_source="https://github.com/akuroglo/Traart/releases/download/models-gigaam-v3-f60c62fe"
  cd "$traart_tmp"
  for traart_file in v3_e2e_rnnt.ckpt v3_e2e_rnnt_tokenizer.model; do
    curl --fail --show-error --location --retry 3 --connect-timeout 30 \
      --output "$traart_file" "$traart_source/$traart_file"
  done
  shasum -a 256 --check <<'CHECKSUMS'
f60c62fe45902d967000770a12f260de7c5ac4d4b8e5e852f1df8c548e3958b5  v3_e2e_rnnt.ckpt
828c12c991019eef952a960661f25a92d6ad279591e2ea466b4aeddf1d20a18a  v3_e2e_rnnt_tokenizer.model
CHECKSUMS
  mkdir -p "$traart_models"
  mv v3_e2e_rnnt.ckpt v3_e2e_rnnt_tokenizer.model "$traart_models/"
  echo 'Модель проверена и установлена. Откройте Traart и повторите настройку.'
)
```

Загрузка занимает около 449 МБ. Повторная настройка использует уже скачанные
файлы. Переустановка Python или PyTorch для этого исправления не требуется.

## Происхождение и контрольные суммы

Это неизменённые файлы GigaAM v3 из CDN проекта
[salute-developers/GigaAM](https://github.com/salute-developers/GigaAM),
сохранённые в рабочем кэше до сбоя сертификата CDN 4 ноября 2026 года.
Checkpoint совпадает с MD5 `2730de7545ac43ad256485a462b0a27a`, закреплённым
в предыдущем установщике Traart. SHA-256 токенизатора также совпадает с
[официальной копией Hugging Face](https://huggingface.co/ai-sage/GigaAM-v3/tree/7655ad717f8122257385bb4b2f373db3697e8680).

| Файл | Размер, байт | SHA-256 |
| --- | ---: | --- |
| `v3_e2e_rnnt.ckpt` | 448929252 | `f60c62fe45902d967000770a12f260de7c5ac4d4b8e5e852f1df8c548e3958b5` |
| `v3_e2e_rnnt_tokenizer.model` | 255336 | `828c12c991019eef952a960661f25a92d6ad279591e2ea466b4aeddf1d20a18a` |

Модель распространяется по MIT License, Copyright (c) 2024 GigaChat Team.
Копия лицензии и файл `SHA256SUMS` приложены к
[релизу с моделью](https://github.com/akuroglo/Traart/releases/tag/models-gigaam-v3-f60c62fe).
Этот релиз содержит данные модели; он не заменяет релизы приложения.

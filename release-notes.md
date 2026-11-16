# NetMeter 1.1.5

## English

- Fixed network speeds and totals on busy connections by using true 64-bit interface counters. Unavailable measurements are shown separately from idle traffic.
- Fixed independent graph preferences and migration of saved settings.
- Moved metric collection off the main thread; added bounded command execution, sleep-gap handling and sensor rediscovery.
- Added GPU core counts when reported by the device, explicit GiB memory units, swap and kernel memory-pressure details.
- Improved font fitting, one-line network headings, window containment and Activity Monitor navigation.
- Added local diagnostic export with a restricted, privacy-conscious schema.
- Updated Sparkle to 2.10.1 and strengthened clean Universal builds, update verification and regression checks. Signed update archives now use immutable version URLs.
- Updated English, Russian, Arabic and Simplified Chinese text and EN/RU documentation.

Requires macOS 13 or later; Universal for Apple Silicon and Intel. Developer ID notarization is not configured.

## Русский

- Исправлены скорость и итоги трафика на загруженных соединениях: используются настоящие 64-битные счётчики интерфейса. Недоступные измерения отличаются от нулевого трафика.
- Исправлены независимые настройки графиков и перенос сохранённых параметров.
- Сбор метрик перенесён с главного потока; добавлены таймауты команд, обработка пауз после сна и повторный поиск датчиков.
- Добавлены число ядер GPU, если его сообщает устройство, единицы GiB для памяти, сведения о swap и системном давлении памяти.
- Улучшены подгонка шрифтов, однострочный заголовок сети, размещение окон и переход в «Мониторинг системы».
- Добавлен локальный экспорт диагностики с ограниченным составом данных.
- Sparkle обновлён до 2.10.1; усилены чистая Universal-сборка, проверка обновлений и регрессионные тесты. Подписанные архивы обновлений используют неизменяемые адреса конкретной версии.
- Обновлены четыре перевода и документация на английском и русском.

Требуется macOS 13 или новее; Universal для Apple Silicon и Intel. Notarization через Developer ID не настроена.

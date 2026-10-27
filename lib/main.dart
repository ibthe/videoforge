
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'licensing.dart';

// Lightweight built-in localization; language choice is saved on this device.
final ValueNotifier<String> videoForgeLanguage = ValueNotifier<String>('ru');
String _activeLanguage = 'ru';
const Map<String, Map<String, String>> _translations = {
  'en': {
    'Конвертация видео': 'Video conversion',
    'ЛОКАЛЬНО': 'ON DEVICE',
    'Пакетная обработка': 'Batch processing',
    'Добавьте видео и выберите качество.': 'Add videos and choose quality.',
    'Добавить видео': 'Add videos',
    'Добавить ещё': 'Add more',
    'Профиль экспорта': 'Export profile',
    'Выберите, что важнее: качество или размер': 'Choose what matters: quality or size',
    'Высокое качество': 'High quality',
    'Сбалансированный': 'Balanced',
    'Компактный размер': 'Smaller file',
    'YouTube 1080p': 'YouTube 1080p',
    'Без потерь — новое кодирование': 'Lossless — re-encoding',
    'Мой профиль': 'My profile',
    'Меньше потерь качества, файл может быть больше.': 'Less quality loss; file may be larger.',
    'Рекомендуемый баланс качества и размера.': 'Recommended balance of quality and size.',
    'Меньше места на диске, заметнее потери качества.': 'Uses less disk space, with more visible quality loss.',
    'MP4 до 1080p с сохранением пропорций.': 'MP4 up to 1080p, preserving aspect ratio.',
    'FFV1 в MKV: новое кодирование видео без потерь. Файл может быть значительно больше; не все платформы принимают этот формат.': 'FFV1 in MKV: lossless video encoding. Files can be much larger; some platforms do not support this format.',
    'Пользовательские настройки кодирования. Настройте CRF и скорость в конструкторе профиля.': 'Custom encoding settings. Adjust CRF and speed in the profile builder.',
    'Анализ': 'Analyze',
    'Быстро': 'Fast',
    'Отмена': 'Cancel',
    'Закрыть': 'Close',
    'История': 'History',
    'Профиль': 'Profile',
    'Исходник': 'Source',
    'Очистить': 'Clear',
    'Сравнить': 'Compare',
    'РЕЗУЛЬТАТ': 'OUTPUT',
    'Результат': 'Output',
    'Сохранить': 'Save',
    'Тест 20 с': '20 s test',
    'Публикации': 'Publishing',
    'Диагностика': 'Diagnostics',
    'ID установки': 'Installation ID',
    'Анализ видео': 'Video analysis',
    'Очень быстро': 'Very fast',
    'Создать тест': 'Create test',
    'Очередь видео': 'Video queue',
    'Готов к работе': 'Ready',
    'Пока нет видео': 'No videos yet',
    'Сбалансировано': 'Balanced',
    'Тест 20 секунд': '20-second test',
    'Кадр недоступен': 'Frame unavailable',
    'Обработка видео': 'Video processing',
    'Проверить время': 'Check time',
    'История экспорта': 'Export history',
    'Начать сравнение': 'Start comparison',
    'Сравнить профили': 'Compare profiles',
    'Запустить очередь': 'Start queue',
    'Оставить как есть': 'Keep as is',
    'Подобрать профиль': 'Suggest profile',
    'Применить профиль': 'Apply profile',
    'Сохранить профиль': 'Save profile',
    'Тестовый фрагмент': 'Test clip',
    'Активация лицензии': 'License activation',
    'ПАКЕТНАЯ ОБРАБОТКА': 'BATCH PROCESSING',
    'История пока пуста.': 'History is empty.',
    'Конструктор профиля': 'Profile builder',
    'Менеджер публикаций': 'Publishing manager',
    'Проверить результат': 'Review result',
    'Результаты сравнения': 'Comparison results',
    'Скорость кодирования': 'Encoding speed',
    'Технические сведения': 'Technical details',
    'Выполняется проверка…': 'Checking…',
    'Готовый файл сохранён': 'Output saved',
    'Медленно, эффективнее': 'Slow, more efficient',
    'Отпустите файлы здесь': 'Drop files here',
    'Профили для сравнения': 'Profiles to compare',
    'Сохранение результата': 'Saving output',
    'Папка для готовых видео': 'Output folder',
    'Рекомендация VideoForge': 'VideoForge recommendation',
    'Дополнительные инструменты': 'More tools',
    'Галерея → альбом VideoForge': 'Gallery → VideoForge album',
    'Без загрузки файлов в облако': 'Files stay on your device',
    'Сравнение исходника и результата': 'Compare source and output',
    'MP4 · MOV · MKV · M4V · AVI · WEBM': 'MP4 · MOV · MKV · M4V · AVI · WEBM',
    'Добавьте один или несколько файлов': 'Add one or more files',
    'Подготовь видео\nк следующему шагу.': 'Prepare your video\nfor the next step.',
    'Обработка выполняется локально на вашем устройстве': 'Processing happens on your device',
    'Добавь видео, настрой качество и запусти обработку.': 'Add videos, set quality, and start processing.',
    'Сначала обработать первые 20 секунд, чтобы проверить настройки и примерный размер файла.': 'Process the first 20 seconds to check settings and approximate file size.',
    'CRF: ниже — выше качество и обычно больше размер. Доступный диапазон этого профиля: 0–35.': 'CRF: lower means higher quality and usually a larger file. Range: 0–35.',
    'Сохраняются локально в приложении. Статистика платформ сюда автоматически не импортируется.': 'Saved locally in the app. Platform statistics are not imported automatically.',
    'Рекомендация основана на доступных метаданных и размере файла, а не гарантирует лучший результат для любого видео.': 'This recommendation uses available metadata and file size; it cannot guarantee the best result for every video.',
    'Этот профиль использует H.264 в MP4. CRF 0 зависит от сборки кодека и не гарантируется как lossless; для строгого режима без потерь выбирайте FFV1.': 'This profile uses H.264 in MP4. CRF 0 is not guaranteed lossless; choose FFV1 for strict lossless encoding.',
    'Один и тот же 20-секундный фрагмент будет обработан каждым выбранным профилем. Сравнение показывает размер и время, но не гарантирует одинаковое визуальное качество.': 'The same 20-second clip will be processed with each selected profile. Comparison shows size and time, not guaranteed identical visual quality.',
    'Кадры показывают только одну точку примерно в середине видео. Это визуальная проверка, а не математическое доказательство отсутствия потерь. Для FFV1 исходные декодированные кадры должны сохраняться без потерь.': 'Frames show one point near the middle of the video. This is a visual check, not mathematical proof of no loss. FFV1 should preserve decoded frames losslessly.',
    'ОРИГИНАЛ': 'SOURCE',
    'Размер неизвестен': 'Size unknown',
    'Исходное видео': 'Source video',
    'Видео': 'Video',
    'Название публикации': 'Publication title',
    'Описание': 'Description',
    'Теги (через запятую)': 'Tags (comma-separated)',
    'Заметки / результаты теста': 'Notes / test results',
    'Email лицензии': 'License email',
    'Лицензионный ключ': 'License key',
    'Информация о сохранении': 'Saving information',
    'Выбрать папку результата': 'Choose output folder',
    'Открыть папку': 'Open folder',
    'Как сохранить результат': 'How to save output',
    'Анализ и сведения о видео': 'Video analysis and details',
    'Поделиться или сохранить видео': 'Share or save video',
    'Убрать из списка': 'Remove from list',
    'Автоматическая проверка свободного места недоступна на этом устройстве.': 'Automatic free-space check is unavailable on this device.',
    'В очереди нет доступных исходных видео.': 'No available source videos in the queue.',
    'Вариант публикации сохранён.': 'Publication draft saved.',
    'Готовые видео сохраняются в галерею телефона, альбом VideoForge.': 'Finished videos are saved to your phone gallery, VideoForge album.',
    'Дождитесь завершения кодирования перед добавлением файлов.': 'Wait for encoding to finish before adding files.',
    'Лицензия ещё загружается. Подождите несколько секунд и повторите.': 'License is still loading. Wait a few seconds and try again.',
    'Лицензия успешно активирована.': 'License activated successfully.',
    'Нет готового файла для проверки.': 'No completed file to review.',
    'Папка результата сохранена.': 'Output folder saved.',
    'Подготавливаем кадры для сравнения…': 'Preparing frames for comparison…',
    'Поддерживаются MP4, MOV, MKV, M4V, AVI и WEBM.': 'Supported formats: MP4, MOV, MKV, M4V, AVI, WEBM.',
    'Пользовательский профиль сохранён.': 'Custom profile saved.',
    'Проверка лицензии ещё не завершена.': 'License check has not finished yet.',
    'Сначала выберите видео для кодирования.': 'Select a video to encode first.',
    'Сначала добавьте видео, чтобы подобрать профиль.': 'Add a video first to get a profile recommendation.',
    'Эти видео уже есть в очереди.': 'These videos are already in the queue.',
    'Основная папка недоступна. Используется папка приложения.': 'Main folder unavailable. Using the app folder.',
    'Требуется доступ к хранилищу': 'Storage access required',
    'Готово к работе': 'Ready',
    'Запускаем кодирование…': 'Starting encoding…',
    'Отменяем текущий файл…': 'Cancelling current file…',
    'Подготавливаем папку для результатов…': 'Preparing output folder…',
    'Папка результата изменена': 'Output folder changed',
    'Активировать': 'Activate',
    'Проверяем…': 'Checking…',
    'Введите email, на который выпущен ключ.': 'Enter the email address the key was issued to.',
    'Проверьте адрес email.': 'Check the email address.',
    'Введите лицензионный ключ.': 'Enter the license key.',
    'не определён': 'not detected',
    'Лицензия': 'License',
    'Лицензия активна': 'License active',
    'Пробный период': 'Trial period',
    'Требуется лицензия': 'License required',
    'Пробный период завершён. Введите лицензионный ключ.': 'Trial period ended. Enter a license key.',
    'Проверяем лицензию…': 'Checking license…',
    'Сетевое время проверено.': 'Network time verified.',
    'Часы устройства спешат. Ключ не изменён; проверка требует корректных часов.': 'Device clock is ahead. The key was not changed; correct time is required.',
    'Нет сети: используется время устройства.': 'No network: using device time.',
    'Адрес сервера активации должен использовать HTTPS.': 'The activation server URL must use HTTPS.',
    'Сервер активации не ответил вовремя. Проверьте интернет и повторите попытку.': 'The activation server timed out. Check your connection and try again.',
    'Нет соединения с сервером активации.': 'Cannot connect to the activation server.',
    'дн.': 'days',
    'не рассчитано': 'not calculated',

    'Часы устройства отстают более чем на час. Ключ удалён; выставьте правильное время и повторите проверку.': 'The device clock is over an hour behind. The key was removed; set the correct time and check again.',
    'Обнаружен откат системного времени. Подключитесь к интернету и восстановите правильные часы.': 'A system-clock rollback was detected. Connect to the internet and restore the correct time.',
    'Сначала восстановите правильное время и выполните проверку через интернет.': 'Correct the device time first, then verify it online.',
    'Сервер активации не настроен. Соберите приложение с --dart-define=LICENSE_SERVER_URL=https://ваш-домен/v1/activate.': 'Activation server is not configured. Build with --dart-define=LICENSE_SERVER_URL=https://your-domain/v1/activate.',
    'Сервер вернул некорректный ответ.': 'The server returned an invalid response.',
    'Подписанная лицензия недействительна или выпущена для другого email/устройства.': 'The signed license is invalid or was issued for a different email/device.',
    'Не удалось сохранить настройки приложения.': 'Could not save app settings.',  },
  'ce': {
    'Конвертация видео': 'Видео хийцар',
    'ЛОКАЛЬНО': 'Устройствехь',
    'Пакетная обработка': 'Масех видео цхьаьна тӀехь болх бан',
    'Добавьте видео и выберите качество.': 'Видео тӀетоха, дикалла харжа.',
    'Добавить видео': 'Видео тӀетоха',
    'Добавить ещё': 'Кхин тӀетоха',
    'Профиль экспорта': 'Экспортан профиль',
    'Выберите, что важнее: качество или размер': 'Дикалла я файлан размер — хӀун хьалха лардан?',
    'Высокое качество': 'Лакхара дикалла',
    'Сбалансированный': 'Дикалли файлан бараман баланс',
    'Компактный размер': 'КӀезиг файл',
    'YouTube 1080p': 'YouTube 1080p',
    'Без потерь — новое кодирование': 'Потерь доцуш — керла кодировани',
    'Мой профиль': 'Сан профиль',
    'Меньше потерь качества, файл может быть больше.': 'Дикалла кӀезиг эшар; файл доккха хила мегар.',
    'Рекомендуемый баланс качества и размера.': 'Дикалли файлан бараман дика баланс.',
    'Меньше места на диске, заметнее потери качества.': 'Диск тӀехь кӀезиг меттиг лело; дикаллин эшар гуш хир ду.',
    'MP4 до 1080p с сохранением пропорций.': 'MP4, 1080p кхаччалц; видеон пропорци ларйо.',
    'FFV1 в MKV: новое кодирование видео без потерь. Файл может быть значительно больше; не все платформы принимают этот формат.': 'MKV форматехь FFV1: видеон дикалла эшар доцуш кодировани. Файл дукха доккха хила мегар; массо платформаша хӀокху формат тӀеэца йиш яц.',
    'Пользовательские настройки кодирования. Настройте CRF и скорость в конструкторе профиля.': 'Шен кодированин нисдарш. Профиль кхолларан гӀирсехь CRF а сихалла а нисде.',
    'Анализ': 'Таллам',
    'Быстро': 'Сиха',
    'Отмена': 'ДӀадаккхар',
    'Закрыть': 'ДӀакъовла',
    'История': 'Истори',
    'Профиль': 'Профиль',
    'Исходник': 'Хьалхара видео',
    'Очистить': 'ДӀаяккха',
    'Сравнить': 'Цхьаьна хьажа',
    'РЕЗУЛЬТАТ': 'ЖАМӀ',
    'Результат': 'ЖамӀ',
    'Сохранить': 'ДӀаӀалашде',
    'Тест 20 с': '20 с тест',
    'Публикации': 'Публикаци',
    'Диагностика': 'Диагностика',
    'ID установки': 'ID установки',
    'Анализ видео': 'Видео таллам',
    'Очень быстро': 'ЧӀогӀа сиха',
    'Создать тест': 'Тест кхолла',
    'Очередь видео': 'Видео къепйоза',
    'Готов к работе': 'Болх бан кийча ду',
    'Пока нет видео': 'ХӀинца цхьа а видео яц',
    'Сбалансировано': 'Баланс дина',
    'Тест 20 секунд': '20-секундан тест',
    'Кадр недоступен': 'Кадр тӀекхочийла бац',
    'Обработка видео': 'Видео тӀехь болх бан',
    'Проверить время': 'Хан талла',
    'История экспорта': 'Экспортан истори',
    'Начать сравнение': 'Цхьаьна хьажа доладе',
    'Сравнить профили': 'Профилаш цхьаьна хьажа',
    'Запустить очередь': 'Видео къепйоза дӀадоло',
    'Оставить как есть': 'Иштта дита',
    'Подобрать профиль': 'Профиль харжа',
    'Применить профиль': 'Профиль дӀахӀоттаде',
    'Сохранить профиль': 'Профиль дӀаӀалашде',
    'Тестовый фрагмент': 'Тестан фрагмент',
    'Активация лицензии': 'Лицензи активировани',
    'ПАКЕТНАЯ ОБРАБОТКА': 'ДУКХА ВИДЕО ЦХЬАЬНА КХОЧУШДАР',
    'История пока пуста.': 'Истори хӀинца яц.',
    'Конструктор профиля': 'Профиль кхоллар',
    'Менеджер публикаций': 'Публикацин менеджер',
    'Проверить результат': 'ЖамӀ талла',
    'Результаты сравнения': 'Цхьаьна хьажаран жамӀаш',
    'Скорость кодирования': 'Кодированин сихалла',
    'Технические сведения': 'Техникан хаамаш',
    'Выполняется проверка…': 'Таллам дулуш ду…',
    'Готовый файл сохранён': 'Файл дӀаӀалашдина',
    'Медленно, эффективнее': 'Сиха доцуш, пайда дукха',
    'Отпустите файлы здесь': 'Файлаш хӀокху метте йита',
    'Профили для сравнения': 'Цхьаьна хьажарна профилаш',
    'Сохранение результата': 'ЖамӀ Ӏалашдар',
    'Папка для готовых видео': 'Видео Ӏалашъен папка',
    'Рекомендация VideoForge': 'VideoForge хьехам',
    'Дополнительные инструменты': 'Кхин инструментанаш',
    'Галерея → альбом VideoForge': 'Телефонан галерея → VideoForge альбом',
    'Без загрузки файлов в облако': 'Файлаш хьан устройствехь Ӏалашло',
    'Сравнение исходника и результата': 'Хьалхара видео а жамӀ а цхьаьна хьажа',
    'MP4 · MOV · MKV · M4V · AVI · WEBM': 'MP4 · MOV · MKV · M4V · AVI · WEBM',
    'Добавьте один или несколько файлов': 'Цхьа я дукха файл тӀетоха',
    'Обработка выполняется локально на вашем устройстве': 'Видеон тӀехь болх хьан устройствехь деш бу',
    'Добавь видео, настрой качество и запусти обработку.': 'Видео тӀетоха, дикалла нисде, тӀаккха видеон тӀехь болх дӀадоло.',
    'Сначала обработать первые 20 секунд, чтобы проверить настройки и примерный размер файла.': 'Хьалха 20 секундан видеон тӀехь болх бе: нисдарш талла, файлан барам хьажа.',
    'CRF: ниже — выше качество и обычно больше размер. Доступный диапазон этого профиля: 0–35.': 'CRF кӀезиг — дикалла лакха, файл доккха хила мегар. Диапазон: 0–35.',
    'Сохраняются локально в приложении. Статистика платформ сюда автоматически не импортируется.': 'ХӀара приложенехь ларло. Платформан статистика автоматически тӀе ца яло.',
    'Рекомендация основана на доступных метаданных и размере файла, а не гарантирует лучший результат для любого видео.': 'Хьехам метаданни а файлан размер а тӀе хьажийна. ХӀора видеонна дика жамӀ хир хилар кепил йоцу.',
    'Этот профиль использует H.264 в MP4. CRF 0 зависит от сборки кодека и не гарантируется как lossless; для строгого режима без потерь выбирайте FFV1.': 'ХӀокху профиль MP4 форматехь H.264 кодек леладо. CRF 0 потерь доцуш хилар кепил йоцу; потерь доцуш кодированина FFV1 харжа.',
    'Один и тот же 20-секундный фрагмент будет обработан каждым выбранным профилем. Сравнение показывает размер и время, но не гарантирует одинаковое визуальное качество.': 'Цхьа 20-секундан фрагмент хаьржина хӀора профилехь кхочушдийр ду. Цхьаьна хьажар файлан барам а хан а гойту, амма визуальни дикалла цхьана тера хилар кепил йоцу.',
    'Кадры показывают только одну точку примерно в середине видео. Это визуальная проверка, а не математическое доказательство отсутствия потерь. Для FFV1 исходные декодированные кадры должны сохраняться без потерь.': 'Кадраш видеон юккъехь цхьа меттиг гойту. ХӀара визуальни таллам бу, потерь йоцун математически далил дац. FFV1 декодировани кадраш потерь доцуш лардан деза.',
    'ОРИГИНАЛ': 'ХЬАЛХАРА ВИДЕО',
    'Размер неизвестен': 'Файлан барам доьвзаш бац',
    'Исходное видео': 'Хьалхара видео',
    'Видео': 'Видео',
    'Название публикации': 'Публикацин цӀе',
    'Описание': 'Описани',
    'Теги (через запятую)': 'Тегаш (запятойца дӀакъастийна)',
    'Заметки / результаты теста': 'Беллам / тестан жамӀаш',
    'Email лицензии': 'Лицензин email',
    'Лицензионный ключ': 'Лицензин ключ',
    'Информация о сохранении': 'Ӏалашдарх хаам',
    'Выбрать папку результата': 'ЖамӀан папка харжа',
    'Открыть папку': 'Папка схьаелла',
    'Как сохранить результат': 'ЖамӀ муха Ӏалашдан',
    'Анализ и сведения о видео': 'Видео таллам а хаамаш а',
    'Поделиться или сохранить видео': 'Видео декъа я дӀаӀалашде',
    'Убрать из списка': 'Къепйозан чуьра дӀаяккха',
    'Автоматическая проверка свободного места недоступна на этом устройстве.': 'Дискан диса меттиг автоматическ талла хӀокху устройствехь йиш яц.',
    'В очереди нет доступных исходных видео.': 'Видео къепйозехь хьалхара видеош яц.',
    'Вариант публикации сохранён.': 'Публикацин вариант Ӏалашйина.',
    'Готовые видео сохраняются в галерею телефона, альбом VideoForge.': 'Кхочушдина видео телефонан галереях, VideoForge альбомехь ларло.',
    'Дождитесь завершения кодирования перед добавлением файлов.': 'Файлаш тӀетохалц кодировани чекхъялар хьажа.',
    'Лицензия ещё загружается. Подождите несколько секунд и повторите.': 'Лицензин хаамаш хӀинца кхочушбеш бу. Жима хан хьажа, тӀаккха юха талла.',
    'Лицензия успешно активирована.': 'Лицензи активна ю.',
    'Нет готового файла для проверки.': 'Талла кийча файл яц.',
    'Папка результата сохранена.': 'ЖамӀан папка Ӏалашйина.',
    'Подготавливаем кадры для сравнения…': 'Кадраш цхьаьна хьажарна кечйо…',
    'Поддерживаются MP4, MOV, MKV, M4V, AVI и WEBM.': 'MP4, MOV, MKV, M4V, AVI а WEBM форматаш лелош ю.',
    'Пользовательский профиль сохранён.': 'Шен профиль дӀаӀалашдина.',
    'Проверка лицензии ещё не завершена.': 'Лицензин таллам хӀинца чекхдаьлла бац.',
    'Сначала выберите видео для кодирования.': 'Кодированина хьалха видео харжа.',
    'Сначала добавьте видео, чтобы подобрать профиль.': 'Профиль харжарна хьалха видео тӀетоха.',
    'Эти видео уже есть в очереди.': 'ХӀара видеош хӀинца а видео къепйоза чу ду.',
    'Основная папка недоступна. Используется папка приложения.': 'Коьрта папка тӀекхочийла яц. Приложенин папка лелош ю.',
    'Требуется доступ к хранилищу': 'Файлашна доступ оьшу',
    'Готово к работе': 'Болх бан кийча ду',
    'Запускаем кодирование…': 'Видеон тӀехь болх дӀадолу…',
    'Отменяем текущий файл…': 'ХӀинца тӀехь болх беш болу файл дӀадаккха…',
    'Подготавливаем папку для результатов…': 'ЖамӀаш Ӏалашъен папка кечйо…',
    'Папка результата изменена': 'ЖамӀан папка хийцина',
    'дн.': 'де',
    'не рассчитано': 'Хисап ца дина',
    'Подготовь видео\nк следующему шагу.': 'Кхин тӀаьхьарчу кадаме видео кечде.',
    'Активировать': 'Активировать',
    'Проверяем…': 'Таллам дулуш ду…',
    'Введите email, на который выпущен ключ.': 'Ключ язйинчу email адрес тӀетоха.',
    'Проверьте адрес email.': 'Email адрес нийса хилар хьажа.',
    'Введите лицензионный ключ.': 'Лицензин ключ тӀетоха.',
    'не определён': 'Ца карийна',
    'Лицензия': 'Лицензи',
    'Лицензия активна': 'Лицензи активна',
    'Пробный период': 'Тестан хан',
    'Требуется лицензия': 'Лицензи оьшу',
    'Пробный период завершён. Введите лицензионный ключ.': 'Тестан хан чекхъяьлла. Лицензин ключ тӀетоха.',
    'Проверяем лицензию…': 'Лицензи таллам дулуш ду…',
    'Сетевое время проверено.': 'Интернетан хан таллина.',
    'Часы устройства спешат. Ключ не изменён; проверка требует корректных часов.': 'Устройстван хан хьалха ю. Ключ хийцина дац; талламна нийса хан оьшу.',
    'Нет сети: используется время устройства.': 'Интернет яц; устройствен хан лелош ю.',
    'Адрес сервера активации должен использовать HTTPS.': 'Активацин серверийн адрес HTTPS хила деза.',
    'Сервер активации не ответил вовремя. Проверьте интернет и повторите попытку.': 'Активацин сервер ханал тӀаьхьа жоп ца делла. Интернет хьажа, тӀаккха юха талла.',
    'Нет соединения с сервером активации.': 'Активацин серверна тӀе ца тасало.',
    'Часы устройства отстают более чем на час. Ключ удалён; выставьте правильное время и повторите проверку.': 'Устройстван хан интернетан хенал сахьтал кӀезиг ю. Ключ дӀадаккхина; нийса хан тохха, тӀаккха юха таллам де.',
    'Обнаружен откат системного времени. Подключитесь к интернету и восстановите правильные часы.': 'Устройстван системан хан юхайоьлла. Интернет тӀетесса, нийса хан тохха.',
    'Сначала восстановите правильное время и выполните проверку через интернет.': 'Хьалха нийса хан тохха, тӀаккха интернетца таллам де.',
    'Сервер активации не настроен. Соберите приложение с --dart-define=LICENSE_SERVER_URL=https://ваш-домен/v1/activate.': 'Активацин сервер нисдина бац. --dart-define=LICENSE_SERVER_URL=https://ваш-домен/v1/activate тохамца приложени билд де.',
    'Сервер вернул некорректный ответ.': 'Сервер нийса доцу жоп делла.',
    'Подписанная лицензия недействительна или выпущена для другого email/устройства.': 'Лицензин тамга нийса яц, я кхечу email адрес/устройстванна язйина.',
    'Не удалось сохранить настройки приложения.': 'Приложенин нисдарш Ӏалашдан аьтто ца баьлла.',
  },
};
String tr(String russian) {
  if (_activeLanguage == 'ru') return russian;
  final english = _activeLanguage == 'en';

  if (russian.startsWith('Лицензия активна')) {
    final replacement = english ? 'License active' : 'Лицензи активна';
    return russian.replaceFirst('Лицензия активна', replacement);
  }

  final trial = RegExp(r'^Пробный период: осталось (\d+) дн\.$').firstMatch(russian);
  if (trial != null) {
    final days = trial.group(1)!;
    return english ? 'Trial period: $days days left' : 'Тестан хан: $days де дисна';
  }

  final count = RegExp(r'^(\d+) файлов · готово (\d+)$').firstMatch(russian);
  if (count != null) {
    return english
        ? '${count.group(1)} files · ${count.group(2)} done'
        : 'Файлаш: ${count.group(1)} · кхочушдина: ${count.group(2)}';
  }

  final recommendation = RegExp(r'^Для «(.*)» предлагается профиль «(.*)»\.$').firstMatch(russian);
  if (recommendation != null) {
    final job = recommendation.group(1)!;
    final profile = recommendation.group(2)!;
    return english
        ? 'Suggested profile for “$job”: “$profile”.'
        : '«$job» видеонна «$profile» профиль хьехадо.';
  }

  final estimate = RegExp(r'^Оценка размера: (.+)$').firstMatch(russian);
  if (estimate != null) {
    return english ? 'Estimated size: ${estimate.group(1)}' : 'Файлан бараман маххадор: ${estimate.group(1)}';
  }

  final selected = RegExp(r'^Убрать выбранные \((\d+)\)$').firstMatch(russian);
  if (selected != null) {
    return english ? 'Remove selected (${selected.group(1)})' : 'Хаьржина файлаш къепйозан чуьра дӀаяккха (${selected.group(1)})';
  }

  final checking = RegExp(r'^Проверка завершена: (.*)$').firstMatch(russian);
  if (checking != null) {
    return english ? 'Check complete: ${tr(checking.group(1)!)}' : 'Таллам чекхбаьлла: ${tr(checking.group(1)!)}';
  }

  final timeError = RegExp(r'^Не удалось проверить время: (.*)$').firstMatch(russian);
  if (timeError != null) {
    return english ? 'Could not check time: ${timeError.group(1)}' : 'Хан талла йиш яц: ${timeError.group(1)}';
  }

  final activationError = RegExp(r'^Ошибка активации: (.*)$').firstMatch(russian);
  if (activationError != null) {
    return english ? 'Activation error: ${activationError.group(1)}' : 'Активацин гӀалат: ${activationError.group(1)}';
  }

  final httpError = RegExp(r'^Сервер отклонил активацию \(HTTP (\d+)\)\.$').firstMatch(russian);
  if (httpError != null) {
    return english ? 'Activation rejected by server (HTTP ${httpError.group(1)}).' : 'Серверо активаци тӀе ца оьцу (HTTP ${httpError.group(1)}).';
  }

  final translations = _translations[_activeLanguage];
  return translations?[russian] ?? russian;
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    videoForgeLanguage.value = prefs.getString('videoforge.language') ?? 'ru';
    _activeLanguage = videoForgeLanguage.value;
  } catch (_) {}
  runApp(const VideoForgeApp());
}

class VideoForgeApp extends StatelessWidget {
  const VideoForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFB5F36D);
    const background = Color(0xFF10110F);
    const surface = Color(0xFF1A1C18);
    const border = Color(0xFF30342B);

    return MaterialApp(
      title: 'VideoForge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          onPrimary: Color(0xFF15180F),
          secondary: Color(0xFFB5F36D),
          surface: surface,
          onSurface: Color(0xFFF3F4EE),
          error: Color(0xFFFF8178),
        ),
        scaffoldBackgroundColor: background,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -1.1, color: Color(0xFFF3F4EE)),
          headlineSmall: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: Color(0xFFF3F4EE)),
          titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF3F4EE)),
          bodyMedium: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFFB5B9AE)),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF131510),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            foregroundColor: const Color(0xFF15180F),
            backgroundColor: accent,
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF3F4EE),
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF22251E),
          selectedColor: accent,
          side: const BorderSide(color: border),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const EncoderHomePage(),
    );
  }
}

enum ExportProfile {
  highQuality,
  balanced,
  compact,
  youtube1080,
  lossless,
  custom;

  String get title => switch (this) {
        ExportProfile.highQuality => tr('Высокое качество'),
        ExportProfile.balanced => tr('Сбалансированный'),
        ExportProfile.compact => tr('Компактный размер'),
        ExportProfile.youtube1080 => tr('YouTube 1080p'),
        ExportProfile.lossless => tr('Без потерь — новое кодирование'),
        ExportProfile.custom => tr('Мой профиль'),
      };

  String get description => switch (this) {
        ExportProfile.highQuality => tr('Меньше потерь качества, файл может быть больше.'),
        ExportProfile.balanced => tr('Рекомендуемый баланс качества и размера.'),
        ExportProfile.compact => tr('Меньше места на диске, заметнее потери качества.'),
        ExportProfile.youtube1080 => tr('MP4 до 1080p с сохранением пропорций.'),
        ExportProfile.lossless => tr('FFV1 в MKV: новое кодирование видео без потерь. Файл может быть значительно больше; не все платформы принимают этот формат.'),
        ExportProfile.custom => tr('Пользовательские настройки кодирования. Настройте CRF и скорость в конструкторе профиля.'),
      };

  int get crf => switch (this) {
        ExportProfile.highQuality => 18,
        ExportProfile.balanced => 20,
        ExportProfile.compact => 25,
        ExportProfile.youtube1080 => 20,
        ExportProfile.lossless => 0,
        ExportProfile.custom => 20,
      };

  String get preset => this == ExportProfile.highQuality ? 'slow' : 'medium';
  bool get limitTo1080p => this == ExportProfile.youtube1080;
  bool get isLossless => this == ExportProfile.lossless;
  String get outputExtension => isLossless ? 'mkv' : 'mp4';
}

enum JobStatus { queued, encoding, done, failed }

class VideoJob {
  VideoJob({required this.path, required this.bytes})
      : name = p.basename(path);

  final String path;
  final String name;
  final int bytes;

  JobStatus status = JobStatus.queued;
  String? outputPath;
  int? outputBytes;
  String? error;
  String? metadataJson;
  String publishTitle = '';
  String publishDescription = '';
  String publishTags = '';
  String publishNotes = '';
}

class EncoderHomePage extends StatefulWidget {
  const EncoderHomePage({super.key});

  @override
  State<EncoderHomePage> createState() => _EncoderHomePageState();
}

class _EncoderHomePageState extends State<EncoderHomePage> {
  static const _videoExtensions = <String>{
    'mp4',
    'mov',
    'mkv',
    'm4v',
    'avi',
    'webm',
  };

  final List<VideoJob> _jobs = <VideoJob>[];
  final Set<String> _selectedJobPaths = <String>{};

  Directory? _outputDirectory;
  bool _isPreparing = true;
  bool _isEncoding = false;
  bool _isDragging = false;
  bool _cancelRequested = false;
  int? _activeSessionId;
  int _currentJob = 0;
  int _currentTotal = 0;
  ExportProfile _profile = ExportProfile.balanced;
  double? _currentProgress;
  double _currentMediaSeconds = 0;
  double _currentDurationSeconds = 0;
  double _currentSpeed = 0;
  int _customCrf = 20;
  String _customPreset = 'medium';
  final List<String> _diagnosticLog = <String>[];
  final List<Map<String, Object?>> _exportHistory = <Map<String, Object?>>[];

  String _status = 'Подготавливаем папку для результатов…';
  String? _initializationError;

  static const _prefOutputDirectory = 'videoforge.outputDirectory';
  static const _prefProfile = 'videoforge.exportProfile';
  static const _prefQueue = 'videoforge.queue';
  static const _prefCustomCrf = 'videoforge.customCrf';
  static const _prefCustomPreset = 'videoforge.customPreset';
  static const _prefHistory = 'videoforge.exportHistory';
  SharedPreferences? _preferences;
  VideoForgeLicensing? _licensing;

  @override
  void initState() {
    super.initState();
    _prepareOutputDirectory();
  }

  Future<void> _prepareOutputDirectory() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      _licensing = VideoForgeLicensing(_preferences!);
      await _licensing!.initialize();
      _customCrf = _preferences?.getInt(_prefCustomCrf) ?? 20;
      _customPreset = _preferences?.getString(_prefCustomPreset) ?? 'medium';
      final savedProfile = _preferences?.getString(_prefProfile);
      if (savedProfile != null) {
        _profile = ExportProfile.values.firstWhere(
          (profile) => profile.name == savedProfile,
          orElse: () => ExportProfile.balanced,
        );
      }
      final savedHistory = _preferences?.getString(_prefHistory);
      if (savedHistory != null && savedHistory.isNotEmpty) {
        try {
          final decodedHistory = jsonDecode(savedHistory);
          if (decodedHistory is List) {
            _exportHistory.addAll(decodedHistory.whereType<Map>().map((item) => Map<String, Object?>.from(item)));
          }
        } catch (_) { /* Ignore corrupted history without blocking startup. */ }
      }
      final savedQueue = _preferences?.getString(_prefQueue);
      if (savedQueue != null && savedQueue.isNotEmpty) {
        _restoreQueue(savedQueue);
      }
      final savedOutput = _preferences?.getString(_prefOutputDirectory);
      final resolvedDefault = await _resolveOutputDirectory();
      final savedPath = savedOutput?.trim();
      final isLegacyDefault = savedPath != null && savedPath.isNotEmpty && (
        (Platform.isWindows && savedPath.replaceAll('/', '\\').toLowerCase().endsWith('videos\\processed_new')) ||
        (Platform.isMacOS && savedPath.replaceAll('\\', '/').toLowerCase().endsWith('movies/processed_new')) ||
        ((Platform.isAndroid || Platform.isIOS) && savedPath.replaceAll('\\', '/').toLowerCase().endsWith('/processed_new'))
      );
      final directory = (Platform.isAndroid || Platform.isIOS)
          ? resolvedDefault
          : savedPath != null && savedPath.isNotEmpty && !isLegacyDefault
              ? Directory(savedPath)
              : resolvedDefault;
      await directory.create(recursive: true);

      if (!mounted) return;

      setState(() {
        _outputDirectory = directory;
        _isPreparing = false;
        _status = _jobs.isEmpty
            ? 'Готово к работе'
            : 'Восстановлена очередь: ${_jobs.length} файл(ов)';
      });
      await _validateRestoredQueue();
      await _persistState();
    } catch (error) {
      try {
        final documents = await getApplicationDocumentsDirectory();
        final fallback = Directory(
          p.join(documents.path, 'Processed_New'),
        );

        await fallback.create(recursive: true);

        if (!mounted) return;

        setState(() {
          _outputDirectory = fallback;
          _isPreparing = false;
          _status = _jobs.isEmpty
              ? 'Готово к работе'
              : 'Восстановлена очередь: ${_jobs.length} файл(ов)';
          _initializationError =
              'Основная папка недоступна. Используется папка приложения.';
        });
        await _validateRestoredQueue();
        await _persistState();
      } catch (fallbackError) {
        if (!mounted) return;

        setState(() {
          _isPreparing = false;
          _initializationError =
              'Не удалось создать папку результатов: $fallbackError';
          _status = 'Требуется доступ к хранилищу';
        });
      }
    }
  }

  Future<void> _validateRestoredQueue() async {
    var changed = false;
    for (final job in _jobs) {
      final sourceExists = await File(job.path).exists();
      if (job.status == JobStatus.done) {
        final outputExists = job.outputPath != null &&
            await File(job.outputPath!).exists();
        if (!outputExists) {
          job.status = sourceExists ? JobStatus.queued : JobStatus.failed;
          job.error = sourceExists
              ? 'Готовый файл больше не найден. Задание можно выполнить повторно.'
              : 'Исходный файл недоступен. Выберите его заново.';
          changed = true;
        }
      } else if (!sourceExists) {
        job.status = JobStatus.failed;
        job.error = 'Исходный файл недоступен. Проверьте путь и права доступа.';
        changed = true;
      }
    }
    if (changed && mounted) {
      setState(() {
        _status = 'Очередь восстановлена; некоторые файлы требуют проверки';
      });
    }
  }

  void _restoreQueue(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return;
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final path = entry['path'];
        final bytes = entry['bytes'];
        if (path is! String || path.isEmpty || bytes is! num) continue;
        final job = VideoJob(path: path, bytes: bytes.toInt());
        final savedStatus = entry['status'];
        // Interrupted encodes are safe to retry; never resume a partial output.
        job.status = savedStatus == 'done' && entry['outputPath'] is String
            ? JobStatus.done
            : savedStatus == 'failed'
                ? JobStatus.failed
                : JobStatus.queued;
        job.outputPath = entry['outputPath'] is String
            ? entry['outputPath'] as String
            : null;
        job.outputBytes = entry['outputBytes'] is num
            ? (entry['outputBytes'] as num).toInt()
            : null;
        job.error = entry['error'] is String ? entry['error'] as String : null;
        job.metadataJson = entry['metadataJson'] is String ? entry['metadataJson'] as String : null;
        job.publishTitle = entry['publishTitle'] is String ? entry['publishTitle'] as String : '';
        job.publishDescription = entry['publishDescription'] is String ? entry['publishDescription'] as String : '';
        job.publishTags = entry['publishTags'] is String ? entry['publishTags'] as String : '';
        job.publishNotes = entry['publishNotes'] is String ? entry['publishNotes'] as String : '';
        _jobs.add(job);
      }
    } catch (_) {
      // A corrupt saved queue must not prevent the app from opening.
    }
  }

  Future<void> _persistState() async {
    try {
      final prefs = _preferences;
      if (prefs == null) {
        debugPrint('VideoForge: preferences are not initialized; skipping state persistence.');
        return;
      }
      await prefs.setString(_prefProfile, _profile.name);
      await prefs.setInt(_prefCustomCrf, _customCrf);
      await prefs.setString(_prefCustomPreset, _customPreset);
      final output = _outputDirectory;
      if (output != null) await prefs.setString(_prefOutputDirectory, output.path);
      final queue = _jobs.map((job) => <String, Object?>{
        'path': job.path,
        'bytes': job.bytes,
        'status': job.status.name == 'encoding' ? 'queued' : job.status.name,
        'outputPath': job.outputPath,
        'outputBytes': job.outputBytes,
        'error': job.error,
        'metadataJson': job.metadataJson,
        'publishTitle': job.publishTitle,
        'publishDescription': job.publishDescription,
        'publishTags': job.publishTags,
        'publishNotes': job.publishNotes,
      }).toList(growable: false);
      await prefs.setString(_prefQueue, jsonEncode(queue));
      await prefs.setString(_prefHistory, jsonEncode(_exportHistory.take(500).toList()));
    } catch (error, stackTrace) {
      debugPrint('VideoForge: failed to persist settings: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showMessage('Не удалось сохранить настройки: $error');
    }
  }

  Future<void> _chooseOutputDirectory() async {
    if (_isEncoding || _isPreparing) return;
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      _showMessage('Выбор произвольной папки доступен в настольной версии. На мобильном устройстве используется папка приложения; готовое видео можно сохранить через «Поделиться».');
      return;
    }
    try {
      final selectedPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Выберите папку для готовых видео',
      );
      if (selectedPath == null || selectedPath.trim().isEmpty) return;
      final selected = Directory(selectedPath);
      await selected.create(recursive: true);
      // Verify that the selected folder is writable before saving it.
      final probe = File(p.join(selected.path, '.videoforge_write_test'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      if (!mounted) return;
      setState(() {
        _outputDirectory = selected;
        _status = 'Папка результата изменена';
      });
      await _persistState();
      _showMessage(tr('Папка результата сохранена.'));
    } catch (error) {
      if (mounted) {
        _showMessage('Не удалось выбрать эту папку. Проверьте права доступа: $error');
      }
    }
  }

  Future<int?> _availableBytes(Directory directory) async {
    // Disk-space probing is available through native shell tools on desktop.
    // Mobile platforms do not expose a portable free-space API in this app.
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final result = await Process.run('df', <String>['-Pk', directory.path]);
        if (result.exitCode != 0) return null;
        final lines = result.stdout.toString().trim().split('\n');
        if (lines.length < 2) return null;
        final fields = lines.last.trim().split(RegExp(r'\s+'));
        if (fields.length < 4) return null;
        return int.parse(fields[3]) * 1024;
      }
      if (Platform.isWindows) {
        final root = p.rootPrefix(directory.path);
        if (root.isEmpty) return null;
        final drive = root.replaceAll(RegExp(r'[:\\/]'), '');
        final result = await Process.run('powershell.exe', <String>[
          '-NoProfile', '-Command', "(Get-PSDrive -Name '$drive').Free",
        ]);
        if (result.exitCode != 0) return null;
        return int.tryParse(result.stdout.toString().trim());
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<bool> _checkFreeSpace(List<VideoJob> pending) async {
    final directory = _outputDirectory;
    if (directory == null) return false;
    final available = await _availableBytes(directory);
    if (available == null) {
      if (mounted && (Platform.isAndroid || Platform.isIOS)) {
        _showMessage(tr('Автоматическая проверка свободного места недоступна на этом устройстве.'));
      }
      return true; // Unknown is a warning, not a hard block.
    }
    final inputBytes = pending.fold<int>(0, (sum, job) => sum + job.bytes);
    final estimated = inputBytes * (_profile.isLossless ? 4 : 2) + 256 * 1024 * 1024;
    if (available < estimated) {
      final availableLabel = _formatBytes(available);
      final requiredLabel = _formatBytes(estimated);
      if (mounted) {
        _showMessage('Может не хватить места: свободно $availableLabel, ориентировочно нужно до $requiredLabel. Освободите место или выберите другую папку.');
      }
      return false;
    }
    return true;
  }

  Future<Directory> _resolveOutputDirectory() async {
    if (Platform.isWindows) {
      final dDrive = Directory(r'D:\VideoForge');
      try {
        if (await Directory(r'D:\').exists()) return dDrive;
      } catch (_) {}
      final home = Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) {
        return Directory(p.join(home, 'Videos', 'VideoForge'));
      }
    }

    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory(p.join(home, 'Downloads', 'VideoForge'));
      }
    }

    // Android stores a working copy inside the app sandbox; after encoding,
    // the finished video is copied into the public media gallery.
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'VideoForge'));
  }

  Future<void> _saveToAndroidGallery(String path) async {
    if (!Platform.isAndroid) return;
    try {
      var hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) hasAccess = await Gal.requestAccess(toAlbum: true);
      if (!hasAccess) {
        _showMessage('Видео обработано, но нет разрешения на сохранение в галерею. Разрешите доступ к фото и видео.');
        return;
      }
      await Gal.putVideo(path, album: 'VideoForge');
      _diagnosticLog.add('${DateTime.now().toIso8601String()} GALLERY: сохранено ${p.basename(path)}');
    } catch (error) {
      _diagnosticLog.add('${DateTime.now().toIso8601String()} GALLERY ERROR: $error');
      if (mounted) _showMessage('Видео обработано, но не удалось сохранить его в галерею: $error');
    }
  }

  
  
  Future<void> _pickVideos() async {
    if (_isEncoding) return;

    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _videoExtensions.toList(),
      );

      if (!mounted || picked.isEmpty) return;
      await _addVideoPaths(picked.map((item) => item.path).whereType<String>());
    } catch (error) {
      if (mounted) {
        _showMessage('Не удалось выбрать видео: $error');
      }
    }
  }

  Future<void> _addVideoPaths(Iterable<String> paths) async {
    if (_isEncoding) {
      _showMessage(tr('Дождитесь завершения кодирования перед добавлением файлов.'));
      return;
    }

    final pathList = paths.toList(growable: false);
    final existingPaths = _jobs.map((job) => _pathKey(job.path)).toSet();
    final added = <VideoJob>[];
    var unavailableCount = 0;
    var unsupportedCount = 0;

    for (final rawPath in pathList) {
      final filePath = rawPath.trim();
      if (filePath.isEmpty) {
        unavailableCount++;
        continue;
      }

      final extension = p.extension(filePath).replaceFirst('.', '').toLowerCase();
      if (!_videoExtensions.contains(extension)) {
        unsupportedCount++;
        continue;
      }

      final key = _pathKey(filePath);
      if (existingPaths.contains(key)) continue;

      try {
        final file = File(filePath);
        if (!await file.exists()) {
          unavailableCount++;
          continue;
        }
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file) {
          unsupportedCount++;
          continue;
        }

        existingPaths.add(key);
        added.add(VideoJob(path: file.absolute.path, bytes: stat.size));
      } catch (_) {
        unavailableCount++;
      }
    }

    if (!mounted) return;

    setState(() {
      _jobs.addAll(added);
      _status = added.isEmpty
          ? (_jobs.isEmpty ? 'Выберите или перетащите видеофайлы' : 'Новых файлов не добавлено')
          : 'Добавлено файлов: ${added.length}';
    });

    if (added.isNotEmpty) await _persistState();

    if (unavailableCount > 0) {
      _showMessage('$unavailableCount файл(ов) недоступны. Проверьте путь и права доступа.');
    } else if (unsupportedCount > 0 && added.isEmpty) {
      _showMessage(tr('Поддерживаются MP4, MOV, MKV, M4V, AVI и WEBM.'));
    } else if (added.isEmpty && pathList.isNotEmpty) {
      _showMessage(tr('Эти видео уже есть в очереди.'));
    }
  }

  String _pathKey(String path) {
    final normalized = p.normalize(p.absolute(path));
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }


  Future<void> _encodeAll() async {
    if (_isEncoding || _outputDirectory == null) return;
    if (!await _ensureLicense()) return;

    final pending = _jobs
        .where(
          (job) =>
              job.status == JobStatus.queued ||
              job.status == JobStatus.failed,
        )
        .toList(growable: false);

    if (pending.isEmpty) {
      _showMessage(tr('Сначала выберите видео для кодирования.'));
      return;
    }
    if (!await _checkFreeSpace(pending)) return;

    setState(() {
      _isEncoding = true;
      _cancelRequested = false;
      _activeSessionId = null;
      _currentProgress = null;
      _currentMediaSeconds = 0;
      _currentDurationSeconds = 0;
      _currentSpeed = 0;
      _currentJob = 0;
      _currentTotal = pending.length;
      _status = 'Запускаем кодирование…';

      for (final job in pending) {
        job.error = null;
      }
    });
    await _persistState();

    var completed = 0;
    var failed = 0;

    try {
      for (var index = 0; index < pending.length; index++) {
        if (!mounted || _cancelRequested) break;

        final job = pending[index];
        String? outputPath;

        setState(() {
          _currentJob = index + 1;
          job.status = JobStatus.encoding;
          _currentProgress = null;
          _currentMediaSeconds = 0;
          _currentDurationSeconds = 0;
          _currentSpeed = 0;
          _status =
              'Кодирование ${index + 1} из ${pending.length}: ${job.name}';
        });

        try {
          outputPath = await _uniqueOutputPath(job.name);

          final durationSeconds = await _getMediaDuration(job.path);
          if (!mounted) return;
          setState(() => _currentDurationSeconds = durationSeconds);

          final result = await _runFfmpeg(
            job.path,
            outputPath,
            _profile,
            durationSeconds,
          );
          _activeSessionId = null;

          if (!mounted) return;

          if (result.success) {
            final outputFile = File(outputPath);
            if (!await outputFile.exists()) {
              throw StateError('FFmpeg сообщил об успехе, но выходной файл не найден.');
            }
            final outputBytes = await outputFile.length();
            if (outputBytes <= 0) {
              throw StateError('Выходной файл пуст. Экспорт не прошёл проверку.');
            }
            final verified = await _probeJson(outputPath);
            if (verified == null) {
              throw StateError('Готовый файл создан, но FFprobe не смог прочитать его структуру. Файл удалён, чтобы не считать непроверенный результат успешным.');
            }
            final outputDuration = await _getMediaDuration(outputPath);
            if (durationSeconds > 0 && outputDuration > 0) {
              final durationDelta = (durationSeconds - outputDuration).abs();
              final allowedDelta = durationSeconds > 100 ? 2.0 : durationSeconds * 0.02;
              if (durationDelta > allowedDelta) {
                _diagnosticLog.add('${DateTime.now().toIso8601String()} WARNING: длительность результата отличается на ${durationDelta.toStringAsFixed(2)} сек. для ${job.name}');
              }
            }
            await _saveToAndroidGallery(outputPath);
            final exportedAt = DateTime.now().toIso8601String();
            _diagnosticLog.add('$exportedAt VERIFIED: ${job.name} -> ${p.basename(outputPath)} (${_formatBytes(outputBytes)}); выходной файл существует, не пустой и читается FFprobe.');
            _exportHistory.insert(0, <String, Object?>{'date': exportedAt, 'source': job.path, 'sourceName': job.name, 'output': outputPath, 'sourceBytes': job.bytes, 'outputBytes': outputBytes, 'profile': _profile.name});
            if (_exportHistory.length > 500) _exportHistory.removeRange(500, _exportHistory.length);
            setState(() {
              job.status = JobStatus.done;
              job.outputPath = outputPath;
              job.outputBytes = outputBytes;
              if (verified != null) job.metadataJson = verified;
              job.error = null;
            });
            completed++;
            await _persistState();
          } else {
            await _deleteIfExists(outputPath);
            if (_cancelRequested) {
              setState(() {
                job.status = JobStatus.queued;
                job.error = null;
              });
            } else {
              _diagnosticLog.add('${DateTime.now().toIso8601String()} ERROR: ${job.name}: ${result.message ?? 'Неизвестная ошибка FFmpeg.'}');
              setState(() {
                job.status = JobStatus.failed;
                job.error = result.message ?? 'Неизвестная ошибка FFmpeg.';
              });
              failed++;
            }
            await _persistState();
          }
        } catch (error) {
          _activeSessionId = null;
          if (outputPath != null) {
            await _deleteIfExists(outputPath);
          }

          if (!mounted) return;

          if (_cancelRequested) {
            setState(() {
              job.status = JobStatus.queued;
              job.error = null;
            });
          } else {
            _diagnosticLog.add('${DateTime.now().toIso8601String()} ERROR: ${job.name}: $error');
            setState(() {
              job.status = JobStatus.failed;
              job.error = error.toString();
            });
            failed++;
          }
          await _persistState();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEncoding = false;
          _activeSessionId = null;
          _status = _cancelRequested
              ? 'Обработка остановлена. Готово: $completed; оставшиеся файлы в очереди.'
              : failed == 0
                  ? 'Готово! Успешно обработано: $completed'
                  : 'Завершено: $completed успешно, ошибок: $failed';
        });
        await _persistState();
      }
    }

    if (!mounted) return;

    _showMessage(
      _cancelRequested
          ? 'Обработка отменена. Незавершённые видео остались в очереди.'
          : failed == 0
              ? 'Готово! Файлы сохранены в Processed_New.'
              : 'Обработка завершена. Успешно: $completed, с ошибкой: $failed.',
    );
  }

  Future<void> _createTestClip() async {
    if (!await _ensureLicense()) return;
    if (_isEncoding || _jobs.isEmpty || _outputDirectory == null) return;
    final availableJobs = _jobs.where((job) => File(job.path).existsSync()).toList();
    if (availableJobs.isEmpty) {
      _showMessage(tr('В очереди нет доступных исходных видео.'));
      return;
    }
    VideoJob selectedJob = availableJobs.first;
    ExportProfile selectedProfile = _profile;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('Тестовый фрагмент')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(tr('Сначала обработать первые 20 секунд, чтобы проверить настройки и примерный размер файла.')),
              SizedBox(height: 16),
              DropdownButtonFormField<VideoJob>(
                value: selectedJob,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('Исходное видео')),
                items: availableJobs.map((job) => DropdownMenuItem<VideoJob>(value: job, child: Text(job.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (job) { if (job != null) setDialogState(() => selectedJob = job); },
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<ExportProfile>(
                value: selectedProfile,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('Профиль')),
                items: ExportProfile.values.map((profile) => DropdownMenuItem<ExportProfile>(value: profile, child: Text(profile.title, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (profile) { if (profile != null) setDialogState(() => selectedProfile = profile); },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('Отмена'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(tr('Создать тест'))),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final oldProfile = _profile;
    setState(() {
      _profile = selectedProfile;
      _isEncoding = true;
      _cancelRequested = false;
      _currentJob = 1;
      _currentTotal = 1;
      _currentProgress = null;
      _currentDurationSeconds = 20;
      _currentMediaSeconds = 0;
      _currentSpeed = 0;
      _status = 'Создаём тестовый фрагмент: ${selectedJob.name}';
    });
    String? outputPath;
    try {
      final base = '${p.basenameWithoutExtension(selectedJob.name)}_test20s';
      final testOutputPath = await _uniqueOutputPathForProfile(base, selectedProfile);
      outputPath = testOutputPath;
      final sourceDuration = await _getMediaDuration(selectedJob.path);
      final double sampleDuration = (sourceDuration > 0 ? (sourceDuration < 20 ? sourceDuration : 20) : 20.0).toDouble();
      final result = await _runFfmpeg(
        selectedJob.path,
        testOutputPath,
        selectedProfile,
        sampleDuration,
        maxDurationSeconds: 20,
      );
      _activeSessionId = null;
      if (!result.success) throw StateError(result.message ?? 'Не удалось создать тестовый фрагмент.');
      final file = File(testOutputPath);
      if (!await file.exists() || await file.length() == 0 || await _probeJson(testOutputPath) == null) {
        throw StateError('Тестовый файл не прошёл проверку.');
      }
      final size = await file.length();
      _diagnosticLog.add('${DateTime.now().toIso8601String()} TEST CLIP: ${selectedJob.name}; profile=${selectedProfile.name}; output=$testOutputPath; bytes=$size');
      if (!mounted) return;
      setState(() => _status = 'Тестовый фрагмент готов: ${p.basename(testOutputPath)}');
      await _persistState();
      _showMessage('Тестовый фрагмент готов (${_formatBytes(size)}): ${p.basename(testOutputPath)}');
    } catch (error) {
      if (outputPath != null) await _deleteIfExists(outputPath);
      _diagnosticLog.add('${DateTime.now().toIso8601String()} TEST CLIP ERROR: $error');
      if (mounted) _showMessage('Не удалось создать тестовый фрагмент: $error');
    } finally {
      _activeSessionId = null;
      if (mounted) {
        setState(() {
          _isEncoding = false;
          _profile = oldProfile;
          _currentProgress = null;
          _status = 'Готово к работе';
        });
      }
    }
  }

  Future<void> _compareProfilesOnTestClip() async {
    if (!await _ensureLicense()) return;
    if (_isEncoding || _jobs.isEmpty || _outputDirectory == null) return;
    final availableJobs = _jobs.where((job) => File(job.path).existsSync()).toList();
    if (availableJobs.isEmpty) {
      _showMessage(tr('В очереди нет доступных исходных видео.'));
      return;
    }

    VideoJob selectedJob = availableJobs.first;
    final selectedProfiles = <ExportProfile>{_profile, ExportProfile.highQuality, ExportProfile.compact};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('Сравнить профили')),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(tr('Один и тот же 20-секундный фрагмент будет обработан каждым выбранным профилем. Сравнение показывает размер и время, но не гарантирует одинаковое визуальное качество.')),
                  SizedBox(height: 14),
                  DropdownButtonFormField<VideoJob>(
                    value: selectedJob,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: tr('Исходное видео')),
                    items: availableJobs.map((job) => DropdownMenuItem<VideoJob>(value: job, child: Text(job.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (job) { if (job != null) setDialogState(() => selectedJob = job); },
                  ),
                  SizedBox(height: 12),
                  Text(tr('Профили для сравнения'), style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  ...ExportProfile.values.map((profile) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selectedProfiles.contains(profile),
                    title: Text(profile.title),
                    subtitle: Text(profile.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onChanged: (checked) => setDialogState(() {
                      if (checked == true) {
                        selectedProfiles.add(profile);
                      } else if (selectedProfiles.length > 1) {
                        selectedProfiles.remove(profile);
                      }
                    }),
                  )),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('Отмена'))),
            FilledButton(onPressed: selectedProfiles.isEmpty ? null : () => Navigator.pop(dialogContext, true), child: Text(tr('Начать сравнение'))),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted || selectedProfiles.isEmpty) return;

    final oldProfile = _profile;
    final profiles = ExportProfile.values.where(selectedProfiles.contains).toList();
    final results = <({ExportProfile profile, String path, int bytes, Duration elapsed})>[];
    final errors = <String>[];
    final sourceDuration = await _getMediaDuration(selectedJob.path);
    final double sampleDuration = (sourceDuration > 0 ? (sourceDuration < 20 ? sourceDuration : 20) : 20.0).toDouble();

    setState(() {
      _isEncoding = true;
      _cancelRequested = false;
      _currentJob = 0;
      _currentTotal = profiles.length;
      _currentProgress = null;
      _currentDurationSeconds = sampleDuration;
      _currentMediaSeconds = 0;
      _currentSpeed = 0;
      _status = 'Сравниваем ${profiles.length} профиля на одном фрагменте';
    });

    try {
      for (var i = 0; i < profiles.length; i++) {
        if (_cancelRequested) break;
        final profile = profiles[i];
        if (mounted) {
          setState(() {
            _profile = profile;
            _currentJob = i + 1;
            _currentProgress = null;
            _currentMediaSeconds = 0;
            _currentSpeed = 0;
            _status = 'Тест ${i + 1}/${profiles.length}: ${profile.title}';
          });
        }
        String? outputPath;
        final stopwatch = Stopwatch()..start();
        try {
          final base = '${p.basenameWithoutExtension(selectedJob.name)}_compare_${profile.name}_20s';
          outputPath = await _uniqueOutputPathForProfile(base, profile);
          final result = await _runFfmpeg(selectedJob.path, outputPath, profile, sampleDuration, maxDurationSeconds: 20);
          _activeSessionId = null;
          if (!result.success) throw StateError(result.message ?? 'Кодирование не завершено.');
          final output = File(outputPath);
          if (!await output.exists() || await output.length() == 0 || await _probeJson(outputPath) == null) {
            throw StateError('Файл не прошёл проверку FFprobe.');
          }
          stopwatch.stop();
          final bytes = await output.length();
          results.add((profile: profile, path: outputPath, bytes: bytes, elapsed: stopwatch.elapsed));
          _diagnosticLog.add('${DateTime.now().toIso8601String()} PROFILE COMPARISON: ${selectedJob.name}; profile=${profile.name}; bytes=$bytes; elapsedMs=${stopwatch.elapsedMilliseconds}; output=$outputPath');
        } catch (error) {
          if (outputPath != null) await _deleteIfExists(outputPath);
          errors.add('${profile.title}: $error');
          _diagnosticLog.add('${DateTime.now().toIso8601String()} PROFILE COMPARISON ERROR: ${profile.name}; $error');
        }
      }

      if (mounted) {
        setState(() => _status = _cancelRequested ? 'Сравнение остановлено' : 'Сравнение профилей завершено');
      }
      await _persistState();
      if (!mounted) return;
      final report = <String>[
        if (results.isNotEmpty) 'Успешные тесты:',
        ...results.map((r) => '${r.profile.title}\nРазмер: ${_formatBytes(r.bytes)} · Время: ${r.elapsed.inSeconds} с\n${r.path}'),
        if (errors.isNotEmpty) '\nОшибки:',
        ...errors,
        if (_cancelRequested) '\nСравнение было остановлено пользователем.',
        if (results.isEmpty && errors.isEmpty) 'Тесты не были завершены.',
      ];
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('Результаты сравнения')),
          content: SizedBox(width: 480, child: SingleChildScrollView(child: SelectableText(report.join('\n\n')))),
          actions: <Widget>[TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('Закрыть')))],
        ),
      );
    } finally {
      _activeSessionId = null;
      if (mounted) {
        setState(() {
          _isEncoding = false;
          _profile = oldProfile;
          _currentProgress = null;
          _status = 'Готово к работе';
        });
      }
    }
  }

  Future<String> _uniqueOutputPathForProfile(String baseName, ExportProfile profile) async {
    final directory = _outputDirectory;
    if (directory == null) throw StateError('Папка результатов ещё не готова.');
    await directory.create(recursive: true);
    final safeBase = baseName.trim().isEmpty ? 'video_test20s' : baseName;
    final extension = profile.outputExtension;
    var candidate = p.join(directory.path, '$safeBase.$extension');
    var suffix = 2;
    while (await File(candidate).exists()) {
      candidate = p.join(directory.path, '${safeBase}_$suffix.$extension');
      suffix++;
    }
    return candidate;
  }

  Future<void> _recommendProfile() async {
    if (_jobs.isEmpty) {
      _showMessage(tr('Сначала добавьте видео, чтобы подобрать профиль.'));
      return;
    }
    final job = _jobs.firstWhere((item) => File(item.path).existsSync(), orElse: () => _jobs.first);
    ExportProfile recommended;
    String reason;
    if (job.bytes >= 1024 * 1024 * 1024) {
      recommended = ExportProfile.compact;
      reason = 'Исходный файл больше 1 ГБ. Компактный профиль может сократить размер, но повторное кодирование H.264 является кодированием с потерями.';
    } else if (job.metadataJson?.contains('3840') == true || job.metadataJson?.contains('2160') == true) {
      recommended = ExportProfile.highQuality;
      reason = 'В метаданных обнаружено разрешение 4K. Высокое качество сохраняет исходное разрешение, если не выбран профиль с ограничением размера кадра.';
    } else {
      recommended = ExportProfile.balanced;
      reason = 'Для обычной конвертации это отправная точка. Если приоритет — архивное сохранение, выберите FFV1 без потерь; для максимальной совместимости обычно удобнее H.264/MP4.';
    }
    final apply = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(tr('Рекомендация VideoForge')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(tr('Для «${job.name}» предлагается профиль «${recommended.title}».'), style: const TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 10),
        Text(reason),
        SizedBox(height: 10),
        Text(tr('Рекомендация основана на доступных метаданных и размере файла, а не гарантирует лучший результат для любого видео.'), style: TextStyle(fontSize: 12, color: Colors.white60)),
      ]),
      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Оставить как есть'))), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Применить профиль')))],
    ));
    if (apply == true && mounted) {
      setState(() => _profile = recommended);
      await _persistState();
      _showMessage('Выбран профиль: ${recommended.title}');
    }
  }

  Future<String?> _probeJson(String path) async {
    try {
      final probe = await FFprobeKit.getMediaInformation(path);
      final info = await probe.getMediaInformation();
      if (info == null) return null;
      final dynamic raw = info.getAllProperties();
      return const JsonEncoder.withIndent('  ').convert(raw ?? <String, Object?>{'filename': path, 'duration': info.getDuration(), 'bitrate': info.getBitrate(), 'format': info.getFormat()});
    } catch (error) {
      _diagnosticLog.add('${DateTime.now().toIso8601String()} FFprobe error for $path: $error');
      return null;
    }
  }

  Future<void> _analyzeQueuedVideos() async {
    if (_jobs.isEmpty) return;
    var analyzed = 0;
    for (final job in _jobs) {
      final result = await _probeJson(job.path);
      if (result != null) {
        job.metadataJson = result;
        analyzed++;
      } else {
        _diagnosticLog.add('${DateTime.now().toIso8601String()} Metadata unavailable: ${job.path}');
      }
    }
    await _persistState();
    if (!mounted) return;
    setState(() {});
    _showMessage('Анализ завершён: $analyzed из ${_jobs.length} файлов. Нажмите на значок сведений у файла для просмотра.');
  }

  Future<void> _configureCustomProfile() async {
    var crf = _customCrf.toDouble();
    var preset = _customPreset;
    final result = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(tr('Конструктор профиля')),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(tr('CRF: ниже — выше качество и обычно больше размер. Доступный диапазон этого профиля: 0–35.')),
        Slider(value: crf, min: 0, max: 35, divisions: 35, label: crf.round().toString(), onChanged: (v) => setDialogState(() => crf = v)),
        Text('CRF ${crf.round()}'),
        SizedBox(height: 12),
        Text(tr('Скорость кодирования')),
        SizedBox(height: 6),
        DropdownButtonFormField<String>(value: preset, items: <DropdownMenuItem<String>>[
          DropdownMenuItem(value: 'ultrafast', child: Text(tr('Очень быстро'))), DropdownMenuItem(value: 'fast', child: Text(tr('Быстро'))), DropdownMenuItem(value: 'medium', child: Text(tr('Сбалансировано'))), DropdownMenuItem(value: 'slow', child: Text(tr('Медленно, эффективнее'))),
        ], onChanged: (v) { if (v != null) setDialogState(() => preset = v); }),
        SizedBox(height: 8),
        Text(tr('Этот профиль использует H.264 в MP4. CRF 0 зависит от сборки кодека и не гарантируется как lossless; для строгого режима без потерь выбирайте FFV1.'), style: TextStyle(fontSize: 12)),
      ])),
      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Отмена'))), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Сохранить профиль')))],
    )));
    if (result != true || !mounted) return;
    setState(() { _customCrf = crf.round(); _customPreset = preset; _profile = ExportProfile.custom; });
    await _persistState();
    _showMessage(tr('Пользовательский профиль сохранён.'));
  }

  Future<void> _showVideoDetails(VideoJob job) async {
    final data = job.metadataJson ?? await _probeJson(job.path);
    if (data != null) job.metadataJson = data;
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(job.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: SelectableText(data ?? 'Не удалось прочитать метаданные видео.\nПроверьте доступ к файлу и поддержку FFprobe.', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)))),
      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Закрыть')))],
    ));
  }

  Future<void> _openPublishingManager() async {
    if (_jobs.isEmpty) return;
    var selected = _jobs.first;
    final title = TextEditingController(text: selected.publishTitle);
    final description = TextEditingController(text: selected.publishDescription);
    final tags = TextEditingController(text: selected.publishTags);
    final notes = TextEditingController(text: selected.publishNotes);
    await showDialog<void>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(tr('Менеджер публикаций')),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        DropdownButtonFormField<VideoJob>(value: selected, isExpanded: true, decoration: InputDecoration(labelText: tr('Видео')), items: _jobs.map((j) => DropdownMenuItem(value: j, child: Text(j.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (job) { if (job == null) return; setDialogState(() { selected = job; title.text = job.publishTitle; description.text = job.publishDescription; tags.text = job.publishTags; notes.text = job.publishNotes; }); }),
        SizedBox(height: 10), TextField(controller: title, decoration: InputDecoration(labelText: tr('Название публикации'))),
        SizedBox(height: 10), TextField(controller: description, maxLines: 3, decoration: InputDecoration(labelText: tr('Описание'))),
        SizedBox(height: 10), TextField(controller: tags, decoration: InputDecoration(labelText: tr('Теги (через запятую)'))),
        SizedBox(height: 10), TextField(controller: notes, maxLines: 2, decoration: InputDecoration(labelText: tr('Заметки / результаты теста'))),
        SizedBox(height: 8), Text(tr('Сохраняются локально в приложении. Статистика платформ сюда автоматически не импортируется.'), style: TextStyle(fontSize: 12)),
      ]))),
      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Закрыть'))), FilledButton(onPressed: () async { selected.publishTitle = title.text; selected.publishDescription = description.text; selected.publishTags = tags.text; selected.publishNotes = notes.text; await _persistState(); if (context.mounted) Navigator.pop(context); if (mounted) _showMessage(tr('Вариант публикации сохранён.')); }, child: Text(tr('Сохранить')))],
    )));
    title.dispose(); description.dispose(); tags.dispose(); notes.dispose();
  }

  Future<void> _openHistory() async {
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(tr('История экспорта')),
      content: SizedBox(width: 600, child: _exportHistory.isEmpty ? Text(tr('История пока пуста.')) : ListView(shrinkWrap: true, children: _exportHistory.map((entry) {
        final sourceBytes = entry['sourceBytes'] is num ? (entry['sourceBytes'] as num).toInt() : 0;
        final outputBytes = entry['outputBytes'] is num ? (entry['outputBytes'] as num).toInt() : 0;
        return ListTile(
          leading: Icon(Icons.check_circle_outline, color: Color(0xFFB5F36D)),
          title: Text('${entry['sourceName'] ?? 'Видео'}', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${entry['date'] ?? ''}\n${_formatBytes(sourceBytes)} → ${_formatBytes(outputBytes)} · ${entry['profile'] ?? ''}\n${entry['output'] ?? ''}'),
          isThreeLine: true,
        );
      }).toList())),
      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Закрыть')))],
    ));
  }

  Future<File?> _extractPreviewFrame(String path) async {
    try {
      final duration = await _getMediaDuration(path);
      final seekSeconds = duration > 1 ? duration * 0.5 : 0.0;
      final temp = await getTemporaryDirectory();
      final output = File(p.join(temp.path, 'videoforge_preview_${DateTime.now().microsecondsSinceEpoch}.jpg'));
      final session = await FFmpegKit.executeWithArguments(<String>[
        '-hide_banner', '-loglevel', 'error', '-y', '-ss', seekSeconds.toStringAsFixed(3), '-i', path,
        '-frames:v', '1', '-vf', 'scale=640:-2', '-q:v', '3', output.path,
      ]);
      final code = await session.getReturnCode();
      if (ReturnCode.isSuccess(code) && await output.exists() && await output.length() > 0) return output;
      return null;
    } catch (error) {
      _diagnosticLog.add('${DateTime.now().toIso8601String()} Preview frame failed for $path: $error');
      return null;
    }
  }

  Future<void> _compareLatestOutput() async {
    final completed = _jobs.where((j) => j.status == JobStatus.done && j.outputPath != null).toList();
    if (completed.isEmpty) { _showMessage(tr('Нет готового файла для проверки.')); return; }
    final job = completed.last;
    _showMessage(tr('Подготавливаем кадры для сравнения…'));
    final sourceFrame = await _extractPreviewFrame(job.path);
    final outputFrame = await _extractPreviewFrame(job.outputPath!);
    final source = await _probeJson(job.path);
    final output = await _probeJson(job.outputPath!);
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(tr('Сравнение исходника и результата')),
      content: SizedBox(width: 760, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(job.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final vertical = constraints.maxWidth < 520;
          final sourcePane = Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(tr('ОРИГИНАЛ'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)), SizedBox(height: 6),
            if (sourceFrame != null) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(sourceFrame, fit: BoxFit.contain, width: double.infinity)) else AspectRatio(aspectRatio: 16 / 9, child: Center(child: Text(tr('Кадр недоступен')))),
            SizedBox(height: 6), Text(_formatBytes(job.bytes), style: const TextStyle(fontSize: 12)),
          ]);
          final outputPane = Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(tr('РЕЗУЛЬТАТ'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)), SizedBox(height: 6),
            if (outputFrame != null) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(outputFrame, fit: BoxFit.contain, width: double.infinity)) else AspectRatio(aspectRatio: 16 / 9, child: Center(child: Text(tr('Кадр недоступен')))),
            SizedBox(height: 6), Text(job.outputBytes == null ? 'Размер неизвестен' : _formatBytes(job.outputBytes!), style: const TextStyle(fontSize: 12)),
          ]);
          return vertical ? Column(children: <Widget>[sourcePane, SizedBox(height: 18), outputPane]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Expanded(child: sourcePane), SizedBox(width: 14), Expanded(child: outputPane)]);
        }),
        Divider(height: 24),
        Text('Изменение размера: ${_sizeChangeLabel(job).isEmpty ? 'не рассчитано' : _sizeChangeLabel(job)}'),
        SizedBox(height: 8), Text(tr('Кадры показывают только одну точку примерно в середине видео. Это визуальная проверка, а не математическое доказательство отсутствия потерь. Для FFV1 исходные декодированные кадры должны сохраняться без потерь.'), style: TextStyle(fontSize: 12)),
        ExpansionTile(title: Text(tr('Технические сведения')), children: <Widget>[
          Align(alignment: Alignment.centerLeft, child: Text(tr('Исходник'), style: TextStyle(fontWeight: FontWeight.bold))),
          SelectableText(source ?? 'Метаданные исходника недоступны.'),
          Divider(),
          Align(alignment: Alignment.centerLeft, child: Text(tr('Результат'), style: TextStyle(fontWeight: FontWeight.bold))),
          SelectableText(output ?? 'Метаданные результата недоступны.'),
        ]),
      ]))),
      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Закрыть')))],
    ));
  }

  Future<void> _exportDiagnostics() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'VideoForge_diagnostics.txt'));
      final lines = <String>[
        'VideoForge diagnostics', 'Generated: ${DateTime.now().toIso8601String()}', 'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}', 'Profile: ${_profile.name}', 'Output: ${_outputDirectory?.path ?? '(none)'}', 'Queue jobs: ${_jobs.length}', '', 'Recent events:', ..._diagnosticLog.take(500), '', 'Jobs:', ..._jobs.map((j) => '${j.status.name} | ${j.name} | ${j.path} | ${j.error ?? ''}'),
      ];
      await file.writeAsString(lines.join('\n'), flush: true);
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(title: 'VideoForge diagnostics', text: 'Диагностический отчёт VideoForge', files: <XFile>[XFile(file.path)]));
    } catch (error) {
      if (mounted) _showMessage('Не удалось подготовить отчёт: $error');
    }
  }

  Future<double> _getMediaDuration(String inputPath) async {
    try {
      final probe = await FFprobeKit.getMediaInformation(inputPath);
      final information = await probe.getMediaInformation();
      return double.tryParse(information?.getDuration() ?? '') ?? 0;
    } catch (_) {
      // If metadata cannot be read, encoding still proceeds with indeterminate progress.
      return 0;
    }
  }

  Future<({bool success, String? message})> _runFfmpeg(
    String inputPath,
    String outputPath,
    ExportProfile profile,
    double durationSeconds, {
    double? maxDurationSeconds,
  }) async {
    final completer =
        Completer<({bool success, String? message})>();

    final args = <String>[
      '-hide_banner',
      '-nostdin',
      '-y',
      '-i',
      inputPath,
      '-map',
      '0:v:0',
      '-map',
      '0:a?',
      '-map_metadata',
      '0',
      '-map_chapters',
      '0',
    ];

    if (profile.isLossless) {
      // FFV1 is a mathematically lossless video codec. MKV supports FFV1
      // and a wide range of existing audio codecs; copying audio avoids
      // introducing a new lossy audio encode.
      args.addAll([
        '-c:v', 'ffv1',
        '-level', '3',
        '-coder', '1',
        '-context', '1',
        '-c:a', 'copy',
      ]);
    } else {
      args.addAll([
        '-c:v',
        'libx264',
        '-preset',
        profile == ExportProfile.custom ? _customPreset : profile.preset,
        '-crf',
        (profile == ExportProfile.custom ? _customCrf : profile.crf).toString(),
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        '-movflags',
        '+faststart',
      ]);
    }

    if (profile.limitTo1080p) {
      args.addAll([
        '-vf',
        "scale=w='min(1920,iw)':h='min(1080,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2",
      ]);
    }
    if (maxDurationSeconds != null && maxDurationSeconds > 0) {
      args.addAll(<String>['-t', maxDurationSeconds.toStringAsFixed(2)]);
    }
    args.add(outputPath);

    try {
      final session = await FFmpegKit.executeWithArgumentsAsync(
        args,
        (session) async {
          try {
            final returnCode = await session.getReturnCode();

            if (ReturnCode.isSuccess(returnCode)) {
              if (!completer.isCompleted) {
                completer.complete((success: true, message: null));
              }
            } else {
              final output = await session.getOutput();
              final details = (output ?? '').trim();

              if (!completer.isCompleted) {
                completer.complete((
                  success: false,
                  message: details.isEmpty
                      ? 'FFmpeg завершился с кодом ${returnCode?.getValue() ?? 'неизвестно'}.'
                      : _shortError(details),
                ));
              }
            }
          } catch (error) {
            if (!completer.isCompleted) {
              completer.complete((success: false, message: error.toString()));
            }
          }
        },
        null,
        (statistics) {
          final mediaSeconds = statistics.getTime() / 1000.0;
          final speed = statistics.getSpeed();
          if (!mounted) return;
          setState(() {
            _currentMediaSeconds = mediaSeconds;
            _currentSpeed = speed;
            _currentProgress = durationSeconds > 0
                ? (mediaSeconds / durationSeconds).clamp(0.0, 1.0).toDouble()
                : null;
          });
        },
      );

      _activeSessionId = session.getSessionId();
      if (_cancelRequested && _activeSessionId != null) {
        await FFmpegKit.cancel(_activeSessionId);
      }
    } catch (error) {
      if (!completer.isCompleted) {
        completer.complete((success: false, message: error.toString()));
      }
    }

    return completer.future;
  }

  Future<void> _cancelEncoding() async {
    if (!_isEncoding || _cancelRequested) return;
    setState(() {
      _cancelRequested = true;
      _status = 'Отменяем текущий файл…';
    });

    final sessionId = _activeSessionId;
    try {
      if (sessionId != null) {
        await FFmpegKit.cancel(sessionId);
      }
    } catch (error) {
      if (mounted) _showMessage('Не удалось отменить кодирование: $error');
    }
  }

  String _shortError(String output) {
    final lines = output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty) {
      return 'Не удалось обработать видео.';
    }

    return lines.length > 3
        ? lines.skip(lines.length - 3).join('\n')
        : lines.join('\n');
  }

  Future<String> _uniqueOutputPath(String inputName) async {
    final directory = _outputDirectory;

    if (directory == null) {
      throw StateError('Папка результатов ещё не готова.');
    }

    await directory.create(recursive: true);

    final base = p.basenameWithoutExtension(inputName).trim();
    final safeBase = base.isEmpty ? 'video' : base;

    final extension = _profile.outputExtension;
    var candidate = p.join(directory.path, '$safeBase.$extension');
    var suffix = 2;

    while (await File(candidate).exists()) {
      candidate = p.join(
        directory.path,
        '${safeBase}_$suffix.$extension',
      );
      suffix++;
    }

    return candidate;
  }

  Future<void> _deleteIfExists(String path) async {
    try {
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ошибка очистки частичного файла не скрывает основную ошибку.
    }
  }

  Future<void> _shareVideo(
    String path,
    BuildContext buttonContext,
  ) async {
    try {
      final box = buttonContext.findRenderObject() as RenderBox?;

      await SharePlus.instance.share(
        ShareParams(
          title: 'VideoForge — готовое видео',
          text: 'Видео обработано в VideoForge.',
          files: <XFile>[XFile(path)],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Не удалось экспортировать файл: $error');
      }
    }
  }

  Future<void> _openOutputFolder() async {
    final directory = _outputDirectory;

    if (directory == null) return;

    try {
      if (Platform.isWindows) {
        await Process.start(
          'explorer.exe',
          <String>[directory.path],
        );
      } else if (Platform.isMacOS) {
        await Process.start(
          'open',
          <String>[directory.path],
        );
      } else {
        _showMessage(
          'Нажмите «Поделиться» у готового видео, '
          'чтобы сохранить его в Файлы или другую папку.',
        );
      }
    } catch (error) {
      _showMessage('Не удалось открыть папку: $error');
    }
  }

  void _removeJob(VideoJob job) {
    if (_isEncoding) return;
    setState(() {
      _jobs.remove(job);
      _selectedJobPaths.remove(_pathKey(job.path));
    });
    _persistState();
  }

  void _removeSelectedJobs() {
    if (_isEncoding || _selectedJobPaths.isEmpty) return;
    final count = _selectedJobPaths.length;
    setState(() {
      _jobs.removeWhere((job) => _selectedJobPaths.contains(_pathKey(job.path)));
      _selectedJobPaths.clear();
    });
    _persistState();
    _showMessage('Убрано из очереди: $count');
  }

  Future<bool> _ensureLicense() async {
    final licensing = _licensing;
    if (licensing == null) {
      _showMessage(tr('Проверка лицензии ещё не завершена.'));
      return false;
    }
    if (!licensing.isAllowed) {
      await _showLicenseDialog();
      return licensing.isAllowed;
    }
    return true;
  }

  Future<void> _showLicenseDialog() async {
    if (!mounted) return;
    final licensing = _licensing;
    if (licensing == null || !licensing.initialized) {
      _showMessage(tr('Лицензия ещё загружается. Подождите несколько секунд и повторите.'));
      return;
    }

    final controller = TextEditingController();
    final emailController = TextEditingController();
    String? errorText;
    bool checking = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screen = MediaQuery.sizeOf(context);
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            backgroundColor: const Color(0xFF1A1C18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0xFF30342B)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: screen.height * 0.82,
              ),
              child: SizedBox(
                width: screen.width - 32,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFB5F36D).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(Icons.verified_user_outlined, color: Color(0xFFB5F36D)),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(tr('Активация лицензии'),
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            tooltip: tr('Закрыть'),
                            visualDensity: VisualDensity.compact,
                            onPressed: checking ? null : () => Navigator.pop(dialogContext),
                            icon: Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        tr(licensing.status),
                        style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFFB5B9AE)),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131510),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF30342B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(tr('ID установки'), style: TextStyle(fontSize: 11, color: Color(0xFF858B7D))),
                            SizedBox(height: 4),
                            SelectableText(
                              licensing.installId ?? 'не определён',
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        enabled: !checking && !licensing.clockBlocked,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: tr('Email лицензии'),
                          hintText: 'name@example.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                          isDense: true,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: controller,
                        enabled: !checking && !licensing.clockBlocked,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.none,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: tr('Лицензионный ключ'),
                          hintText: 'VF1.…',
                          prefixIcon: Icon(Icons.key_outlined),
                          isDense: true,
                        ),
                      ),
                      if (errorText != null) ...<Widget>[
                        SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8178).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x55FF8178)),
                          ),
                          child: Text(
                            tr(errorText!),
                            style: const TextStyle(color: Color(0xFFFFA19A), fontSize: 12, height: 1.35),
                          ),
                        ),
                      ],
                      if (checking) ...<Widget>[
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 9),
                            Flexible(child: Text(tr('Выполняется проверка…'), style: TextStyle(fontSize: 12))),
                          ],
                        ),
                      ],
                      SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: checking ? null : () async {
                            FocusScope.of(context).unfocus();
                            setDialogState(() { checking = true; errorText = null; });
                            String? activationError;
                            try {
                              if (licensing.clockBlocked) {
                                await licensing.refreshTimeAndLicense(forceNetworkCheck: true);
                                if (licensing.clockBlocked) {
                                  activationError = licensing.status;
                                }
                              }
                              if (activationError == null && emailController.text.trim().isEmpty) {
                                activationError = 'Введите email, на который выпущен ключ.';
                              }
                              if (activationError == null && !emailController.text.trim().contains('@')) {
                                activationError = 'Проверьте адрес email.';
                              }
                              if (activationError == null && controller.text.trim().isEmpty) {
                                activationError = 'Введите лицензионный ключ.';
                              }
                              if (activationError == null) {
                                activationError = await licensing.activate(
                                  controller.text.trim(),
                                  emailController.text.trim(),
                                );
                              }
                            } catch (error) {
                              activationError = 'Не удалось выполнить активацию: $error';
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  checking = false;
                                  errorText = activationError;
                                });
                              }
                            }
                            if (!dialogContext.mounted) return;
                            if (activationError == null) {
                              Navigator.pop(dialogContext);
                              if (mounted) setState(() {});
                              _showMessage(tr('Лицензия успешно активирована.'));
                            } else if (mounted) {
                              setState(() {});
                            }
                          },
                          icon: checking
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(Icons.verified_rounded, size: 18),
                          label: Text(tr(checking ? 'Проверяем…' : 'Активировать')),
                        ),
                      ),
                      SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: checking ? null : () async {
                          FocusScope.of(context).unfocus();
                          setDialogState(() { checking = true; errorText = null; });
                          String? checkError;
                          try {
                            await licensing.refreshTimeAndLicense(forceNetworkCheck: true);
                            if (licensing.clockBlocked) checkError = licensing.status;
                            else checkError = 'Проверка завершена: ${licensing.status}';
                          } catch (error) {
                            checkError = 'Не удалось проверить время: $error';
                          }
                          if (!dialogContext.mounted) return;
                          setDialogState(() { checking = false; errorText = checkError; });
                          if (mounted) setState(() {});
                        },
                        icon: Icon(Icons.sync_rounded, size: 18),
                        label: Text(tr('Проверить время')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
    emailController.dispose();
    if (mounted) setState(() {});
  }

  Widget _buildLicenseCard() {
    final license = _licensing;
    final allowed = license?.isAllowed ?? false;
    final title = license == null
        ? tr('Лицензия')
        : license.isLicensed
            ? tr('Лицензия активна')
            : license.isTrialActive
                ? '${tr('Пробный период')} · ${license.trialDaysLeft} ${tr('дн.')}'
                : tr('Требуется лицензия');
    return Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: <Widget>[
      Icon(allowed ? Icons.verified_user_outlined : Icons.lock_outline_rounded, color: allowed ? const Color(0xFFB5F36D) : const Color(0xFFFF8178), size: 22),
      SizedBox(width: 10),
      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
      OutlinedButton(onPressed: _showLicenseDialog, child: Text(tr(allowed ? 'Лицензия' : 'Активировать'))),
    ])));
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} ГБ';
  }

  String _formatClock(double seconds) {
    if (!seconds.isFinite || seconds < 0) return '--:--';
    final total = seconds.round();
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final remainder = total % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
    }
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  String _sizeChangeLabel(VideoJob job) {
    final outputBytes = job.outputBytes;
    if (outputBytes == null || job.bytes <= 0) return '';
    final change = ((job.bytes - outputBytes) / job.bytes) * 100;
    if (change >= 0) return '−${change.toStringAsFixed(1)}%';
    return '+${change.abs().toStringAsFixed(1)}% к размеру';
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _jobs.where((job) => job.status == JobStatus.done).length;
    final failedCount = _jobs.where((job) => job.status == JobStatus.failed).length;
    final double? batchProgress = _currentProgress == null || _currentTotal == 0
        ? null
        : ((_currentJob - 1 + _currentProgress!) / _currentTotal).clamp(0.0, 1.0).toDouble();
    final remainingSeconds = _currentSpeed > 0 && _currentDurationSeconds > 0
        ? (_currentDurationSeconds - _currentMediaSeconds).clamp(0.0, _currentDurationSeconds) / _currentSpeed
        : null;

    return Scaffold(
      body: SafeArea(
        child: _desktopDropTarget(
          Stack(
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 820;
                    return ListView(
                      padding: EdgeInsets.fromLTRB(wide ? 28 : 12, wide ? 20 : 10, wide ? 28 : 12, wide ? 28 : 16),
                      children: <Widget>[
                        _buildHeader(),
                        SizedBox(height: wide ? 12 : 7),
                        _buildLicenseCard(),
                        SizedBox(height: wide ? 16 : 8),
                        _buildHeroCard(),
                        SizedBox(height: wide ? 16 : 8),
                        if (wide)
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Expanded(flex: 6, child: _buildProfileCard()),
                            SizedBox(width: 18),
                            Expanded(flex: 5, child: _buildOutputCard()),
                          ])
                        else ...<Widget>[
                          _buildProfileCard(),
                          SizedBox(height: 8),
                          _buildOutputCard(),
                        ],
                        SizedBox(height: wide ? 16 : 8),
                        Row(children: <Widget>[
                          Expanded(child: _metricCard('В очереди', '${_jobs.length}', Icons.video_library_outlined)),
                          SizedBox(width: 10),
                          Expanded(child: _metricCard('Готово', '$doneCount', Icons.check_circle_outline_rounded, color: const Color(0xFFB5F36D))),
                          SizedBox(width: 10),
                          Expanded(child: _metricCard('Ошибки', '$failedCount', Icons.error_outline_rounded, color: const Color(0xFFFF8178))),
                        ]),
                        SizedBox(height: 8),
                        if (Platform.isAndroid)
                          Card(
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                leading: Icon(Icons.tune_rounded, color: Color(0xFFB5F36D)),
                                title: Text(tr('Дополнительные инструменты'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                children: <Widget>[
                                  Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                                    OutlinedButton.icon(onPressed: _jobs.isEmpty ? null : _analyzeQueuedVideos, icon: Icon(Icons.manage_search_rounded, size: 17), label: Text(tr('Анализ'))),
                                    OutlinedButton.icon(onPressed: _jobs.isEmpty || _isEncoding ? null : _recommendProfile, icon: Icon(Icons.auto_awesome_outlined, size: 17), label: Text(tr('Профиль'))),
                                    OutlinedButton.icon(onPressed: _jobs.isEmpty || _isEncoding ? null : _createTestClip, icon: Icon(Icons.science_outlined, size: 17), label: Text(tr('Тест 20 с'))),
                                    OutlinedButton.icon(onPressed: _jobs.isEmpty || _isEncoding ? null : _compareProfilesOnTestClip, icon: Icon(Icons.compare_rounded, size: 17), label: Text(tr('Сравнить'))),
                                    OutlinedButton.icon(onPressed: _jobs.where((j) => j.status == JobStatus.done).isEmpty ? null : _openHistory, icon: Icon(Icons.history_rounded, size: 17), label: Text(tr('История'))),
                                    OutlinedButton.icon(onPressed: _jobs.isEmpty ? null : _openPublishingManager, icon: Icon(Icons.campaign_outlined, size: 17), label: Text(tr('Публикации'))),
                                    OutlinedButton.icon(onPressed: _jobs.where((j) => j.status == JobStatus.done).isEmpty ? null : _compareLatestOutput, icon: Icon(Icons.compare_arrows_rounded, size: 17), label: Text(tr('Результат'))),
                                  ]),
                                ],
                              ),
                            ),
                          )
                        else
                          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                            OutlinedButton.icon(onPressed: _jobs.isEmpty ? null : _analyzeQueuedVideos, icon: Icon(Icons.manage_search_rounded), label: Text(tr('Анализ видео'))),
                            OutlinedButton.icon(onPressed: _jobs.isEmpty || _isEncoding ? null : _recommendProfile, icon: Icon(Icons.auto_awesome_outlined), label: Text(tr('Подобрать профиль'))),
                            OutlinedButton.icon(onPressed: _jobs.isEmpty || _isEncoding ? null : _createTestClip, icon: Icon(Icons.science_outlined), label: Text(tr('Тест 20 секунд'))),
                            OutlinedButton.icon(onPressed: _jobs.isEmpty || _isEncoding ? null : _compareProfilesOnTestClip, icon: Icon(Icons.compare_rounded), label: Text(tr('Сравнить профили'))),
                            OutlinedButton.icon(onPressed: _jobs.where((j) => j.status == JobStatus.done).isEmpty ? null : _openHistory, icon: Icon(Icons.history_rounded), label: Text(tr('История экспорта'))),
                            OutlinedButton.icon(onPressed: _jobs.isEmpty ? null : _openPublishingManager, icon: Icon(Icons.campaign_outlined), label: Text(tr('Публикации'))),
                            OutlinedButton.icon(onPressed: _jobs.where((j) => j.status == JobStatus.done).isEmpty ? null : _compareLatestOutput, icon: Icon(Icons.compare_arrows_rounded), label: Text(tr('Проверить результат'))),
                          ]),
                        SizedBox(height: 12),
                        _buildQueueCard(doneCount),
                        if (_isEncoding) ...<Widget>[
                          SizedBox(height: 18),
                          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Row(children: <Widget>[
                              Expanded(child: Text(tr('Обработка видео'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                              Text('$_currentJob / $_currentTotal', style: const TextStyle(color: Color(0xFFB5F36D), fontWeight: FontWeight.w800)),
                            ]),
                            SizedBox(height: 14),
                            ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(minHeight: 8, value: batchProgress, backgroundColor: const Color(0xFF30342B))),
                            SizedBox(height: 10),
                            Text(_currentProgress == null ? 'Обработано ${_formatClock(_currentMediaSeconds)}' : 'Текущий файл: ${(_currentProgress! * 100).round()}% · ${_formatClock(_currentMediaSeconds)}', style: const TextStyle(color: Color(0xFFB5B9AE), fontSize: 12)),
                            if (_currentSpeed > 0 || remainingSeconds != null) ...<Widget>[
                              SizedBox(height: 4),
                              Text('${_currentSpeed > 0 ? 'Скорость ${_currentSpeed.toStringAsFixed(1)}×' : ''}${_currentSpeed > 0 && remainingSeconds != null ? '  ·  ' : ''}${remainingSeconds != null ? 'Осталось около ${_formatClock(remainingSeconds)}' : ''}', style: const TextStyle(color: Color(0xFF858B7D), fontSize: 12)),
                            ],
                          ]))),
                        ],
                        SizedBox(height: 18),
                        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                          Row(children: <Widget>[
                            Container(width: 9, height: 9, decoration: BoxDecoration(color: _initializationError == null ? const Color(0xFFB5F36D) : const Color(0xFFFFC56C), shape: BoxShape.circle)),
                            SizedBox(width: 9),
                            Expanded(child: Text(tr(_status), style: const TextStyle(color: Color(0xFFB5B9AE), fontSize: 13))),
                          ]),
                          if (_initializationError != null) ...<Widget>[
                            SizedBox(height: 8),
                            Text(tr(_initializationError!), style: const TextStyle(color: Color(0xFFFFC56C), fontSize: 12)),
                          ],
                          SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isPreparing || _isEncoding || _outputDirectory == null ? null : _encodeAll,
                            icon: _isEncoding ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF15180F))) : Icon(Icons.play_arrow_rounded),
                            label: Text(_isEncoding ? 'ОБРАБОТКА $_currentJob/$_currentTotal' : 'НАЧАТЬ ОБРАБОТКУ'),
                          ),
                          if (_isEncoding) ...<Widget>[
                            SizedBox(height: 10),
                            OutlinedButton.icon(onPressed: _cancelRequested ? null : _cancelEncoding, icon: Icon(Icons.stop_rounded), label: Text(_cancelRequested ? 'ОСТАНОВКА…' : 'ОСТАНОВИТЬ ОБРАБОТКУ')),
                          ],
                          SizedBox(height: 14),
                          Text(tr('Обработка выполняется локально на вашем устройстве'), textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF858B7D), fontSize: 11)),
                        ]))),
                      ],
                    );
                  }),
                ),
              ),
              if (_isDragging)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: const Color(0xAA10110F),
                      alignment: Alignment.center,
                      child: Container(
                        margin: const EdgeInsets.all(28),
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1C18),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFB5F36D),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.file_download_outlined, size: 48, color: Color(0xFFB5F36D)),
                            SizedBox(height: 14),
                            Text(tr('Отпустите файлы здесь'),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 7),
                            Text(tr('MP4 · MOV · MKV · M4V · AVI · WEBM'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFFB5B9AE)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, {Color color = const Color(0xFF858B7D)}) {
    return Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), child: Row(children: <Widget>[
      Icon(icon, size: 20, color: color),
      SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFF3F4EE))),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF858B7D))),
      ])),
    ])));
  }

  Widget _desktopDropTarget(Widget child) {
    if (!(Platform.isMacOS || Platform.isWindows)) {
      return child;
    }
    return DropTarget(
      onDragEntered: (_) {
        if (mounted && !_isEncoding) setState(() => _isDragging = true);
      },
      onDragExited: (_) {
        if (mounted) setState(() => _isDragging = false);
      },
      onDragDone: (details) {
        if (!mounted) return;
        setState(() => _isDragging = false);
        _addVideoPaths(details.files.map((file) => file.path));
      },
      child: child,
    );
  }

  Widget _buildProfileCard() {
    return Card(child: Padding(padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 10 : 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFFB5F36D).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.tune_rounded, color: Color(0xFFB5F36D))), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(tr('Профиль экспорта'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text(tr('Выберите, что важнее: качество или размер'), style: TextStyle(fontSize: 11, color: Color(0xFF858B7D))) ]))]),
      SizedBox(height: 12),
      ...ExportProfile.values.map((profile) {
        final selected = _profile == profile;
        final icon = switch (profile) { ExportProfile.highQuality => Icons.high_quality_rounded, ExportProfile.balanced => Icons.balance_rounded, ExportProfile.compact => Icons.sd_storage_rounded, ExportProfile.youtube1080 => Icons.smart_display_rounded, ExportProfile.lossless => Icons.verified_rounded, ExportProfile.custom => Icons.tune_rounded };
        return Padding(padding: const EdgeInsets.only(bottom: 6), child: Material(color: selected ? const Color(0xFFB5F36D).withValues(alpha: 0.09) : const Color(0xFF131510), borderRadius: BorderRadius.circular(15), child: InkWell(borderRadius: BorderRadius.circular(15), onTap: _isEncoding ? null : () { setState(() => _profile = profile); _persistState(); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), constraints: const BoxConstraints(minHeight: 54), decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: selected ? const Color(0xFFB5F36D) : const Color(0xFF30342B))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Icon(icon, color: selected ? const Color(0xFFB5F36D) : const Color(0xFF858B7D), size: 21), SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(profile.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? const Color(0xFFF3F4EE) : const Color(0xFFCFD2C9))), SizedBox(height: 2), Text(profile.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.3, color: Color(0xFF858B7D)))])), SizedBox(width: 8), Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? const Color(0xFFB5F36D) : const Color(0xFF505548), size: 19),
        ])))));
      }),
    ])));
  }

  Widget _buildHeader() {
    return Row(children: <Widget>[
      Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFB5F36D), borderRadius: BorderRadius.circular(13)), child: Icon(Icons.movie_filter_rounded, color: Color(0xFF15180F), size: 24)),
      SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('VIDEOFORGE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.4, color: Color(0xFFB5F36D))),
        SizedBox(height: 3),
        Text(tr('Конвертация видео'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.45)),
      ])),
      PopupMenuButton<String>(
        tooltip: 'Language / Язык / Мотт',
        onSelected: (language) async {
          setState(() {
            videoForgeLanguage.value = language;
            _activeLanguage = language;
          });
          try {
            await (await SharedPreferences.getInstance()).setString('videoforge.language', language);
          } catch (_) {}
        },
        itemBuilder: (context) => const <PopupMenuEntry<String>>[
          PopupMenuItem(value: 'ru', child: Text('Русский')),
          PopupMenuItem(value: 'en', child: Text('English')),
          PopupMenuItem(value: 'ce', child: Text('Нохчийн')),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFF30342B)), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Icon(Icons.language, size: 16), SizedBox(width: 4),
            Text(switch (videoForgeLanguage.value) { 'en' => 'EN', 'ce' => 'НОХ', _ => 'RU' }, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      SizedBox(width: 8),
      if (_isPreparing) SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2)) else Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFB5F36D).withValues(alpha: 0.09), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFF30342B))), child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[Icon(Icons.shield_outlined, size: 15, color: Color(0xFFB5F36D)), SizedBox(width: 6), Text(tr('ЛОКАЛЬНО'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: Color(0xFFB5F36D))) ])),
    ]);
  }

  Widget _buildHeroCard() {
    return Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFF252A1E), Color(0xFF1A1C18), Color(0xFF171914)]), border: Border.all(color: const Color(0xFF3B4430))), child: Padding(padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 10 : 20), child: LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 580;
      if (compact && Platform.isAndroid) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.movie_creation_outlined, color: Color(0xFFB5F36D), size: 24),
                SizedBox(width: 9),
                Expanded(child: Text(tr('Пакетная обработка'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
              ],
            ),
            SizedBox(height: 4),
            Text(tr('Добавьте видео и выберите качество.'), style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFFB5B9AE))),
            SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: _isEncoding || _isPreparing ? null : _pickVideos,
                icon: Icon(Icons.add_rounded),
                label: Text(_jobs.isEmpty ? 'Добавить видео' : 'Добавить ещё'),
              ),
            ),
            if (_jobs.isNotEmpty) ...<Widget>[
              SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: _isEncoding || _isPreparing ? null : _encodeAll,
                  icon: Icon(Icons.play_arrow_rounded),
                  label: Text(tr('Запустить очередь')),
                ),
              ),
            ],
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                TextButton.icon(onPressed: _isEncoding ? null : _configureCustomProfile, icon: Icon(Icons.tune_rounded, size: 17), label: Text(tr('Мой профиль'))),
                TextButton.icon(onPressed: _exportDiagnostics, icon: Icon(Icons.receipt_long_outlined, size: 17), label: Text(tr('Диагностика'))),
              ],
            ),
          ],
        );
      }
      final intro = Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFB5F36D).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(30)), child: Text(tr('ПАКЕТНАЯ ОБРАБОТКА'), style: TextStyle(color: Color(0xFFB5F36D), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
        SizedBox(height: 17),
        Text(tr('Подготовь видео\nк следующему шагу.'), style: Theme.of(context).textTheme.headlineMedium),
        SizedBox(height: 10),
        Text(tr('Добавь видео, настрой качество и запусти обработку.'), style: TextStyle(fontSize: 13, height: 1.55, color: Color(0xFFB5B9AE))),
        SizedBox(height: 19),
        Wrap(spacing: 7, runSpacing: 7, children: <Widget>[_FormatChip(label: 'MP4'), _FormatChip(label: 'MOV'), _FormatChip(label: 'MKV'), _FormatChip(label: 'M4V'), _FormatChip(label: 'AVI'), _FormatChip(label: 'WEBM')]),
        SizedBox(height: 22),
        Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
          SizedBox(width: compact ? double.infinity : 205, child: FilledButton.icon(onPressed: _isEncoding || _isPreparing ? null : _pickVideos, icon: Icon(Icons.add_rounded), label: Text(_jobs.isEmpty ? 'Добавить видео' : 'Добавить ещё'))),
          if (_jobs.isNotEmpty) OutlinedButton.icon(onPressed: _isEncoding ? null : _encodeAll, icon: Icon(Icons.play_arrow_rounded), label: Text(tr('Запустить очередь'))),
          OutlinedButton.icon(onPressed: _isEncoding ? null : _configureCustomProfile, icon: Icon(Icons.tune_rounded), label: Text(tr('Мой профиль'))),
          OutlinedButton.icon(onPressed: _isEncoding ? null : _exportDiagnostics, icon: Icon(Icons.receipt_long_outlined), label: Text(tr('Диагностика'))),
        ]),
      ]);
      if (compact) return intro;
      return Row(children: <Widget>[Expanded(flex: 7, child: intro), SizedBox(width: 24), Expanded(flex: 4, child: Container(height: 220, decoration: BoxDecoration(color: const Color(0xFF11130F), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF30342B))), child: Stack(children: <Widget>[
        Positioned(right: 18, top: 18, child: Container(width: 72, height: 72, decoration: BoxDecoration(color: const Color(0xFFB5F36D).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)), child: Icon(Icons.graphic_eq_rounded, size: 38, color: Color(0xFFB5F36D)))),
        Center(child: Icon(Icons.movie_creation_outlined, size: 76, color: Color(0xFFB5F36D))),
        Positioned(left: 16, right: 16, bottom: 16, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF20231B), borderRadius: BorderRadius.circular(14)), child: Row(children: <Widget>[Icon(Icons.bolt_rounded, color: Color(0xFFB5F36D)), SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(tr('Готов к работе'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), SizedBox(height: 2), Text(tr('Без загрузки файлов в облако'), style: TextStyle(fontSize: 10, color: Color(0xFF858B7D))) ]))]))),
      ])))]);
    })));
  }

  Widget _buildOutputCard() {
    if (Platform.isAndroid) {
      final estimate = _formatBytes((_jobs.fold<int>(0, (sum, job) => sum + job.bytes) *
          (_profile.isLossless ? 4.0 : _profile == ExportProfile.compact ? 0.65 : 1.1)).round());
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFB5F36D).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.photo_library_outlined, color: Color(0xFFB5F36D)),
              ),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(tr('Сохранение результата'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text(tr('Галерея → альбом VideoForge'), style: TextStyle(fontSize: 12, color: Color(0xFFB5F36D))),
                    SizedBox(height: 3),
                    Text(tr('Оценка размера: $estimate'), style: const TextStyle(fontSize: 11, color: Color(0xFF858B7D))),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('Информация о сохранении'),
                onPressed: () => _showMessage(tr('Готовые видео сохраняются в галерею телефона, альбом VideoForge.')),
                icon: Icon(Icons.info_outline_rounded),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFB5F36D).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.folder_copy_outlined,
                color: Color(0xFFB5F36D),
              ),
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(tr('Папка для готовых видео'),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 5),
                  SelectableText(
                    _outputDirectory?.path ?? 'Создаётся автоматически…',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text('Оценка для выбранного профиля: ${_formatBytes((_jobs.fold<int>(0, (sum, job) => sum + job.bytes) * (_profile.isLossless ? 4.0 : _profile == ExportProfile.compact ? 0.65 : 1.1)).round())} (очень приблизительно)', style: const TextStyle(color: Color(0xFF858B7D), fontSize: 11)),
                  SizedBox(height: 7),
                  Text(
                    Platform.isWindows
                        ? 'Videos/Processed_New'
                        : Platform.isMacOS
                            ? 'Movies/Processed_New'
                            : 'Галерея · альбом VideoForge',
                    style: const TextStyle(
                      color: Color(0xFFB5F36D),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: <Widget>[
                IconButton(
                  tooltip: tr('Выбрать папку результата'),
                  onPressed: _isEncoding || _isPreparing ? null : _chooseOutputDirectory,
                  icon: Icon(Icons.drive_folder_upload_outlined),
                ),
                IconButton(
                  tooltip: Platform.isWindows || Platform.isMacOS
                      ? 'Открыть папку'
                      : 'Как сохранить результат',
                  onPressed: _outputDirectory == null ? null : _openOutputFolder,
                  icon: Icon(Icons.open_in_new_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueCard(int doneCount) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(tr('Очередь видео'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_jobs.isNotEmpty)
                  Text(tr('${_jobs.length} файлов · готово $doneCount'),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 7),
            if (_jobs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.video_library_outlined,
                      size: 27,
                      color: Colors.white38,
                    ),
                    SizedBox(height: 9),
                    Text(tr('Пока нет видео'),
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 4),
                    Text(tr('Добавьте один или несколько файлов'),
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._jobs.map(_buildJobTile),
            if (_jobs.isNotEmpty && !_isEncoding) ...<Widget>[
              SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                runSpacing: 0,
                children: <Widget>[
                  if (_selectedJobPaths.isNotEmpty)
                    TextButton.icon(
                      onPressed: _removeSelectedJobs,
                      icon: Icon(Icons.remove_circle_outline_rounded, size: 16),
                      label: Text(tr('Убрать выбранные (${_selectedJobPaths.length})')),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() { _jobs.clear(); _selectedJobPaths.clear(); });
                      _persistState();
                    },
                    icon: Icon(Icons.delete_outline_rounded, size: 16),
                    label: Text(tr('Очистить')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJobTile(VideoJob job) {
    final statusColor = switch (job.status) {
      JobStatus.queued => Colors.white54,
      JobStatus.encoding => const Color(0xFFB5F36D),
      JobStatus.done => const Color(0xFF75D89B),
      JobStatus.failed => const Color(0xFFFF8F83),
    };

    final statusLabel = switch (job.status) {
      JobStatus.queued => 'В очереди',
      JobStatus.encoding => 'Кодирование…',
      JobStatus.done => 'Готово',
      JobStatus.failed => 'Ошибка',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF131510),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF30342B)),
        ),
        child: Row(
          children: <Widget>[
            if (!_isEncoding) Checkbox(
              value: _selectedJobPaths.contains(_pathKey(job.path)),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedJobPaths.add(_pathKey(job.path));
                  } else {
                    _selectedJobPaths.remove(_pathKey(job.path));
                  }
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                job.status == JobStatus.done
                    ? Icons.check_circle_outline_rounded
                    : job.status == JobStatus.failed
                        ? Icons.error_outline_rounded
                        : Icons.movie_outlined,
                color: statusColor,
              ),
            ),
            SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    job.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 3),
                  Text(
                    job.outputBytes == null
                        ? '${_formatBytes(job.bytes)}  ·  $statusLabel'
                        : '${_formatBytes(job.bytes)} → ${_formatBytes(job.outputBytes!)}  ·  ${_sizeChangeLabel(job)}',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                    ),
                  ),
                  if (job.status == JobStatus.done && job.outputPath != null)
                    Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text(tr('Готовый файл сохранён'),
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                  if (job.error != null) ...<Widget>[
                    SizedBox(height: 4),
                    Text(
                      job.error!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFFA69C),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(visualDensity: VisualDensity.compact, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero, tooltip: tr('Анализ и сведения о видео'), onPressed: () => _showVideoDetails(job), icon: Icon(Icons.info_outline_rounded)),
            if (job.status == JobStatus.done && job.outputPath != null)
              Builder(
                builder: (buttonContext) => IconButton(
                  visualDensity: VisualDensity.compact, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero,
                  tooltip: tr('Поделиться или сохранить видео'),
                  onPressed: () => _shareVideo(
                    job.outputPath!,
                    buttonContext,
                  ),
                  icon: Icon(Icons.ios_share_rounded),
                ),
              )
            else if (!_isEncoding)
              IconButton(
                visualDensity: VisualDensity.compact, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero,
                tooltip: tr('Убрать из списка'),
                onPressed: () => _removeJob(job),
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white54,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF33424F)),
        borderRadius: BorderRadius.circular(30),
        color: const Color(0xFF131510),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
          headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1.1, color: Color(0xFFF3F4EE)),
          headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: Color(0xFFF3F4EE)),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFF3F4EE)),
          bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: Color(0xFFB5B9AE)),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
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
            minimumSize: const Size(0, 54),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF3F4EE),
            minimumSize: const Size(0, 50),
            side: const BorderSide(color: border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
  lossless;

  String get title => switch (this) {
        ExportProfile.highQuality => 'Высокое качество',
        ExportProfile.balanced => 'Сбалансированный',
        ExportProfile.compact => 'Компактный размер',
        ExportProfile.youtube1080 => 'YouTube 1080p',
        ExportProfile.lossless => 'Без потерь — новое кодирование',
      };

  String get description => switch (this) {
        ExportProfile.highQuality => 'Меньше потерь качества, файл может быть больше.',
        ExportProfile.balanced => 'Рекомендуемый баланс качества и размера.',
        ExportProfile.compact => 'Меньше места на диске, заметнее потери качества.',
        ExportProfile.youtube1080 => 'MP4 до 1080p с сохранением пропорций.',
        ExportProfile.lossless => 'FFV1 в MKV: новое кодирование видео без потерь. Файл может быть значительно больше; не все платформы принимают этот формат.',
      };

  int get crf => switch (this) {
        ExportProfile.highQuality => 18,
        ExportProfile.balanced => 20,
        ExportProfile.compact => 25,
        ExportProfile.youtube1080 => 20,
        ExportProfile.lossless => 0,
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

  String _status = 'Подготавливаем папку для результатов…';
  String? _initializationError;

  static const _prefOutputDirectory = 'videoforge.outputDirectory';
  static const _prefProfile = 'videoforge.exportProfile';
  static const _prefQueue = 'videoforge.queue';
  SharedPreferences? _preferences;

  @override
  void initState() {
    super.initState();
    _prepareOutputDirectory();
  }

  Future<void> _prepareOutputDirectory() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      final savedProfile = _preferences?.getString(_prefProfile);
      if (savedProfile != null) {
        _profile = ExportProfile.values.firstWhere(
          (profile) => profile.name == savedProfile,
          orElse: () => ExportProfile.balanced,
        );
      }
      final savedQueue = _preferences?.getString(_prefQueue);
      if (savedQueue != null && savedQueue.isNotEmpty) {
        _restoreQueue(savedQueue);
      }
      final savedOutput = _preferences?.getString(_prefOutputDirectory);
      final directory = savedOutput != null && savedOutput.trim().isNotEmpty
          ? Directory(savedOutput)
          : await _resolveOutputDirectory();
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
        _jobs.add(job);
      }
    } catch (_) {
      // A corrupt saved queue must not prevent the app from opening.
    }
  }

  Future<void> _persistState() async {
    try {
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      _preferences = prefs;
      await prefs.setString(_prefProfile, _profile.name);
      final output = _outputDirectory;
      if (output != null) await prefs.setString(_prefOutputDirectory, output.path);
      final queue = _jobs.map((job) => <String, Object?>{
        'path': job.path,
        'bytes': job.bytes,
        'status': job.status.name == 'encoding' ? 'queued' : job.status.name,
        'outputPath': job.outputPath,
        'outputBytes': job.outputBytes,
        'error': job.error,
      }).toList(growable: false);
      await prefs.setString(_prefQueue, jsonEncode(queue));
    } catch (_) {
      if (mounted) _showMessage('Не удалось сохранить настройки приложения.');
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
      _showMessage('Папка результата сохранена.');
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
        _showMessage('Автоматическая проверка свободного места недоступна на этом устройстве.');
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
      final home = Platform.environment['USERPROFILE'];

      if (home != null && home.isNotEmpty) {
        return Directory(
          p.join(home, 'Videos', 'Processed_New'),
        );
      }
    }

    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];

      if (home != null && home.isNotEmpty) {
        return Directory(
          p.join(home, 'Movies', 'Processed_New'),
        );
      }
    }

    final documents = await getApplicationDocumentsDirectory();

    return Directory(
      p.join(documents.path, 'Processed_New'),
    );
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
      _showMessage('Дождитесь завершения кодирования перед добавлением файлов.');
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
      _showMessage('Поддерживаются MP4, MOV, MKV, M4V, AVI и WEBM.');
    } else if (added.isEmpty && pathList.isNotEmpty) {
      _showMessage('Эти видео уже есть в очереди.');
    }
  }

  String _pathKey(String path) {
    final normalized = p.normalize(p.absolute(path));
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }


  Future<void> _encodeAll() async {
    if (_isEncoding || _outputDirectory == null) return;

    final pending = _jobs
        .where(
          (job) =>
              job.status == JobStatus.queued ||
              job.status == JobStatus.failed,
        )
        .toList(growable: false);

    if (pending.isEmpty) {
      _showMessage('Сначала выберите видео для кодирования.');
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
            final outputBytes = await outputFile.length();
            setState(() {
              job.status = JobStatus.done;
              job.outputPath = outputPath;
              job.outputBytes = outputBytes;
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
    double durationSeconds,
  ) async {
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
        profile.preset,
        '-crf',
        profile.crf.toString(),
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
    setState(() => _jobs.remove(job));
    _persistState();
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
                      padding: EdgeInsets.fromLTRB(wide ? 34 : 18, 24, wide ? 34 : 18, 36),
                      children: <Widget>[
                        _buildHeader(),
                        const SizedBox(height: 28),
                        _buildHeroCard(),
                        const SizedBox(height: 18),
                        if (wide)
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Expanded(flex: 6, child: _buildProfileCard()),
                            const SizedBox(width: 18),
                            Expanded(flex: 5, child: _buildOutputCard()),
                          ])
                        else ...<Widget>[
                          _buildProfileCard(),
                          const SizedBox(height: 14),
                          _buildOutputCard(),
                        ],
                        const SizedBox(height: 18),
                        Row(children: <Widget>[
                          Expanded(child: _metricCard('В очереди', '${_jobs.length}', Icons.video_library_outlined)),
                          const SizedBox(width: 10),
                          Expanded(child: _metricCard('Готово', '$doneCount', Icons.check_circle_outline_rounded, color: const Color(0xFFB5F36D))),
                          const SizedBox(width: 10),
                          Expanded(child: _metricCard('Ошибки', '$failedCount', Icons.error_outline_rounded, color: const Color(0xFFFF8178))),
                        ]),
                        const SizedBox(height: 18),
                        _buildQueueCard(doneCount),
                        if (_isEncoding) ...<Widget>[
                          const SizedBox(height: 18),
                          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Row(children: <Widget>[
                              const Expanded(child: Text('Обработка видео', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                              Text('$_currentJob / $_currentTotal', style: const TextStyle(color: Color(0xFFB5F36D), fontWeight: FontWeight.w800)),
                            ]),
                            const SizedBox(height: 14),
                            ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(minHeight: 8, value: batchProgress, backgroundColor: const Color(0xFF30342B))),
                            const SizedBox(height: 10),
                            Text(_currentProgress == null ? 'Обработано ${_formatClock(_currentMediaSeconds)}' : 'Текущий файл: ${(_currentProgress! * 100).round()}% · ${_formatClock(_currentMediaSeconds)}', style: const TextStyle(color: Color(0xFFB5B9AE), fontSize: 12)),
                            if (_currentSpeed > 0 || remainingSeconds != null) ...<Widget>[
                              const SizedBox(height: 4),
                              Text('${_currentSpeed > 0 ? 'Скорость ${_currentSpeed.toStringAsFixed(1)}×' : ''}${_currentSpeed > 0 && remainingSeconds != null ? '  ·  ' : ''}${remainingSeconds != null ? 'Осталось около ${_formatClock(remainingSeconds)}' : ''}', style: const TextStyle(color: Color(0xFF858B7D), fontSize: 12)),
                            ],
                          ]))),
                        ],
                        const SizedBox(height: 18),
                        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                          Row(children: <Widget>[
                            Container(width: 9, height: 9, decoration: BoxDecoration(color: _initializationError == null ? const Color(0xFFB5F36D) : const Color(0xFFFFC56C), shape: BoxShape.circle)),
                            const SizedBox(width: 9),
                            Expanded(child: Text(_status, style: const TextStyle(color: Color(0xFFB5B9AE), fontSize: 13))),
                          ]),
                          if (_initializationError != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(_initializationError!, style: const TextStyle(color: Color(0xFFFFC56C), fontSize: 12)),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isPreparing || _isEncoding || _outputDirectory == null ? null : _encodeAll,
                            icon: _isEncoding ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF15180F))) : const Icon(Icons.play_arrow_rounded),
                            label: Text(_isEncoding ? 'ОБРАБОТКА $_currentJob/$_currentTotal' : 'НАЧАТЬ ОБРАБОТКУ'),
                          ),
                          if (_isEncoding) ...<Widget>[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(onPressed: _cancelRequested ? null : _cancelEncoding, icon: const Icon(Icons.stop_rounded), label: Text(_cancelRequested ? 'ОСТАНОВКА…' : 'ОСТАНОВИТЬ ОБРАБОТКУ')),
                          ],
                          const SizedBox(height: 14),
                          const Text('Обработка выполняется локально на вашем устройстве', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF858B7D), fontSize: 11)),
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
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.file_download_outlined, size: 48, color: Color(0xFFB5F36D)),
                            SizedBox(height: 14),
                            Text(
                              'Отпустите файлы здесь',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 7),
                            Text(
                              'MP4 · MOV · MKV · M4V · AVI · WEBM',
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
    return Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15), child: Row(children: <Widget>[
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFFF3F4EE))),
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
    return Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFB5F36D).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.tune_rounded, color: Color(0xFFB5F36D))), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('Профиль экспорта', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Выберите, что важнее: качество или размер', style: TextStyle(fontSize: 11, color: Color(0xFF858B7D))) ]))]),
      const SizedBox(height: 18),
      ...ExportProfile.values.map((profile) {
        final selected = _profile == profile;
        final icon = switch (profile) { ExportProfile.highQuality => Icons.high_quality_rounded, ExportProfile.balanced => Icons.balance_rounded, ExportProfile.compact => Icons.sd_storage_rounded, ExportProfile.youtube1080 => Icons.smart_display_rounded, ExportProfile.lossless => Icons.verified_rounded };
        return Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(color: selected ? const Color(0xFFB5F36D).withValues(alpha: 0.09) : const Color(0xFF131510), borderRadius: BorderRadius.circular(15), child: InkWell(borderRadius: BorderRadius.circular(15), onTap: _isEncoding ? null : () { setState(() => _profile = profile); _persistState(); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: selected ? const Color(0xFFB5F36D) : const Color(0xFF30342B))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Icon(icon, color: selected ? const Color(0xFFB5F36D) : const Color(0xFF858B7D), size: 21), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(profile.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? const Color(0xFFF3F4EE) : const Color(0xFFCFD2C9))), const SizedBox(height: 4), Text(profile.description, style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF858B7D)))])), const SizedBox(width: 8), Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? const Color(0xFFB5F36D) : const Color(0xFF505548), size: 19),
        ])))));
      }),
    ])));
  }

  Widget _buildHeader() {
    return Row(children: <Widget>[
      Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFFB5F36D), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.movie_filter_rounded, color: Color(0xFF15180F), size: 30)),
      const SizedBox(width: 14),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('VIDEOFORGE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.4, color: Color(0xFFB5F36D))),
        SizedBox(height: 3),
        Text('Видео. Под твоим контролем.', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
      ])),
      if (_isPreparing) const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2)) else Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFB5F36D).withValues(alpha: 0.09), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFF30342B))), child: const Row(mainAxisSize: MainAxisSize.min, children: <Widget>[Icon(Icons.shield_outlined, size: 15, color: Color(0xFFB5F36D)), SizedBox(width: 6), Text('ЛОКАЛЬНО', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: Color(0xFFB5F36D))) ])),
    ]);
  }

  Widget _buildHeroCard() {
    return Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFF252A1E), Color(0xFF1A1C18), Color(0xFF171914)]), border: Border.all(color: const Color(0xFF3B4430))), child: Padding(padding: const EdgeInsets.all(26), child: LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 580;
      final intro = Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFB5F36D).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(30)), child: const Text('ПАКЕТНАЯ ОБРАБОТКА', style: TextStyle(color: Color(0xFFB5F36D), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
        const SizedBox(height: 17),
        Text('Подготовь видео
к следующему шагу.', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        const Text('Добавь один файл или целую папку видео. Выбери профиль — VideoForge обработает очередь на этом устройстве.', style: TextStyle(fontSize: 13, height: 1.55, color: Color(0xFFB5B9AE))),
        const SizedBox(height: 19),
        Wrap(spacing: 7, runSpacing: 7, children: const <Widget>[_FormatChip(label: 'MP4'), _FormatChip(label: 'MOV'), _FormatChip(label: 'MKV'), _FormatChip(label: 'M4V'), _FormatChip(label: 'AVI'), _FormatChip(label: 'WEBM')]),
        const SizedBox(height: 22),
        Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
          SizedBox(width: compact ? double.infinity : 205, child: FilledButton.icon(onPressed: _isEncoding || _isPreparing ? null : _pickVideos, icon: const Icon(Icons.add_rounded), label: Text(_jobs.isEmpty ? 'Добавить видео' : 'Добавить ещё'))),
          if (_jobs.isNotEmpty) OutlinedButton.icon(onPressed: _isEncoding ? null : _encodeAll, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Запустить очередь')),
        ]),
      ]);
      if (compact) return intro;
      return Row(children: <Widget>[Expanded(flex: 7, child: intro), const SizedBox(width: 24), Expanded(flex: 4, child: Container(height: 220, decoration: BoxDecoration(color: const Color(0xFF11130F), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF30342B))), child: Stack(children: <Widget>[
        Positioned(right: 18, top: 18, child: Container(width: 72, height: 72, decoration: BoxDecoration(color: const Color(0xFFB5F36D).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.graphic_eq_rounded, size: 38, color: Color(0xFFB5F36D)))),
        const Center(child: Icon(Icons.movie_creation_outlined, size: 76, color: Color(0xFFB5F36D))),
        Positioned(left: 16, right: 16, bottom: 16, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF20231B), borderRadius: BorderRadius.circular(14)), child: const Row(children: <Widget>[Icon(Icons.bolt_rounded, color: Color(0xFFB5F36D)), SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('Готов к работе', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), SizedBox(height: 2), Text('Без загрузки файлов в облако', style: TextStyle(fontSize: 10, color: Color(0xFF858B7D))) ]))]))),
      ])))]);
    })));
  }

  Widget _buildOutputCard() {
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
              child: const Icon(
                Icons.folder_copy_outlined,
                color: Color(0xFFB5F36D),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Папка для готовых видео',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    _outputDirectory?.path ?? 'Создаётся автоматически…',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    Platform.isWindows
                        ? 'Videos/Processed_New'
                        : Platform.isMacOS
                            ? 'Movies/Processed_New'
                            : 'Папка приложения / Processed_New',
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
                  tooltip: 'Выбрать папку результата',
                  onPressed: _isEncoding || _isPreparing ? null : _chooseOutputDirectory,
                  icon: const Icon(Icons.drive_folder_upload_outlined),
                ),
                IconButton(
                  tooltip: Platform.isWindows || Platform.isMacOS
                      ? 'Открыть папку'
                      : 'Как сохранить результат',
                  onPressed: _outputDirectory == null ? null : _openOutputFolder,
                  icon: const Icon(Icons.open_in_new_rounded),
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Очередь видео',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_jobs.isNotEmpty)
                  Text(
                    '${_jobs.length} файлов · готово $doneCount',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_jobs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 8,
                ),
                child: const Column(
                  children: <Widget>[
                    Icon(
                      Icons.video_library_outlined,
                      size: 35,
                      color: Colors.white38,
                    ),
                    SizedBox(height: 9),
                    Text(
                      'Пока нет видео',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Добавьте один или несколько файлов',
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
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(_jobs.clear);
                    _persistState();
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                  ),
                  label: const Text('Очистить список'),
                ),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF131510),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF30342B)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
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
            const SizedBox(width: 11),
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
                  const SizedBox(height: 3),
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
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text(
                        'Готовый файл сохранён',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                  if (job.error != null) ...<Widget>[
                    const SizedBox(height: 4),
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
            if (job.status == JobStatus.done && job.outputPath != null)
              Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: 'Поделиться или сохранить видео',
                  onPressed: () => _shareVideo(
                    job.outputPath!,
                    buttonContext,
                  ),
                  icon: const Icon(Icons.ios_share_rounded),
                ),
              )
            else if (!_isEncoding)
              IconButton(
                tooltip: 'Убрать из списка',
                onPressed: () => _removeJob(job),
                icon: const Icon(
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

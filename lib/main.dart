
import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VideoForgeApp());
}

class VideoForgeApp extends StatelessWidget {
  const VideoForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF55D6BE);

    return MaterialApp(
      title: 'VideoForge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: const Color(0xFF141A22),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1016),
        cardTheme: CardThemeData(
          color: const Color(0xFF141A22),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF27313D)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ),
      home: const EncoderHomePage(),
    );
  }
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
  int _currentJob = 0;
  int _currentTotal = 0;

  String _status = 'Подготавливаем папку для результатов…';
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _prepareOutputDirectory();
  }

  Future<void> _prepareOutputDirectory() async {
    try {
      final directory = await _resolveOutputDirectory();
      await directory.create(recursive: true);

      if (!mounted) return;

      setState(() {
        _outputDirectory = directory;
        _isPreparing = false;
        _status = 'Готово к работе';
      });
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
          _status = 'Готово к работе';
          _initializationError =
              'Основная папка недоступна. Используется папка приложения.';
        });
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

      final existingPaths = _jobs.map((job) => job.path).toSet();
      final added = <VideoJob>[];
      var missingPathCount = 0;

      for (final item in picked) {
        final filePath = item.path;

        if (filePath == null || filePath.isEmpty) {
          missingPathCount++;
          continue;
        }

        final extension =
            p.extension(filePath).replaceFirst('.', '').toLowerCase();

        if (!_videoExtensions.contains(extension) ||
            existingPaths.contains(filePath)) {
          continue;
        }

        if (!await File(filePath).exists()) {
          missingPathCount++;
          continue;
        }

        final bytes = item.lengthSync() ?? (await item.length()) ?? 0;

        existingPaths.add(filePath);
        added.add(VideoJob(path: filePath, bytes: bytes));
      }

      if (!mounted) return;

      setState(() {
        _jobs.addAll(added);
        _status = _jobs.isEmpty
            ? 'Выберите один или несколько видеофайлов'
            : 'Добавлено файлов: ${added.length}';
      });

      if (missingPathCount > 0 && mounted) {
        _showMessage(
          'Некоторые файлы недоступны. '
          'Скачайте их на устройство и выберите снова.',
        );
      } else if (added.isEmpty && picked.isNotEmpty && mounted) {
        _showMessage('Новых поддерживаемых видео не найдено.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Не удалось выбрать видео: $error');
      }
    }
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

    setState(() {
      _isEncoding = true;
      _currentJob = 0;
      _currentTotal = pending.length;
      _status = 'Запускаем кодирование…';

      for (final job in pending) {
        job.error = null;
      }
    });

    var completed = 0;
    var failed = 0;

    try {
      for (var index = 0; index < pending.length; index++) {
        if (!mounted) return;

        final job = pending[index];
        String? outputPath;

        setState(() {
          _currentJob = index + 1;
          job.status = JobStatus.encoding;
          _status =
              'Кодирование ${index + 1} из ${pending.length}: ${job.name}';
        });

        try {
          outputPath = await _uniqueOutputPath(job.name);

          final result = await _runFfmpeg(
            job.path,
            outputPath,
          );

          if (!mounted) return;

          if (result.success) {
            setState(() {
              job.status = JobStatus.done;
              job.outputPath = outputPath;
              job.error = null;
            });

            completed++;
          } else {
            await _deleteIfExists(outputPath);

            setState(() {
              job.status = JobStatus.failed;
              job.error = result.message ?? 'Неизвестная ошибка FFmpeg.';
            });

            failed++;
          }
        } catch (error) {
          if (outputPath != null) {
            await _deleteIfExists(outputPath);
          }

          if (!mounted) return;

          setState(() {
            job.status = JobStatus.failed;
            job.error = error.toString();
          });

          failed++;
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEncoding = false;
          _status = failed == 0
              ? 'Готово! Успешно обработано: $completed'
              : 'Завершено: $completed успешно, ошибок: $failed';
        });
      }
    }

    if (!mounted) return;

    _showMessage(
      failed == 0
          ? 'Готово! Файлы сохранены в Processed_New.'
          : 'Обработка завершена. Успешно: $completed, с ошибкой: $failed.',
    );
  }

  Future<({bool success, String? message})> _runFfmpeg(
    String inputPath,
    String outputPath,
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
      '-c:v',
      'libx264',
      '-preset',
      'medium',
      '-crf',
      '20',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-movflags',
      '+faststart',
      outputPath,
    ];

    try {
      await FFmpegKit.executeWithArgumentsAsync(
        args,
        (session) async {
          try {
            final returnCode = await session.getReturnCode();

            if (ReturnCode.isSuccess(returnCode)) {
              if (!completer.isCompleted) {
                completer.complete(
                  (success: true, message: null),
                );
              }
            } else {
              final output = await session.getOutput();
              final details = (output ?? '').trim();

              if (!completer.isCompleted) {
                completer.complete(
                  (
                    success: false,
                    message: details.isEmpty
                        ? 'FFmpeg завершился с кодом '
                            '${returnCode?.getValue() ?? 'неизвестно'}.'
                        : _shortError(details),
                  ),
                );
              }
            }
          } catch (error) {
            if (!completer.isCompleted) {
              completer.complete(
                (success: false, message: error.toString()),
              );
            }
          }
        },
      );
    } catch (error) {
      if (!completer.isCompleted) {
        completer.complete(
          (success: false, message: error.toString()),
        );
      }
    }

    return completer.future;
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

    var candidate = p.join(directory.path, '$safeBase.mp4');
    var suffix = 2;

    while (await File(candidate).exists()) {
      candidate = p.join(
        directory.path,
        '${safeBase}_$suffix.mp4',
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

  @override
  Widget build(BuildContext context) {
    final doneCount =
        _jobs.where((job) => job.status == JobStatus.done).length;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              children: <Widget>[
                _buildHeader(),
                const SizedBox(height: 24),
                _buildHeroCard(),
                const SizedBox(height: 16),
                _buildOutputCard(),
                const SizedBox(height: 16),
                _buildQueueCard(doneCount),
                if (_isEncoding) ...<Widget>[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(20),
                    value: _currentTotal > 0
                        ? _currentJob / _currentTotal
                        : null,
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                if (_initializationError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _initializationError!,
                    style: const TextStyle(
                      color: Color(0xFFFFC56C),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _isPreparing ||
                          _isEncoding ||
                          _outputDirectory == null
                      ? null
                      : _encodeAll,
                  icon: _isEncoding
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.bolt_rounded),
                  label: Text(
                    _isEncoding
                        ? 'КОДИРОВАНИЕ $_currentJob/$_currentTotal'
                        : 'КОДИРОВАТЬ',
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'H.264 · MP4 · AAC · Обработка на устройстве',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF55D6BE).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.movie_filter_rounded,
            color: Color(0xFF55D6BE),
            size: 27,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'VideoForge',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Простое кодирование видео',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (_isPreparing)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Tooltip(
            message: 'Видео обрабатывается локально на устройстве',
            child: Icon(
              Icons.verified_user_outlined,
              color: Color(0xFF55D6BE),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Превратите видео в MP4',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Выберите файлы — VideoForge создаст папку результатов '
              'и подготовит видео для совместимого воспроизведения.',
              style: TextStyle(
                color: Colors.white70,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const <Widget>[
                _FormatChip(label: 'MP4'),
                _FormatChip(label: 'MOV'),
                _FormatChip(label: 'MKV'),
                _FormatChip(label: 'M4V'),
                _FormatChip(label: 'AVI'),
                _FormatChip(label: 'WEBM'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _isEncoding || _isPreparing ? null : _pickVideos,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  _jobs.isEmpty ? 'ВЫБРАТЬ ВИДЕО' : 'ДОБАВИТЬ ВИДЕО',
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                color: const Color(0xFF55D6BE).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.folder_copy_outlined,
                color: Color(0xFF55D6BE),
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
                      color: Color(0xFF55D6BE),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: Platform.isWindows || Platform.isMacOS
                  ? 'Открыть папку'
                  : 'Как сохранить результат',
              onPressed:
                  _outputDirectory == null ? null : _openOutputFolder,
              icon: const Icon(Icons.open_in_new_rounded),
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
                  onPressed: () => setState(_jobs.clear),
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
      JobStatus.encoding => const Color(0xFF55D6BE),
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
          color: const Color(0xFF0E141B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF27313D)),
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
                    '${_formatBytes(job.bytes)}  ·  $statusLabel',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
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
        color: const Color(0xFF0E141B),
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

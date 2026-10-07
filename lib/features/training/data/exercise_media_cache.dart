import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import '../../../shared/utils/result.dart';
import '../domain/exercise_media.dart';

class ExerciseMediaSource {
  const ExerciseMediaSource({this.asset, this.file});
  final String? asset;
  final File? file;
}

typedef MediaDownloader =
    Future<void> Function(Uri uri, File destination, int maxBytes);

class ExerciseMediaCache {
  ExerciseMediaCache({
    required this.directory,
    MediaDownloader? download,
    this.maxFileBytes = 24 * 1024 * 1024,
    this.maxCacheBytes = 128 * 1024 * 1024,
  }) : download = download ?? _download;
  final Future<String> Function() directory;
  final MediaDownloader download;
  final int maxFileBytes;
  final int maxCacheBytes;
  Future<void> _pending = Future.value();

  Future<Result<void>> invalidate(ExerciseMedia media) {
    final operation = _pending.then((_) async {
      if (media.localAsset != null) return const Success<void>(null);
      try {
        final file = await _cacheFile(Directory(await directory()), media);
        if (await file.exists()) await file.delete();
        return const Success<void>(null);
      } on Object {
        return const Failure<void>(
          AppFailure(message: 'Nao foi possivel limpar esta animacao.'),
        );
      }
    });
    _pending = operation.then((_) {});
    return operation;
  }

  Future<File> _cacheFile(Directory root, ExerciseMedia media) async {
    final digest = await Sha256().hash(
      utf8.encode('${media.url}|${media.version}|${media.type.name}'),
    );
    final key = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return File('${root.path}/$key.${media.extension}');
  }

  Future<Result<ExerciseMediaSource>> resolve(ExerciseMedia media) {
    final operation = _pending.then((_) => _resolve(media));
    _pending = operation.then((_) {});
    return operation;
  }

  Future<Result<ExerciseMediaSource>> _resolve(ExerciseMedia media) async {
    final asset = media.localAsset;
    if (asset != null) {
      if (!asset.startsWith('assets/exercises/') ||
          asset.contains('..') ||
          asset.contains('\\')) {
        return const Failure(AppFailure(message: 'Animacao indisponivel.'));
      }
      return Success(ExerciseMediaSource(asset: asset));
    }
    final uri = Uri.tryParse(media.url ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return const Failure(AppFailure(message: 'Animacao indisponivel.'));
    }
    File? temporary;
    try {
      final root = Directory(await directory());
      await root.create(recursive: true);
      final file = await _cacheFile(root, media);
      if (await file.exists()) {
        final size = await file.length();
        if (size > 0 && size <= maxFileBytes) {
          await file.setLastModified(DateTime.now());
          return Success(ExerciseMediaSource(file: file));
        }
        await file.delete();
      }
      temporary = File('${file.path}.part');
      await download(uri, temporary, maxFileBytes);
      final size = await temporary.length();
      if (size <= 0 || size > maxFileBytes || size > maxCacheBytes) {
        throw const FormatException('Media size exceeds cache budget.');
      }
      await _makeRoom(root, size);
      await temporary.rename(file.path);
      return Success(ExerciseMediaSource(file: file));
    } on Object {
      return const Failure(
        AppFailure(
          message:
              'Nao foi possivel carregar a animacao. Tente novamente quando estiver conectado.',
        ),
      );
    } finally {
      if (temporary != null) {
        try {
          if (await temporary.exists()) await temporary.delete();
        } on FileSystemException {
          /* Retry can replace a partial file. */
        }
      }
    }
  }

  Future<void> _makeRoom(Directory root, int incoming) async {
    final files = <({File file, FileStat stat})>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is File && !entry.path.endsWith('.part')) {
        files.add((file: entry, stat: await entry.stat()));
      }
    }
    files.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    var total = files.fold(0, (sum, entry) => sum + entry.stat.size) + incoming;
    for (final entry in files) {
      if (total <= maxCacheBytes) break;
      await entry.file.delete();
      total -= entry.stat.size;
    }
  }

  static Future<void> _download(Uri uri, File destination, int maxBytes) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    IOSink? sink;
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200 || response.contentLength > maxBytes) {
        throw const HttpException('Media download rejected.');
      }
      sink = destination.openWrite();
      var total = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        total += chunk.length;
        if (total > maxBytes) throw const FormatException('Media too large.');
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }
}

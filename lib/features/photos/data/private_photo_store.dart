import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cryptography/cryptography.dart';

import '../../../shared/database/record_cipher.dart';

class PrivatePhotoStore {
  const PrivatePhotoStore(this.root, this.cipher, this.ownerId);
  final Directory root;
  final RecordCipher cipher;
  final String ownerId;

  Future<Directory> _directory() async {
    final hash = await Sha256().hash(utf8.encode(ownerId));
    final owner = hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return Directory('${root.path}/photos/$owner').create(recursive: true);
  }

  Future<File> _file(String fileName) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{20,200}\.vero$').hasMatch(fileName)) {
      throw const FormatException('Invalid photo path.');
    }
    final directory = await _directory();
    return File('${directory.path}/$fileName');
  }

  Future<String> save(String id, Uint8List bytes) async {
    // Encrypt an opaque ID, never a date or the original camera/gallery name.
    final name = await cipher.encryptBytes(
      utf8.encode(id),
      recordKey: 'photo-name:$ownerId',
    );
    final fileName = '${base64UrlEncode(name).replaceAll('=', '')}.vero';
    final encrypted = await cipher.encryptBytes(
      bytes,
      recordKey: 'photo:$ownerId:$id',
    );
    final file = await _file(fileName);
    try {
      await file.writeAsBytes(encrypted, flush: true);
      return fileName;
    } on Exception {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<Uint8List> read(String id, String fileName) async =>
      cipher.decryptBytes(
        await readEncrypted(fileName),
        recordKey: 'photo:$ownerId:$id',
      );

  Future<Uint8List> readEncrypted(String fileName) async =>
      (await _file(fileName)).readAsBytes();

  Future<Uint8List> readForSync(
    String id,
    String fileName,
    RecordCipher syncCipher,
  ) async {
    final clear = await read(id, fileName);
    return syncCipher.encryptBytes(
      clear,
      recordKey: 'cloud-photo:$ownerId:$id',
    );
  }

  Future<void> writeFromSync(
    String id,
    String fileName,
    Uint8List bytes,
    RecordCipher syncCipher,
  ) async {
    final clear = await syncCipher.decryptBytes(
      bytes,
      recordKey: 'cloud-photo:$ownerId:$id',
    );
    final local = await cipher.encryptBytes(
      clear,
      recordKey: 'photo:$ownerId:$id',
    );
    await writeEncrypted(fileName, local);
  }

  Future<void> writeEncrypted(String fileName, Uint8List bytes) async {
    await (await _file(fileName)).writeAsBytes(bytes, flush: true);
  }

  Future<void> delete(String fileName) async {
    final file = await _file(fileName);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAll() async {
    final directory = await _directory();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// Re-encoding strips EXIF/location and bounds dimensions before encryption.
Future<Uint8List> normalizePhoto(Uint8List bytes) async {
  if (bytes.length > 20 * 1024 * 1024) {
    throw const FormatException('Photo exceeds 20 MB.');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final largest = descriptor.width > descriptor.height
        ? descriptor.width
        : descriptor.height;
    final scale = largest > 1600 ? 1600 / largest : 1.0;
    final codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round().clamp(1, 1600),
      targetHeight: (descriptor.height * scale).round().clamp(1, 1600),
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final png = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (png == null) throw const FormatException('Unsupported photo.');
        return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}

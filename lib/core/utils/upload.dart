import 'dart:io' show File;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Picked photos and videos are [XFile]s on every platform. These helpers
/// keep file-system code (dart:io) to phones: on the web a picked file only
/// exists as bytes in the browser.

/// JPEG bytes of a picked image, resized. On the web, or if compression is not
/// possible, the original bytes are used.
Future<Uint8List> compressedImageBytes(XFile x, {int minWidth = 1080, int minHeight = 810, int quality = 82}) async {
  final raw = await x.readAsBytes();
  if (kIsWeb) return raw;
  try {
    final out = await FlutterImageCompress.compressWithList(raw, minWidth: minWidth, minHeight: minHeight, quality: quality);
    return out.isNotEmpty ? out : raw;
  } catch (_) {
    return raw;
  }
}

/// Uploads a picked file as is (videos, documents). Phones stream it from
/// disk; the browser has only the bytes.
Future<UploadTask> putPickedFile(Reference ref, XFile x, SettableMetadata meta) async {
  if (kIsWeb) return ref.putData(await x.readAsBytes(), meta);
  return ref.putFile(File(x.path), meta);
}

/// Shows a picked image. Reads the bytes once.
class XFileImage extends StatefulWidget {
  final XFile file;
  final double? width;
  final double? height;
  final BoxFit fit;
  const XFileImage(this.file, {super.key, this.width, this.height, this.fit = BoxFit.cover});
  @override
  State<XFileImage> createState() => _XFileImageState();
}

class _XFileImageState extends State<XFileImage> {
  late Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  void didUpdateWidget(covariant XFileImage old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) _bytes = widget.file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (_, s) {
        if (!s.hasData) return SizedBox(width: widget.width, height: widget.height);
        return Image.memory(s.data!, width: widget.width, height: widget.height, fit: widget.fit, errorBuilder: (_, __, ___) => SizedBox(width: widget.width, height: widget.height));
      },
    );
  }
}

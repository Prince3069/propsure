import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Gets frames and videos onto the agent's phone. On a phone this opens the
/// share sheet with the real files, where "Save to gallery" (or Photos) and
/// WhatsApp are one tap away. On the website the file opens in a new tab.

Future<List<XFile>> _download(List<String> urls, String prefix, String ext, String mime) async {
  final dir = await getTemporaryDirectory();
  final files = <XFile>[];
  for (var i = 0; i < urls.length; i++) {
    final r = await http.get(Uri.parse(urls[i]));
    if (r.statusCode != 200) throw Exception('Could not download file ${i + 1}. Check your connection and try again.');
    final f = File('${dir.path}/${prefix}_${i + 1}.$ext');
    await f.writeAsBytes(r.bodyBytes);
    files.add(XFile(f.path, mimeType: mime, name: '${prefix}_${i + 1}.$ext'));
  }
  return files;
}

Future<void> saveImagesToPhone(List<String> urls, {String prefix = 'propsure_frame'}) async {
  if (urls.isEmpty) return;
  if (kIsWeb) {
    await launchUrl(Uri.parse(urls.first), webOnlyWindowName: '_blank');
    return;
  }
  final files = await _download(urls, prefix, 'jpg', 'image/jpeg');
  await Share.shareXFiles(files, text: 'Frames from my Propsure video tour');
}

Future<void> saveVideoToPhone(String url, {String prefix = 'propsure_tour'}) async {
  if (kIsWeb) {
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    return;
  }
  final files = await _download([url], prefix, 'mp4', 'video/mp4');
  await Share.shareXFiles(files, text: 'My Propsure video tour');
}

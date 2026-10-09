import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Centralized offline and local caching service for BJCI journal manuscripts.
/// Downloads PDF once, caches permanently on device, and serves via local file IO.
class PdfCacheService {
  static final PdfCacheService _instance = PdfCacheService._internal();
  factory PdfCacheService() => _instance;
  PdfCacheService._internal();

  final Map<String, Future<File>> _activeDownloads = {};

  /// Returns cached file immediately if it exists and has content.
  Future<File?> getCachedPdf(String url, {dynamic pubId}) async {
    if (url.isEmpty) return null;
    final file = await _getCacheFile(url, pubId: pubId);
    if (await file.exists() && (await file.length()) > 1024) {
      return file;
    }
    return null;
  }

  /// Downloads the PDF with real-time percentage progress, saving to local cache.
  /// If already cached, returns immediately with progress = 1.0.
  Future<File> getOrDownloadPdf(
    String url, {
    dynamic pubId,
    void Function(double progress)? onProgress,
  }) async {
    if (url.isEmpty) {
      throw Exception('PDF URL is empty');
    }

    final file = await _getCacheFile(url, pubId: pubId);
    if (await file.exists() && (await file.length()) > 1024) {
      onProgress?.call(1.0);
      return file;
    }

    // Deduplicate concurrent downloads
    if (_activeDownloads.containsKey(url)) {
      return _activeDownloads[url]!;
    }

    final completer = Completer<File>();
    _activeDownloads[url] = completer.future;

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode >= 400) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final tempFile = File(
        '${file.path}.tmp_${DateTime.now().millisecondsSinceEpoch}',
      );
      final sink = tempFile.openWrite();

      int bytesReceived = 0;
      await response.stream.listen((chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress((bytesReceived / contentLength).clamp(0.0, 1.0));
        }
      }).asFuture();

      await sink.flush();
      await sink.close();
      client.close();

      if (await tempFile.length() < 1024) {
        if (await tempFile.exists()) await tempFile.delete();
        throw Exception('Downloaded manuscript appears corrupted or incomplete');
      }

      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);

      onProgress?.call(1.0);
      completer.complete(file);
      return file;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _activeDownloads.remove(url);
    }
  }

  Future<File> _getCacheFile(String url, {dynamic pubId}) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/bsci_pdf_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final safeName = pubId != null
        ? 'journal_pub_$pubId.pdf'
        : 'journal_hash_${url.hashCode.abs()}.pdf';
    return File('${cacheDir.path}/$safeName');
  }
}

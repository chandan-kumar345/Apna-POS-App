import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../network/api_endpoints.dart';

class YouTubeService {
  static final Map<String, Video?> _videoDetailsCache = {};
  static final Map<String, Future<String?>> _inFlightDownloads = {};
  static Directory? _cacheDir;

  static final RegExp _ytRegex = RegExp(
    r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/|live\/))([\w-]{11})',
    caseSensitive: false,
  );

  /// Checks if the provided URL is a YouTube video URL
  static bool isYouTubeUrl(String url) {
    if (url.trim().isEmpty) return false;
    return _ytRegex.hasMatch(url.trim());
  }

  /// Extracts the 11-character YouTube video ID from various link formats
  static String? extractVideoId(String url) {
    if (url.trim().isEmpty) return null;
    final match = _ytRegex.firstMatch(url.trim());
    return match?.group(1);
  }

  /// Get standard high-quality YouTube thumbnail URL
  static String getThumbnailUrl(String videoId) {
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  /// Get max resolution YouTube thumbnail URL
  static String getMaxResThumbnailUrl(String videoId) {
    return 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
  }

  /// Ensures and returns the video cache directory
  static Future<Directory?> _getVideoCacheDir() async {
    if (_cacheDir != null && _cacheDir!.existsSync()) {
      return _cacheDir;
    }
    if (kIsWeb) return null;
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory('${tempDir.path}${Platform.pathSeparator}apna_pos_video_cache');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _cacheDir = dir;
      return dir;
    } catch (e) {
      debugPrint('[YouTubeService] Error getting cache directory: $e');
      return null;
    }
  }

  /// Fetches video details (title, description, duration, thumbnails)
  static Future<Video?> getVideoDetails(String urlOrId) async {
    final videoId = isYouTubeUrl(urlOrId) ? extractVideoId(urlOrId) : urlOrId;
    if (videoId == null || videoId.isEmpty) return null;

    if (_videoDetailsCache.containsKey(videoId)) {
      return _videoDetailsCache[videoId];
    }

    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(videoId);
      _videoDetailsCache[videoId] = video;
      return video;
    } catch (e) {
      debugPrint('[YouTubeService] Error getting video details for $videoId: $e');
      return null;
    } finally {
      yt.close();
    }
  }

  static final Map<String, ({String url, DateTime timestamp})> _streamCache = {};

  /// Optimal Stream Selection: Selects 360p or 480p or 720p MP4 stream for instant loading & smooth 60fps playback
  static StreamInfo? _pickOptimalStream(StreamManifest manifest) {
    // 1. MP4 muxed stream (video + audio)
    final mp4Muxed = manifest.muxed
        .where((s) => s.container == StreamContainer.mp4 || s.codec.mimeType.contains('mp4'))
        .toList();

    if (mp4Muxed.isNotEmpty) {
      // Look for 480p, 360p, or 720p (avoids 1080p/4K massive bitrates that stall mobile devices)
      final p480 = mp4Muxed.where((s) => s.videoResolution.height == 480 || s.videoQuality.name.contains('480')).firstOrNull;
      if (p480 != null) return p480;

      final p360 = mp4Muxed.where((s) => s.videoResolution.height == 360 || s.videoQuality.name.contains('360')).firstOrNull;
      if (p360 != null) return p360;

      final p720 = mp4Muxed.where((s) => s.videoResolution.height == 720 || s.videoQuality.name.contains('720')).firstOrNull;
      if (p720 != null) return p720;

      // Or lowest bitrate muxed stream (< 1.5 Mbps) for instant start
      mp4Muxed.sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
      return mp4Muxed.first;
    }

    // 2. MP4 video-only stream (fast, crisp, perfect for muted POS dish playback)
    final mp4Video = manifest.videoOnly
        .where((s) => s.container == StreamContainer.mp4 || s.codec.mimeType.contains('mp4'))
        .toList();

    if (mp4Video.isNotEmpty) {
      final p480 = mp4Video.where((s) => s.videoResolution.height == 480 || s.videoQuality.name.contains('480')).firstOrNull;
      if (p480 != null) return p480;

      final p360 = mp4Video.where((s) => s.videoResolution.height == 360 || s.videoQuality.name.contains('360')).firstOrNull;
      if (p360 != null) return p360;

      final p720 = mp4Video.where((s) => s.videoResolution.height == 720 || s.videoQuality.name.contains('720')).firstOrNull;
      if (p720 != null) return p720;

      mp4Video.sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
      return mp4Video.first;
    }

    // 3. Fallback to any muxed or video-only stream
    return manifest.muxed.firstOrNull ?? manifest.videoOnly.firstOrNull;
  }

  /// Resolves direct progressive/muxed MP4 stream URL
  static Future<String?> resolveStreamUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;

    if (!isYouTubeUrl(cleanUrl)) {
      return ApiEndpoints.resolveMediaUrl(cleanUrl);
    }

    final videoId = extractVideoId(cleanUrl);
    if (videoId == null || videoId.isEmpty) {
      return cleanUrl;
    }

    if (_streamCache.containsKey(videoId)) {
      final entry = _streamCache[videoId]!;
      if (DateTime.now().difference(entry.timestamp).inHours < 4) {
        return entry.url;
      } else {
        _streamCache.remove(videoId);
      }
    }

    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final selectedStream = _pickOptimalStream(manifest);

      if (selectedStream != null) {
        final streamUrl = selectedStream.url.toString();
        _streamCache[videoId] = (url: streamUrl, timestamp: DateTime.now());
        return streamUrl;
      }
    } catch (e) {
      debugPrint('[YouTubeService] Error extracting stream for $videoId: $e');
    } finally {
      yt.close();
    }

    return null;
  }

  /// Downloads & caches video streams locally so they play seamlessly on Windows & Android without
  /// rate limits, network stutter, or buffering delay.
  /// Returns a validated local file path or instant progressive stream URL.
  static Future<String?> getPlayableVideoPath(String rawUrl, {bool instantStream = true}) async {
    var cleanUrl = rawUrl.trim();
    if (cleanUrl.isEmpty) return null;

    if (cleanUrl.startsWith('"') && cleanUrl.endsWith('"')) {
      cleanUrl = cleanUrl.substring(1, cleanUrl.length - 1).trim();
    }
    if (cleanUrl.startsWith("'") && cleanUrl.endsWith("'")) {
      cleanUrl = cleanUrl.substring(1, cleanUrl.length - 1).trim();
    }

    // 1. Asset video
    if (cleanUrl.startsWith('assets/')) {
      return cleanUrl;
    }

    // 2. Direct local file on disk
    if (!kIsWeb) {
      String localPath = cleanUrl;
      if (localPath.startsWith('file://')) {
        try {
          localPath = Uri.parse(localPath).toFilePath();
        } catch (_) {
          localPath = localPath.replaceFirst('file://', '');
        }
      }
      try {
        final decoded = Uri.decodeFull(localPath);
        final f = File(decoded);
        if (f.existsSync() && f.lengthSync() > 0) {
          return f.absolute.path;
        }
      } catch (_) {}

      try {
        final f = File(localPath);
        if (f.existsSync() && f.lengthSync() > 0) {
          return f.absolute.path;
        }
      } catch (_) {}

      // Check persistent gallery videos directory
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final rawFileName = cleanUrl.split(Platform.pathSeparator).last.split('/').last.split('?').first;
        if (rawFileName.isNotEmpty) {
          final localSaved = File('${appDir.path}${Platform.pathSeparator}saved_product_videos${Platform.pathSeparator}$rawFileName');
          if (localSaved.existsSync() && localSaved.lengthSync() > 0) {
            return localSaved.absolute.path;
          }
        }
      } catch (_) {}

      // Check relative/backend upload path on local machine (e.g. /uploads/products/videos/...)
      try {
        if (cleanUrl.contains('uploads/')) {
          final afterUploads = cleanUrl.substring(cleanUrl.indexOf('uploads/'));
          final cleanRelative = afterUploads.split('?').first;
          final candidatePaths = [
            'backend/public/$cleanRelative',
            '../backend/public/$cleanRelative',
            '${Directory.current.path}/backend/public/$cleanRelative',
          ];
          for (final cPath in candidatePaths) {
            final bFile = File(cPath);
            if (bFile.existsSync() && bFile.lengthSync() > 0) {
              return bFile.absolute.path;
            }
          }
        }
      } catch (_) {}
    }

    // 3. YouTube Video (Instant progressive streaming + background disk caching)
    if (isYouTubeUrl(cleanUrl)) {
      final videoId = extractVideoId(cleanUrl);
      if (videoId == null || videoId.isEmpty) return null;

      final cacheDir = await _getVideoCacheDir();
      if (cacheDir != null) {
        final targetFile = File('${cacheDir.path}${Platform.pathSeparator}yt_$videoId.mp4');
        if (targetFile.existsSync() && targetFile.lengthSync() > 1000) {
          return targetFile.path;
        }

        // Kick off lightweight background download for subsequent offline / 0ms plays
        if (!_inFlightDownloads.containsKey(videoId)) {
          _inFlightDownloads[videoId] = _downloadYouTubeVideo(videoId, targetFile);
        }
      }

      // Fast-path: Return progressive stream URL immediately (zero startup wait)
      if (instantStream) {
        final streamUrl = await resolveStreamUrl(cleanUrl);
        if (streamUrl != null && streamUrl.isNotEmpty) {
          return streamUrl;
        }
      }

      // Fallback: wait for background download to complete
      if (cacheDir != null && _inFlightDownloads.containsKey(videoId)) {
        try {
          return await _inFlightDownloads[videoId];
        } finally {
          _inFlightDownloads.remove(videoId);
        }
      }

      return resolveStreamUrl(cleanUrl);
    }

    // 4. Remote HTTP/HTTPS Video URL (Server uploads, S3, CDN)
    final resolvedUrl = ApiEndpoints.resolveMediaUrl(cleanUrl);
    if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://')) {
      if (kIsWeb) return resolvedUrl;

      final cacheDir = await _getVideoCacheDir();
      if (cacheDir != null) {
        final urlHash = resolvedUrl.hashCode.abs().toString();
        final targetFile = File('${cacheDir.path}${Platform.pathSeparator}remote_$urlHash.mp4');
        if (targetFile.existsSync() && targetFile.lengthSync() > 1000) {
          return targetFile.path;
        }

        if (!_inFlightDownloads.containsKey(urlHash)) {
          _inFlightDownloads[urlHash] = _downloadRemoteVideo(resolvedUrl, targetFile);
        }
      }

      // Return streaming URL immediately for instant start
      return resolvedUrl;
    }

    return cleanUrl;
  }

  static Future<String?> _downloadYouTubeVideo(String videoId, File targetFile) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final targetStream = _pickOptimalStream(manifest);

      if (targetStream == null) return null;

      final tempFile = File('${targetFile.path}.tmp');
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }

      final stream = yt.videos.streamsClient.get(targetStream);
      final sink = tempFile.openWrite();
      await stream.pipe(sink);
      await sink.flush();
      await sink.close();

      if (tempFile.existsSync() && tempFile.lengthSync() > 1000) {
        if (targetFile.existsSync()) {
          try {
            targetFile.deleteSync();
          } catch (_) {}
        }
        await tempFile.rename(targetFile.path);
        debugPrint('[YouTubeService] Cached video saved: ${targetFile.path} (${(targetFile.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB)');
        return targetFile.path;
      }
    } catch (e) {
      debugPrint('[YouTubeService] Error downloading YouTube video ($videoId): $e');
    } finally {
      yt.close();
    }
    return null;
  }

  static Future<String?> _downloadRemoteVideo(String remoteUrl, File targetFile) async {
    try {
      var fetchUrl = remoteUrl;
      if (!kIsWeb && Platform.isWindows && fetchUrl.contains('localhost:')) {
        fetchUrl = fetchUrl.replaceAll('localhost:', '127.0.0.1:');
      }

      final tempFile = File('${targetFile.path}.tmp');
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }

      final uri = Uri.parse(fetchUrl);
      final request = http.Request('GET', uri);
      request.headers['Bypass-Tunnel-Reminder'] = 'true';
      request.headers['Accept'] = 'video/mp4,video/*,*/*';

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final sink = tempFile.openWrite();
        await streamedResponse.stream.pipe(sink);
        await sink.flush();
        await sink.close();

        if (tempFile.existsSync() && tempFile.lengthSync() > 0) {
          if (targetFile.existsSync()) {
            try {
              targetFile.deleteSync();
            } catch (_) {}
          }
          await tempFile.rename(targetFile.path);
          debugPrint('[YouTubeService] Cached remote video saved: ${targetFile.path}');
          return targetFile.path;
        }
      }
    } catch (e) {
      debugPrint('[YouTubeService] Error caching remote video ($remoteUrl): $e');
    }
    return null;
  }
}

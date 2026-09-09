import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  static final Map<String, Video?> _videoDetailsCache = {};

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

  /// Resolves direct progressive/muxed MP4 stream URL playable in VideoPlayerController
  static Future<String?> resolveStreamUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;

    // If it's not YouTube, return original URL directly
    if (!isYouTubeUrl(cleanUrl)) {
      return cleanUrl;
    }

    final videoId = extractVideoId(cleanUrl);
    if (videoId == null || videoId.isEmpty) {
      return cleanUrl;
    }

    // Check cache (valid for 3 hours)
    if (_streamCache.containsKey(videoId)) {
      final entry = _streamCache[videoId]!;
      if (DateTime.now().difference(entry.timestamp).inHours < 3) {
        return entry.url;
      } else {
        _streamCache.remove(videoId);
      }
    }

    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      StreamInfo? selectedStream;

      // 1. Prioritize MP4 muxed stream (video + audio) for native Windows MF / Android playback
      final mp4Muxed = manifest.muxed
          .where((s) => s.container == StreamContainer.mp4 || s.codec.mimeType.contains('mp4'))
          .toList();
      if (mp4Muxed.isNotEmpty) {
        selectedStream = mp4Muxed.withHighestBitrate();
      }

      // 2. If no MP4 muxed, use MP4 video-only stream (perfect for muted POS dish playback)
      if (selectedStream == null && manifest.videoOnly.isNotEmpty) {
        final mp4Video = manifest.videoOnly
            .where((s) => s.container == StreamContainer.mp4 || s.codec.mimeType.contains('mp4'))
            .toList();
        if (mp4Video.isNotEmpty) {
          selectedStream = mp4Video.withHighestBitrate();
        }
      }

      // 3. Fallback to any muxed or video-only stream
      selectedStream ??= manifest.muxed.isNotEmpty
          ? manifest.muxed.withHighestBitrate()
          : (manifest.videoOnly.isNotEmpty ? manifest.videoOnly.withHighestBitrate() : null);

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
}

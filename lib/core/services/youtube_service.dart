import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  static final Map<String, String> _streamUrlCache = {};
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

    if (_streamUrlCache.containsKey(videoId)) {
      return _streamUrlCache[videoId];
    }

    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      // Prefer muxed streams (both video + audio) with highest bitrate or 720p/480p/360p for fast POS card streaming
      StreamInfo? selectedStream;
      if (manifest.muxed.isNotEmpty) {
        selectedStream = manifest.muxed.withHighestBitrate();
      } else if (manifest.videoOnly.isNotEmpty) {
        selectedStream = manifest.videoOnly.withHighestBitrate();
      }

      if (selectedStream != null) {
        final streamUrl = selectedStream.url.toString();
        _streamUrlCache[videoId] = streamUrl;
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

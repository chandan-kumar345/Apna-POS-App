import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_win/video_player_win.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/youtube_service.dart';

/// A high-performance media widget for POS product cards and dish listings.
/// Supports:
/// 1. Sequential Video -> Image auto-slide playback (Plays video first, then transitions to auto-sliding images, then loops)
/// 2. Video-only playback (muted looping)
/// 3. Multi-image auto-sliding carousel (with staggered timer and indicator dots)
/// 4. Single static image or emoji fallback
class PosProductMediaBox extends StatefulWidget {
  final MenuItemModel item;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool showDots;
  final bool isMini;
  final VoidCallback? onTap;

  const PosProductMediaBox({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.showDots = true,
    this.isMini = false,
    this.onTap,
  });

  @override
  State<PosProductMediaBox> createState() => _PosProductMediaBoxState();
}

class _PosProductMediaBoxState extends State<PosProductMediaBox> {
  // Video Player State
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoError = false;

  // Carousel & Sequencing State
  // Mode: 0 = Showing Video, 1 = Showing Images
  int _activeMode = 0; // 0 = video, 1 = images
  int _currentImageIndex = 0;
  Timer? _imageSlideTimer;
  Timer? _staggerTimer;
  PageController? _pageController;
  bool _hasBothVideoAndImages = false;

  List<String> _resolvedImages = [];
  String _resolvedVideoUrl = '';

  @override
  void initState() {
    super.initState();
    _extractMedia();
    _initializePlayback();
  }

  @override
  void didUpdateWidget(covariant PosProductMediaBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.videoUrl != widget.item.videoUrl ||
        oldWidget.item.imageUrl != widget.item.imageUrl ||
        oldWidget.item.images.length != widget.item.images.length ||
        oldWidget.item.id != widget.item.id) {
      _cleanupControllers();
      _extractMedia();
      _initializePlayback();
    }
  }

  void _extractMedia() {
    // 1. Resolve image list
    final List<String> list = [];
    if (widget.item.images.isNotEmpty) {
      for (final img in widget.item.images) {
        final resolved = ApiEndpoints.resolveMediaUrl(img);
        if (resolved.isNotEmpty && !list.contains(resolved)) {
          list.add(resolved);
        }
      }
    }
    if (widget.item.imageUrl.trim().isNotEmpty) {
      final primary = ApiEndpoints.resolveMediaUrl(widget.item.imageUrl.trim());
      if (primary.isNotEmpty && !list.contains(primary)) {
        list.insert(0, primary);
      }
    }
    _resolvedImages = list;

    // 2. Resolve video URL
    final rawVideo = widget.item.videoUrl.trim();
    _resolvedVideoUrl = YouTubeService.isYouTubeUrl(rawVideo)
        ? rawVideo
        : ApiEndpoints.resolveMediaUrl(rawVideo);

    // 3. If no image exists but YouTube URL exists, auto-fallback to YouTube thumbnail
    if (_resolvedImages.isEmpty &&
        _resolvedVideoUrl.isNotEmpty &&
        YouTubeService.isYouTubeUrl(_resolvedVideoUrl)) {
      final videoId = YouTubeService.extractVideoId(_resolvedVideoUrl);
      if (videoId != null && videoId.isNotEmpty) {
        _resolvedImages = [YouTubeService.getThumbnailUrl(videoId)];
      }
    }

    _hasBothVideoAndImages = _resolvedVideoUrl.isNotEmpty && _resolvedImages.isNotEmpty;
  }

  void _initializePlayback() {
    _currentImageIndex = 0;
    _pageController?.dispose();
    if (_resolvedImages.length > 1) {
      _pageController = PageController(initialPage: 0);
    } else {
      _pageController = null;
    }

    if (_resolvedVideoUrl.isNotEmpty) {
      // Start with Video playback
      _activeMode = 0;
      _initVideoPlayer();
    } else if (_resolvedImages.length > 1) {
      // No video, start image carousel
      _activeMode = 1;
      _startImageCarousel();
    } else {
      // 0 or 1 image
      _activeMode = 1;
    }
  }

  Future<void> _initVideoPlayer() async {
    if (_resolvedVideoUrl.isEmpty) return;

    if (!kIsWeb && Platform.isWindows) {
      try {
        WindowsVideoPlayer.registerWith();
      } catch (_) {}
    }

    try {
      String streamTarget = _resolvedVideoUrl;
      if (YouTubeService.isYouTubeUrl(_resolvedVideoUrl)) {
        final resolved = await YouTubeService.resolveStreamUrl(_resolvedVideoUrl);
        if (resolved != null && resolved.isNotEmpty) {
          streamTarget = resolved;
        }
      } else {
        streamTarget = ApiEndpoints.resolveMediaUrl(_resolvedVideoUrl);
      }

      // Windows Media Foundation IPv4 fix: replace localhost with 127.0.0.1
      if (streamTarget.contains('localhost:')) {
        streamTarget = streamTarget.replaceAll('localhost:', '127.0.0.1:');
      }

      if (!mounted) return;

      bool isLocalFile = false;
      if (!kIsWeb) {
        try {
          if (File(streamTarget).existsSync()) {
            isLocalFile = true;
          }
        } catch (_) {}
      }

      if (isLocalFile) {
        _videoController = VideoPlayerController.file(
          File(streamTarget),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        final uri = Uri.tryParse(streamTarget);
        if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
          _videoController = VideoPlayerController.networkUrl(
            uri,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        } else {
          _videoController = VideoPlayerController.file(
            File(streamTarget),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        }
      }

      await _videoController!.initialize();
      if (!mounted) {
        _videoController?.dispose();
        return;
      }

      // Mute for auto-play inside grid cards (required for browser and OS autoplay)
      await _videoController!.setVolume(0.0);

      if (_hasBothVideoAndImages) {
        // Non-looping: listen for completion to switch to images
        await _videoController!.setLooping(false);
      } else {
        // Video only: loop indefinitely
        await _videoController!.setLooping(true);
      }
      _videoController!.addListener(_videoListener);

      await _videoController!.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoError = false;
        });
      }
    } catch (e) {
      debugPrint('[PosProductMediaBox] Video init error (${widget.item.name}): $e');
      if (mounted) {
        setState(() {
          _isVideoError = true;
          _isVideoInitialized = false;
          _activeMode = 1; // Fallback to images
        });
        if (_resolvedImages.length > 1) {
          _startImageCarousel();
        }
      }
    }
  }

  void _videoListener() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;

    final val = _videoController!.value;
    if (val.hasError) {
      debugPrint('[PosProductMediaBox] Video playback error: ${val.errorDescription}');
      if (mounted && _activeMode == 0) {
        setState(() {
          _isVideoError = true;
          _activeMode = 1;
        });
        if (_resolvedImages.length > 1) {
          _startImageCarousel();
        }
      }
      return;
    }

    // Check if video reached its end
    if (val.isCompleted ||
        (val.duration > Duration.zero && val.position >= val.duration - const Duration(milliseconds: 250))) {
      // Transition from Video to Images!
      _onVideoFinished();
    }
  }

  void _onVideoFinished() {
    if (!mounted || !_hasBothVideoAndImages) return;

    _videoController?.pause();
    setState(() {
      _activeMode = 1; // Switch to images mode
      _currentImageIndex = 0;
    });

    if (_pageController != null && _pageController!.hasClients) {
      _pageController!.jumpToPage(0);
    }

    // Start auto-slide through images
    _startImageCarousel(isSequentialFromVideo: true);
  }

  void _startImageCarousel({bool isSequentialFromVideo = false}) {
    _imageSlideTimer?.cancel();
    _staggerTimer?.cancel();

    if (_resolvedImages.length <= 1) return;

    // Fast initial start (0ms if from video, otherwise 200-600ms)
    final int staggerMs = isSequentialFromVideo ? 0 : ((widget.item.id.hashCode.abs() % 400) + 150);

    _staggerTimer = Timer(Duration(milliseconds: staggerMs), () {
      if (!mounted) return;
      // Fast snappy interval (2.0s per slide)
      _imageSlideTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
        if (!mounted) return;

        if (_currentImageIndex + 1 < _resolvedImages.length) {
          _currentImageIndex++;
          if (_pageController != null && _pageController!.hasClients) {
            _pageController!.animateToPage(
              _currentImageIndex,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
            );
          } else {
            setState(() {});
          }
        } else {
          // Reached last image!
          if (_hasBothVideoAndImages && _videoController != null && _isVideoInitialized) {
            // Loop back to video
            timer.cancel();
            setState(() {
              _activeMode = 0; // Switch to video
              _currentImageIndex = 0;
            });
            _videoController!.seekTo(Duration.zero);
            _videoController!.play();
          } else {
            // Loop back to first image smoothly
            _currentImageIndex = 0;
            if (_pageController != null && _pageController!.hasClients) {
              _pageController!.animateToPage(
                0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
              );
            } else {
              setState(() {});
            }
          }
        }
      });
    });
  }

  void _cleanupControllers() {
    _imageSlideTimer?.cancel();
    _staggerTimer?.cancel();
    _pageController?.dispose();
    _pageController = null;
    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      _videoController!.dispose();
      _videoController = null;
    }
    _isVideoInitialized = false;
    _isVideoError = false;
  }

  @override
  void dispose() {
    _cleanupControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_activeMode == 0 && _isVideoInitialized && _videoController != null && !_isVideoError) {
      // 1. Render Video with hardware-accelerated FittedBox
      final size = _videoController!.value.size;
      final double vWidth = size.width > 0 ? size.width : 160;
      final double vHeight = size.height > 0 ? size.height : 100;

      content = Stack(
        fit: StackFit.expand,
        children: [
          // Background fallback image while video loads/buffers
          if (_resolvedImages.isNotEmpty)
            _buildSingleImage(_resolvedImages.first),
          SizedBox.expand(
            child: FittedBox(
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: vWidth,
                height: vHeight,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
        ],
      );
    } else if (_resolvedImages.isNotEmpty) {
      // 2. Render Image (Single or Multi-image Slide PageView)
      if (_resolvedImages.length > 1) {
        content = Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _resolvedImages.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final imagePath = _resolvedImages[index];
                return _buildSingleImage(imagePath, key: ValueKey('slide_${widget.item.id}_$index'));
              },
            ),
            // Multi-image slide indicator pill dots
            if (widget.showDots && !widget.isMini)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_resolvedImages.length, (index) {
                        final isSelected = index == _currentImageIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: isSelected ? 12 : 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
          ],
        );
      } else {
        // Single static image
        final String imagePath = _resolvedImages.first;
        content = _buildSingleImage(imagePath, key: ValueKey('single_${widget.item.id}'));
      }
    } else {
      // 3. Fallback Emoji
      content = _buildEmojiFallback();
    }

    if (widget.borderRadius != null) {
      content = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      child: content,
    );
  }

  Widget _buildSingleImage(String imagePath, {Key? key}) {
    final fallback = _buildEmojiFallback();
    final resolved = ApiEndpoints.resolveMediaUrl(imagePath);
    if (resolved.isEmpty) return fallback;

    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(
        resolved,
        key: key,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[PosProductMediaBox] Image network error for "$resolved": $error');
          // Try local fallback if original image was a local path
          if (!kIsWeb) {
            try {
              final file = File(imagePath);
              if (file.existsSync()) {
                return Image.file(
                  file,
                  key: key,
                  fit: widget.fit,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => fallback,
                );
              }
            } catch (_) {}
          }
          return fallback;
        },
      );
    } else if (!kIsWeb) {
      try {
        final file = File(resolved);
        if (file.existsSync()) {
          return Image.file(
            file,
            key: key,
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => fallback,
          );
        }
      } catch (_) {}
    }
    return fallback;
  }

  Widget _buildEmojiFallback() {
    final String fallbackEmoji =
        widget.item.emoji.trim().isNotEmpty ? widget.item.emoji.trim() : '🥘';
    return Center(
      child: Text(
        fallbackEmoji,
        style: TextStyle(fontSize: widget.isMini ? 18 : 26),
      ),
    );
  }
}

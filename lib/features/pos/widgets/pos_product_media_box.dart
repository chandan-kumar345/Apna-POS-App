import 'dart:async';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_win/video_player_win.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/youtube_service.dart';

/// Enum representing the type of media item in the product slide deck
enum PosMediaType { video, image, placeholder }

/// Data model representing an individual slide item
class PosMediaItem {
  final PosMediaType type;
  final String url;
  final String? previewThumbnail;
  final String? title;

  const PosMediaItem({
    required this.type,
    this.url = '',
    this.previewThumbnail,
    this.title,
  });
}

/// Custom ScrollBehavior enabling mouse-drag and touch-drag across Android and Windows
class PosMediaScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Internal client interface for coordinating global video decoder slots
abstract class _PosPlaybackClient {
  void onPlaybackSlotRevoked();
}

/// Global Playback Coordinator to enforce strict hardware video decoder limits.
/// Android/iOS hardware video decoders (MediaCodec / Codec2) have strict hardware instance
/// and surface buffer pool limits. This coordinator ensures at most 1 decoder on mobile
/// and 2 decoders on desktop/web are active simultaneously, automatically disposing
/// inactive decoders to avoid GPU buffer timeouts and frame stutter.
class _PosMediaPlaybackCoordinator {
  static final _PosMediaPlaybackCoordinator instance = _PosMediaPlaybackCoordinator._();
  _PosMediaPlaybackCoordinator._();

  final List<_PosPlaybackClient> _activeClients = [];

  int get _maxActiveDecoders {
    if (kIsWeb) return 2;
    if (Platform.isAndroid || Platform.isIOS) return 1;
    return 2;
  }

  void acquireSlot(_PosPlaybackClient client) {
    if (!_activeClients.contains(client)) {
      _activeClients.add(client);
    }
    while (_activeClients.length > _maxActiveDecoders) {
      final evicted = _activeClients.removeAt(0);
      if (evicted != client) {
        evicted.onPlaybackSlotRevoked();
      }
    }
  }

  void releaseSlot(_PosPlaybackClient client) {
    _activeClients.remove(client);
  }
}

/// A high-performance mixed-media widget for POS product cards and dish listings.
/// Supports:
/// 1. Direct & YouTube video streaming with seamless auto-play for Android & Windows
/// 2. Mixed-media slide deck (Videos + Multiple Images)
/// 3. Interactive Touch Swipe (Android) & Mouse Drag (Windows)
/// 4. Interactive Pill Pagination Dots (tap-to-jump)
/// 5. Automatic pause/release on slide change to conserve system resources
/// 6. Graceful fallback to YouTube thumbnails, local images, or placeholder
class PosProductMediaBox extends StatefulWidget {
  final MenuItemModel item;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool showDots;
  final bool showArrows;
  final bool isMini;
  final bool autoSlide;
  final VoidCallback? onTap;

  const PosProductMediaBox({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.showDots = true,
    this.showArrows = false,
    this.isMini = false,
    this.autoSlide = true,
    this.onTap,
  });

  @override
  State<PosProductMediaBox> createState() => _PosProductMediaBoxState();
}

class _PosProductMediaBoxState extends State<PosProductMediaBox> implements _PosPlaybackClient {
  final List<PosMediaItem> _mediaList = [];
  PageController? _pageController;
  int _currentPage = 0;

  // Video Streaming State
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;
  bool _isVideoError = false;

  // Auto-Slide Timers
  Timer? _autoSlideTimer;
  Timer? _resumeAutoSlideTimer;
  bool _isUserInteracting = false;
  bool _isVideoFinishingSlide = false;

  @override
  void initState() {
    super.initState();
    _buildMediaList();
    _initController();
  }

  @override
  void didUpdateWidget(covariant PosProductMediaBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.videoUrl != widget.item.videoUrl ||
        oldWidget.item.imageUrl != widget.item.imageUrl ||
        oldWidget.item.images.length != widget.item.images.length ||
        oldWidget.item.id != widget.item.id) {
      _cleanup();
      _buildMediaList();
      _initController();
    }
  }

  @override
  void onPlaybackSlotRevoked() {
    _releaseVideoController();
  }

  void _releaseVideoController() {
    if (_videoController != null) {
      final ctrl = _videoController!;
      _videoController = null;
      try {
        ctrl.removeListener(_videoListener);
        ctrl.pause();
        ctrl.dispose();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isVideoInitialized = false;
        _isVideoLoading = false;
      });
    } else {
      _isVideoInitialized = false;
      _isVideoLoading = false;
    }
  }

  void _buildMediaList() {
    _mediaList.clear();

    final rawVideo = widget.item.videoUrl.trim();
    final hasVideo = rawVideo.isNotEmpty;

    // 1. Determine video thumbnail if available
    String? videoThumbnail;
    if (hasVideo) {
      if (YouTubeService.isYouTubeUrl(rawVideo)) {
        final videoId = YouTubeService.extractVideoId(rawVideo);
        if (videoId != null && videoId.isNotEmpty) {
          videoThumbnail = YouTubeService.getThumbnailUrl(videoId);
        }
      } else if (widget.item.imageUrl.trim().isNotEmpty) {
        videoThumbnail = ApiEndpoints.resolveMediaUrl(widget.item.imageUrl.trim());
      } else if (widget.item.images.isNotEmpty) {
        for (final img in widget.item.images) {
          final res = ApiEndpoints.resolveMediaUrl(img);
          if (res.isNotEmpty) {
            videoThumbnail = res;
            break;
          }
        }
      }
    }

    // 2. Add Video Item first if product has video
    if (hasVideo) {
      _mediaList.add(PosMediaItem(
        type: PosMediaType.video,
        url: rawVideo,
        previewThumbnail: videoThumbnail,
        title: 'Video Preview',
      ));
    }

    // 3. Add Multiple Images
    if (widget.item.images.isNotEmpty) {
      for (int i = 0; i < widget.item.images.length; i++) {
        final imgUrl = ApiEndpoints.resolveMediaUrl(widget.item.images[i].trim());
        if (imgUrl.isNotEmpty) {
          _mediaList.add(PosMediaItem(
            type: PosMediaType.image,
            url: imgUrl,
            title: 'Photo ${i + 1}',
          ));
        }
      }
    }

    // Add Primary Image if not already included
    if (widget.item.imageUrl.trim().isNotEmpty) {
      final primary = ApiEndpoints.resolveMediaUrl(widget.item.imageUrl.trim());
      if (primary.isNotEmpty && !_mediaList.any((m) => m.url == primary)) {
        _mediaList.add(PosMediaItem(
          type: PosMediaType.image,
          url: primary,
          title: 'Primary Photo',
        ));
      }
    }

    // 4. Fallback if no images or video
    if (_mediaList.isEmpty) {
      _mediaList.add(const PosMediaItem(
        type: PosMediaType.placeholder,
        url: '',
        title: 'Product',
      ));
    }
  }

  void _initController() {
    _currentPage = 0;
    _pageController?.dispose();
    if (_mediaList.length > 1) {
      _pageController = PageController(initialPage: 0);
    } else {
      _pageController = null;
    }

    // If initial slide is video, check if we should auto-start stream
    if (_mediaList.isNotEmpty && _mediaList[0].type == PosMediaType.video) {
      // Schedule stream initialization on demand
      if (!widget.isMini) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _currentPage == 0 && _mediaList.isNotEmpty && _mediaList[0].type == PosMediaType.video) {
            _requestAndInitVideoStream(_mediaList[0].url);
          }
        });
      }
    } else if (widget.autoSlide && _mediaList.length > 1 && !widget.isMini) {
      _scheduleAutoSlideForImages();
    }
  }

  void _requestAndInitVideoStream(String videoUrl) {
    _PosMediaPlaybackCoordinator.instance.acquireSlot(this);
    _initVideoStream(videoUrl);
  }

  Future<void> _initVideoStream(String videoUrl) async {
    if (_videoController != null || _isVideoLoading) return;
    var cleanUrl = videoUrl.trim();
    if (cleanUrl.isEmpty) return;

    if (cleanUrl.startsWith('"') && cleanUrl.endsWith('"')) {
      cleanUrl = cleanUrl.substring(1, cleanUrl.length - 1).trim();
    }
    if (cleanUrl.startsWith("'") && cleanUrl.endsWith("'")) {
      cleanUrl = cleanUrl.substring(1, cleanUrl.length - 1).trim();
    }

    _isVideoLoading = true;
    _isVideoError = false;

    if (!kIsWeb && Platform.isWindows) {
      try {
        WindowsVideoPlayer.registerWith();
      } catch (e) {
        debugPrint('[PosProductMediaBox] WindowsVideoPlayer init: $e');
      }
    }

    try {
      final playablePath = await YouTubeService.getPlayableVideoPath(cleanUrl, instantStream: true);
      if (playablePath == null || playablePath.isEmpty) {
        throw Exception('Could not resolve playable video path for $cleanUrl');
      }

      if (!mounted) {
        _isVideoLoading = false;
        return;
      }

      VideoPlayerController controller;

      if (!kIsWeb && File(playablePath).existsSync()) {
        controller = VideoPlayerController.file(
          File(playablePath),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else if (playablePath.startsWith('assets/')) {
        controller = VideoPlayerController.asset(
          playablePath,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else if (playablePath.startsWith('http://') || playablePath.startsWith('https://')) {
        var netUrl = playablePath;
        if (!kIsWeb && Platform.isWindows && netUrl.contains('localhost:')) {
          netUrl = netUrl.replaceAll('localhost:', '127.0.0.1:');
        }
        controller = VideoPlayerController.networkUrl(
          Uri.parse(netUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          httpHeaders: const {
            'Accept': 'video/mp4,video/*,*/*',
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          },
        );
      } else {
        controller = VideoPlayerController.file(
          File(playablePath),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }

      await controller.initialize();
      await controller.setVolume(0.0);

      final shouldLoop = _mediaList.length <= 1 || !widget.autoSlide;
      await controller.setLooping(shouldLoop);

      if (!mounted) {
        controller.dispose();
        return;
      }

      _videoController = controller;
      _videoController!.addListener(_videoListener);

      // Auto-play immediately if active slide is currently on Video
      if (_mediaList.isNotEmpty && _currentPage < _mediaList.length && _mediaList[_currentPage].type == PosMediaType.video) {
        try {
          await _videoController!.play();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
          _isVideoError = false;
        });
      }
    } catch (e) {
      debugPrint('[PosProductMediaBox] Video stream error (${widget.item.name}): $e');
      if (mounted) {
        setState(() {
          _isVideoError = true;
          _isVideoLoading = false;
          _isVideoInitialized = false;
        });
        if (_mediaList.length > 1) {
          _scheduleAutoSlideForImages();
        }
      }
    }
  }

  void _videoListener() {
    if (!mounted || _videoController == null || !_videoController!.value.isInitialized) return;

    final val = _videoController!.value;
    if (val.hasError) {
      debugPrint('[PosProductMediaBox] Video playback error: ${val.errorDescription}');
      if (!_isVideoError) {
        setState(() {
          _isVideoError = true;
        });
        if (_mediaList.length > 1) {
          _scheduleAutoSlideForImages();
        }
      }
      return;
    }

    // Detect when video has played fully from start to finish
    if (widget.autoSlide &&
        _mediaList.length > 1 &&
        !widget.isMini &&
        !_isUserInteracting &&
        !_isVideoFinishingSlide &&
        _mediaList.isNotEmpty &&
        _currentPage < _mediaList.length &&
        _mediaList[_currentPage].type == PosMediaType.video) {
      final position = val.position;
      final duration = val.duration;

      final bool hasActuallyPlayed = position > const Duration(milliseconds: 500);
      final bool reachedEnd = duration > const Duration(milliseconds: 500) &&
          position >= (duration - const Duration(milliseconds: 200));
      final bool isCompleted = val.isCompleted && hasActuallyPlayed;

      if (isCompleted || (hasActuallyPlayed && reachedEnd)) {
        _onVideoCompleted();
      }
    }
  }

  void _onVideoCompleted() {
    if (_isVideoFinishingSlide || !mounted || _mediaList.length <= 1 || _isUserInteracting) return;
    _isVideoFinishingSlide = true;

    // Small delay on final frame before sliding smoothly to next slide
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || _isUserInteracting || _mediaList.length <= 1) {
        _isVideoFinishingSlide = false;
        return;
      }
      final nextIndex = (_currentPage + 1) % _mediaList.length;
      if (_pageController != null && _pageController!.hasClients) {
        _pageController!.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 320),
          curve: Curves.fastOutSlowIn,
        );
      }
      _isVideoFinishingSlide = false;
    });
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() {
      _currentPage = index;
    });

    final currentMedia = _mediaList[index];
    if (currentMedia.type == PosMediaType.video) {
      _autoSlideTimer?.cancel();
      _isVideoFinishingSlide = false;
      _PosMediaPlaybackCoordinator.instance.acquireSlot(this);
      if (_videoController != null && _isVideoInitialized) {
        _videoController!.seekTo(Duration.zero).then((_) {
          if (mounted && _currentPage == index && _videoController != null) {
            _videoController!.play();
          }
        });
      } else if (!_isVideoLoading) {
        _initVideoStream(currentMedia.url);
      }
    } else {
      // Release video controller when viewing image slides to free up native decoders and GPU buffers
      _PosMediaPlaybackCoordinator.instance.releaseSlot(this);
      _releaseVideoController();
      if (widget.autoSlide && !_isUserInteracting && _mediaList.length > 1 && !widget.isMini) {
        _scheduleAutoSlideForImages();
      }
    }
  }

  void _scheduleAutoSlideForImages() {
    _autoSlideTimer?.cancel();
    if (_mediaList.length <= 1 || widget.isMini) return;

    // If currently on video slide, do NOT slide via timer; let the video play fully first!
    if (_currentPage < _mediaList.length && _mediaList[_currentPage].type == PosMediaType.video) return;

    _autoSlideTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted || _isUserInteracting || _mediaList.length <= 1) return;
      final nextIndex = (_currentPage + 1) % _mediaList.length;
      if (_pageController != null && _pageController!.hasClients) {
        _pageController!.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 320),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  void _pauseAutoSlideTemporarily() {
    _isUserInteracting = true;
    _autoSlideTimer?.cancel();
    _resumeAutoSlideTimer?.cancel();

    // Resume auto-slide after 5 seconds of idle inactivity
    _resumeAutoSlideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _isUserInteracting = false;
      if (_currentPage < _mediaList.length && _mediaList[_currentPage].type == PosMediaType.image) {
        _scheduleAutoSlideForImages();
      } else if (_currentPage < _mediaList.length &&
          _mediaList[_currentPage].type == PosMediaType.video &&
          _videoController != null &&
          _isVideoInitialized) {
        _videoController!.play();
      }
    });
  }

  void _cleanup() {
    _PosMediaPlaybackCoordinator.instance.releaseSlot(this);
    _autoSlideTimer?.cancel();
    _resumeAutoSlideTimer?.cancel();
    _pageController?.dispose();
    _pageController = null;
    if (_videoController != null) {
      final ctrl = _videoController!;
      _videoController = null;
      try {
        ctrl.removeListener(_videoListener);
        ctrl.dispose();
      } catch (_) {}
    }
    _isVideoInitialized = false;
    _isVideoLoading = false;
    _isVideoError = false;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_mediaList.isEmpty || _mediaList.first.type == PosMediaType.placeholder) {
      content = _buildPlaceholderFallback();
    } else if (_mediaList.length == 1) {
      // Single Item (Video or Image)
      content = _buildSlideItem(_mediaList.first, 0);
    } else {
      // Multi-Item Slide Deck (Videos + Images)
      content = Stack(
        fit: StackFit.expand,
        children: [
          // 1. Gesture-enabled PageView with Touch & Mouse Drag Support
          ScrollConfiguration(
            behavior: PosMediaScrollBehavior(),
            child: PageView.builder(
              controller: _pageController,
              itemCount: _mediaList.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return _buildSlideItem(_mediaList[index], index);
              },
            ),
          ),

          // 2. Slide Indicator Dots (Tap to jump directly to any slide)
          if (widget.showDots && !widget.isMini && _mediaList.length > 1)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_mediaList.length, (index) {
                      final isSelected = index == _currentPage;
                      final isVideo = _mediaList[index].type == PosMediaType.video;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _pauseAutoSlideTemporarily();
                          _pageController?.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: isSelected ? (isVideo ? 18 : 14) : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isVideo ? const Color(0xFF38BDF8) : Colors.white)
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
        ],
      );
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

  Widget _buildSlideItem(PosMediaItem mediaItem, int index) {
    if (mediaItem.type == PosMediaType.video) {
      return _buildVideoSlide(mediaItem);
    } else if (mediaItem.type == PosMediaType.image) {
      return _buildImageSlide(mediaItem.url, key: ValueKey('slide_img_${widget.item.id}_$index'));
    } else {
      return _buildPlaceholderFallback();
    }
  }

  Widget _buildVideoSlide(PosMediaItem mediaItem) {
    // Build guaranteed base thumbnail / dish photo
    // Even while video buffers or when video is not active, this guarantees 0 blank box
    String? thumb = mediaItem.previewThumbnail;
    if (thumb == null || thumb.isEmpty) {
      if (widget.item.imageUrl.trim().isNotEmpty) {
        thumb = ApiEndpoints.resolveMediaUrl(widget.item.imageUrl.trim());
      } else if (widget.item.images.isNotEmpty) {
        for (final img in widget.item.images) {
          final res = ApiEndpoints.resolveMediaUrl(img);
          if (res.isNotEmpty) {
            thumb = res;
            break;
          }
        }
      }
    }

    final Widget baseThumb = (thumb != null && thumb.isNotEmpty)
        ? _buildImageSlide(thumb, key: ValueKey('vid_thumb_${widget.item.id}'))
        : _buildPlaceholderFallback();

    // 1. If Video is initialized and ready
    if (_isVideoInitialized && _videoController != null && !_isVideoError) {
      // Auto-play if not already playing and not completed
      if (!_videoController!.value.isPlaying &&
          !_videoController!.value.isCompleted &&
          _mediaList.isNotEmpty &&
          _currentPage < _mediaList.length &&
          _mediaList[_currentPage].type == PosMediaType.video) {
        try {
          _videoController!.play();
        } catch (_) {}
      }

      final double vWidth = _videoController!.value.size.width > 0
          ? _videoController!.value.size.width
          : (_videoController!.value.aspectRatio > 0 ? _videoController!.value.aspectRatio * 200 : 320);
      final double vHeight = _videoController!.value.size.height > 0
          ? _videoController!.value.size.height
          : 200;

      return Stack(
        fit: StackFit.expand,
        children: [
          // Guaranteed background photo (underneath video)
          baseThumb,

          // Smooth High Quality Video Render
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
    }

    // 2. If Loading or Initializing: show preview thumbnail with subtle buffer indicator
    if (_isVideoLoading) {
      return Stack(
        fit: StackFit.expand,
        children: [
          baseThumb,
          Container(
            color: Colors.black.withValues(alpha: 0.12),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: Color(0xFF38BDF8),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return baseThumb;
  }

  Widget _buildImageSlide(String imagePath, {Key? key}) {
    final fallback = _buildPlaceholderFallback();
    final trimmed = imagePath.trim();
    if (trimmed.isEmpty) return fallback;

    // 1. Asset Image
    if (trimmed.startsWith('assets/')) {
      return Image.asset(
        trimmed,
        key: key,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    // 2. Resolve via ApiEndpoints
    final resolved = ApiEndpoints.resolveMediaUrl(trimmed);
    if (resolved.isEmpty) return fallback;

    // 3. Network URL
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(
        resolved,
        key: key,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[PosProductMediaBox] Image network load failed for "$resolved": $error');
          if (!kIsWeb) {
            try {
              final file = File(trimmed);
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
      // 4. Local File
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

  /// Package Box Placeholder Image when product has no images or image fails to load
  Widget _buildPlaceholderFallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF1F5F9),
      padding: EdgeInsets.all(widget.isMini ? 3.0 : 6.0),
      child: Center(
        child: Image.asset(
          'assets/images/product_placeholder.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.inventory_2_outlined,
              size: widget.isMini ? 18 : 32,
              color: const Color(0xFF94A3B8),
            );
          },
        ),
      ),
    );
  }
}

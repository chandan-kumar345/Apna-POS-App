import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/models/menu_item_model.dart';

class StorefrontVideoPlayerDialog extends StatefulWidget {
  final MenuItemModel item;
  final Color themeColor;

  const StorefrontVideoPlayerDialog({
    super.key,
    required this.item,
    this.themeColor = const Color(0xFFE65100),
  });

  static Future<void> show(BuildContext context, MenuItemModel item, {Color? themeColor}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => StorefrontVideoPlayerDialog(
        item: item,
        themeColor: themeColor ?? const Color(0xFFE65100),
      ),
    );
  }

  @override
  State<StorefrontVideoPlayerDialog> createState() => _StorefrontVideoPlayerDialogState();
}

class _StorefrontVideoPlayerDialogState extends State<StorefrontVideoPlayerDialog> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.item.videoUrl.trim();
    if (url.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      VideoPlayerController controller;
      if (!kIsWeb && File(url).existsSync()) {
        controller = VideoPlayerController.file(File(url));
      } else if (url.startsWith('assets/')) {
        controller = VideoPlayerController.asset(url);
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        controller = VideoPlayerController.file(File(url));
      }

      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[StorefrontVideoPlayerDialog] video load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close Icon and Title Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Video Viewport
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 380, minHeight: 220),
            color: Colors.black,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : _hasError
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 44),
                            SizedBox(height: 8),
                            Text('Video unavailable', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      )
                    : Center(
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio > 0
                              ? _controller!.value.aspectRatio
                              : 16 / 9,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
          ),

          // Bottom Controls Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                if (_controller != null && _controller!.value.isInitialized) ...[
                  IconButton(
                    icon: Icon(
                      _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_controller!.value.isPlaying) {
                          _controller!.pause();
                        } else {
                          _controller!.play();
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        _controller!.setVolume(_isMuted ? 0.0 : 1.0);
                      });
                    },
                  ),
                ],
                const Spacer(),
                Text(
                  '₹${widget.item.effectivePrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

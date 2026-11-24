import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/sound_service.dart';
import 'connection_status_badge.dart';

class GlassCompanyNameBadge extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;
  final bool hasDropdown;
  final bool isDropdownOpen;
  final bool isNeumorphic;
  final bool showConnectionStatus;

  const GlassCompanyNameBadge({
    super.key,
    required this.name,
    this.onTap,
    this.hasDropdown = false,
    this.isDropdownOpen = false,
    this.isNeumorphic = false,
    this.showConnectionStatus = true,
  });

  Widget _buildBadgeContent({
    required String displayName,
    required Color foregroundColor,
    List<Shadow>? textShadows,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showConnectionStatus) ...[
          const ConnectionStatusDot(size: 10.5),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            displayName,
            style: TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.w800,
              color: foregroundColor,
              letterSpacing: -0.2,
              shadows: textShadows,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasDropdown) ...[
          const SizedBox(width: 4),
          AnimatedRotation(
            turns: isDropdownOpen ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: foregroundColor,
              size: 18.5,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isNotEmpty ? name : 'My Business';
    final badgePadding = EdgeInsets.fromLTRB(
      showConnectionStatus ? 11.0 : (hasDropdown ? 12.0 : 14.0),
      7.0,
      hasDropdown ? 12.0 : 14.0,
      7.0,
    );

    return RepaintBoundary(
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                SoundService.playButtonClick();
                onTap!();
              },
        borderRadius: BorderRadius.circular(20),
        child: isNeumorphic
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: badgePadding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFFF7FAFD),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-2.0, -2.0),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Color(0xFFC0D2E6),
                      offset: Offset(2.0, 2.0),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: _buildBadgeContent(
                  displayName: displayName,
                  foregroundColor: const Color(0xFF0F2B48),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: badgePadding,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDropdownOpen
                            ? [
                                Colors.white.withValues(alpha: 0.32),
                                Colors.white.withValues(alpha: 0.16),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.22),
                                Colors.white.withValues(alpha: 0.08),
                              ],
                      ),
                      border: Border.all(
                        color: isDropdownOpen
                            ? const Color(0xFF60A5FA).withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.3),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00C2FF).withValues(alpha: isDropdownOpen ? 0.28 : 0.18),
                          blurRadius: isDropdownOpen ? 16 : 12,
                          spreadRadius: isDropdownOpen ? 2 : 1,
                        ),
                      ],
                    ),
                    child: _buildBadgeContent(
                      displayName: displayName,
                      foregroundColor: Colors.white,
                      textShadows: const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

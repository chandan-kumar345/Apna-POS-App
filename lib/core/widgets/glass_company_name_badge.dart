import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/sound_service.dart';

class GlassCompanyNameBadge extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;
  final bool hasDropdown;
  final bool isDropdownOpen;
  final bool isNeumorphic;

  const GlassCompanyNameBadge({
    super.key,
    required this.name,
    this.onTap,
    this.hasDropdown = false,
    this.isDropdownOpen = false,
    this.isNeumorphic = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isNotEmpty ? name : 'My Business';

    return InkWell(
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
              padding: EdgeInsets.symmetric(
                horizontal: hasDropdown ? 12 : 14,
                vertical: 7.0,
              ),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F2B48),
                        letterSpacing: -0.2,
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
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF0F2B48),
                        size: 18.5,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: hasDropdown ? 12 : 14,
                    vertical: 7.0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDropdownOpen
                          ? [
                              Colors.white.withOpacity(0.32),
                              Colors.white.withOpacity(0.16),
                            ]
                          : [
                              Colors.white.withOpacity(0.22),
                              Colors.white.withOpacity(0.08),
                            ],
                    ),
                    border: Border.all(
                      color: isDropdownOpen
                          ? const Color(0xFF60A5FA).withOpacity(0.6)
                          : Colors.white.withOpacity(0.3),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C2FF).withOpacity(isDropdownOpen ? 0.28 : 0.18),
                        blurRadius: isDropdownOpen ? 16 : 12,
                        spreadRadius: isDropdownOpen ? 2 : 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
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
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 18.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

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
      borderRadius: BorderRadius.circular(22),
      child: isNeumorphic
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: hasDropdown ? 14 : 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: const Color(0xFFF7FAFD),
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-2.5, -2.5),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Color(0xFFC0D2E6),
                    offset: Offset(2.5, 2.5),
                    blurRadius: 6,
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
                    const SizedBox(width: 5),
                    AnimatedRotation(
                      turns: isDropdownOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOutCubic,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF0F2B48),
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: hasDropdown ? 14 : 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
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
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C2FF).withOpacity(isDropdownOpen ? 0.28 : 0.18),
                        blurRadius: isDropdownOpen ? 20 : 16,
                        spreadRadius: isDropdownOpen ? 3 : 2,
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
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasDropdown) ...[
                        const SizedBox(width: 5),
                        AnimatedRotation(
                          turns: isDropdownOpen ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOutCubic,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 20,
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

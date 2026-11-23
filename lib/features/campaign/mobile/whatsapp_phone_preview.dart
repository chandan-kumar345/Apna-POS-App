import 'package:flutter/material.dart';

class WhatsAppPhonePreview extends StatelessWidget {
  final String businessName;
  final String messageBody;
  final String? headerText;
  final String? footerText;
  final List<String> buttons;
  final String time;
  final String? imageUrl;
  final String? avatarUrl;

  const WhatsAppPhonePreview({
    super.key,
    required this.businessName,
    required this.messageBody,
    this.headerText,
    this.footerText,
    this.buttons = const [],
    this.time = '11:30 AM',
    this.imageUrl,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      height: 560,
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Dark smartphone chassis
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: const Color(0xFF334155), width: 5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(33),
        child: Column(
          children: [
            // Status bar
            Container(
              height: 24,
              color: const Color(0xFF005C4B),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '9:41',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  // Camera notch dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.signal_cellular_alt_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.wifi_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Icon(
                        Icons.battery_full_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // WhatsApp App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: const Color(0xFF075E54),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  _buildAvatar(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF25D366),
                              size: 13,
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Business Account',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.call_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),

            // WhatsApp Chat Body (Wallpaper)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFEAE2),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date bubble
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Text(
                            'TODAY',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF556066),
                              fontFamily: 'Roboto',
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),

                      // WhatsApp message bubble
                      Container(
                        constraints: const BoxConstraints(maxWidth: 260),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7FFDB),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(14),
                            bottomLeft: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(14),
                            bottomLeft: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Campaign Image Header (User request: "and also show the image.")
                              if (imageUrl != null && imageUrl!.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  height: 140,
                                  child: _buildBubbleImage(imageUrl!),
                                ),

                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (headerText != null &&
                                        headerText!.isNotEmpty) ...[
                                      Text(
                                        headerText!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1E293B),
                                          fontFamily: 'Roboto',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      messageBody,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        height: 1.38,
                                        color: Color(0xFF111827),
                                        fontFamily: 'Roboto',
                                      ),
                                    ),
                                    if (footerText != null &&
                                        footerText!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        footerText!,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          color: Color(0xFF6B7280),
                                          fontFamily: 'Roboto',
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        const Spacer(),
                                        Text(
                                          time,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Color(0xFF64748B),
                                            fontFamily: 'Roboto',
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.done_all,
                                          color: Color(0xFF34B7F1),
                                          size: 13,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Quick reply buttons
                      if (buttons.isNotEmpty)
                        ...buttons.map(
                          (btn) => Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 260,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                btn,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0284C7),
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom input bar mockup
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              color: const Color(0xFFF0F2F5),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_emotions_outlined,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Message',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11.5,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                          Icon(
                            Icons.attach_file_rounded,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.camera_alt_rounded,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF00A884),
                    child: Icon(Icons.mic, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      if (avatarUrl!.startsWith('http')) {
        return CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage(avatarUrl!),
        );
      }
      return CircleAvatar(
        radius: 16,
        backgroundImage: AssetImage(avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFF1E293B),
      child: ClipOval(
        child: Image.asset(
          'assets/images/tpl_food_bogo_pizza.png',
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Text(
            businessName.isNotEmpty ? businessName[0].toUpperCase() : 'P',
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleImage(String url) {
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/tpl_food_bogo_pizza.png',
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFFFECE0),
        child: const Icon(
          Icons.local_pizza_rounded,
          color: Color(0xFFE65100),
          size: 32,
        ),
      ),
    );
  }
}

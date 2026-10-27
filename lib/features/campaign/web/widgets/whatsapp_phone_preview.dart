import 'package:flutter/material.dart';

class WhatsAppPhonePreview extends StatelessWidget {
  final String businessName;
  final String messageBody;
  final String? headerText;
  final String? footerText;
  final List<String> buttons;
  final String time;

  const WhatsAppPhonePreview({
    super.key,
    required this.businessName,
    required this.messageBody,
    this.headerText,
    this.footerText,
    this.buttons = const [],
    this.time = '11:30 AM',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      height: 480,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2428),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF33383B), width: 6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          children: [
            // Speaker / Camera notch bar
            Container(
              height: 20,
              color: const Color(0xFF0F172A),
              child: Center(
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            // WhatsApp App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: const Color(0xFF075E54),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFF95B1C),
                    child: Text(
                      businessName.isNotEmpty ? businessName[0].toUpperCase() : 'P',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.verified, color: Color(0xFF25D366), size: 12),
                          ],
                        ),
                        const Text(
                          'Business Account',
                          style: TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.videocam_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Icon(Icons.call_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 6),
                  const Icon(Icons.more_vert_rounded, color: Colors.white, size: 16),
                ],
              ),
            ),

            // Chat Body (WhatsApp chat wallpaper background)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFE5DDD5),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Date bubble
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4),
                            ],
                          ),
                          child: const Text(
                            'TODAY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF556066),
                            ),
                          ),
                        ),
                      ),

                      // WhatsApp message bubble
                      Container(
                        constraints: const BoxConstraints(maxWidth: 240),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCF8C6),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(0),
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (headerText != null && headerText!.isNotEmpty) ...[
                              Text(
                                headerText!,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              messageBody,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                color: Color(0xFF111827),
                              ),
                            ),
                            if (footerText != null && footerText!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                footerText!,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  time,
                                  style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.done_all, color: Color(0xFF34B7F1), size: 12),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Quick reply buttons if any
                      if (buttons.isNotEmpty)
                        ...buttons.map((btn) => Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 240,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 2),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  btn,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom input bar mockup
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: const Color(0xFFF0F2F5),
              child: Row(
                children: [
                  const Icon(Icons.emoji_emotions_outlined, color: Colors.grey, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerLeft,
                      child: const Text('Message', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFF00A884),
                    child: Icon(Icons.mic, color: Colors.white, size: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

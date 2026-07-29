import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import 'login_screen.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121318),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),

                  // 2x3 Grid of 3D Carved Inset Tiles with Colorful POS Icons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181920),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildCarvedTile(_build3dHeartIcon())),
                            const SizedBox(width: 14),
                            Expanded(child: _buildCarvedTile(_build3dPlusIcon())),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _buildCarvedTile(_build3dKitchenIcon())),
                            const SizedBox(width: 14),
                            Expanded(child: _buildCarvedTile(_build3dKdsIcon())),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _buildCarvedTile(_build3dChartIcon())),
                            const SizedBox(width: 14),
                            Expanded(child: _buildCarvedTile(_build3dSearchIcon())),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // "Apna POS" Branding Title (Script Style)
                  Center(
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFE0E7FF)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds),
                          child: const Text(
                            'Apna POS',
                            style: TextStyle(
                              fontFamily: 'Serif',
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Smart billing, kitchen KDS & restaurant analytics',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // "Let's get started" Vibrant Action Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, anim, secAnim) => const LoginScreen(),
                          transitionsBuilder: (context, anim, secAnim, child) {
                            return FadeTransition(opacity: anim, child: child);
                          },
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: const Color(0xFF2563EB).withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Let's get started",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarvedTile(Widget child) {
    return Container(
      height: 105,
      decoration: BoxDecoration(
        color: const Color(0xFF13141A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF22242E), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0C0D11),
            offset: Offset(3, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: Color(0xFF1E202A),
            offset: Offset(-2, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  // 3D Gradient Icon 1: Heart & Billing Spheres
  Widget _build3dHeartIcon() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: const Icon(Icons.favorite_rounded, size: 38, color: Colors.white),
    );
  }

  // 3D Gradient Icon 2: Plus / Add Order Cross
  Widget _build3dPlusIcon() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFF97316), Color(0xFFEC4899), Color(0xFF8B5CF6)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(bounds),
      child: const Icon(Icons.add_rounded, size: 44, color: Colors.white),
    );
  }

  // 3D Gradient Icon 3: Kitchen Ring / Dish Icon
  Widget _build3dKitchenIcon() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFFEC4899)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: const Icon(Icons.radio_button_checked_rounded, size: 40, color: Colors.white),
    );
  }

  // 3D Gradient Icon 4: KDS Speech / Ticket Icon
  Widget _build3dKdsIcon() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: const Icon(Icons.chat_bubble_rounded, size: 36, color: Colors.white),
    );
  }

  // 3D Gradient Icon 5: Sales Bar Chart Pills
  Widget _build3dChartIcon() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFF43F5E), Color(0xFFFB923C), Color(0xFFFBBF24)],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(bounds),
      child: const Icon(Icons.bar_chart_rounded, size: 40, color: Colors.white),
    );
  }

  // 3D Gradient Icon 6: Search Scanner Lens
  Widget _build3dSearchIcon() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: const Icon(Icons.search_rounded, size: 40, color: Colors.white),
    );
  }
}

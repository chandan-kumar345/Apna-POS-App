import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import 'signup_screen.dart';
import '../onboarding/restaurant_onboarding_screen.dart';
import '../dashboard/main_layout.dart';

// Country Code Item Model
class CountryCodeItem {
  final String flag;
  final String code; // e.g. "IN"
  final String dialCode; // e.g. "+91"
  final String name; // e.g. "India"

  const CountryCodeItem({
    required this.flag,
    required this.code,
    required this.dialCode,
    required this.name,
  });
}

// Complete Country Codes List with Flags
const List<CountryCodeItem> countryCodesList = [
  CountryCodeItem(flag: '🇮🇳', code: 'IN', dialCode: '+91', name: 'India'),
  CountryCodeItem(flag: '🇺🇸', code: 'US', dialCode: '+1', name: 'United States'),
  CountryCodeItem(flag: '🇬🇧', code: 'GB', dialCode: '+44', name: 'United Kingdom'),
  CountryCodeItem(flag: '🇦🇪', code: 'AE', dialCode: '+971', name: 'United Arab Emirates'),
  CountryCodeItem(flag: '🇸🇦', code: 'SA', dialCode: '+966', name: 'Saudi Arabia'),
  CountryCodeItem(flag: '🇨🇦', code: 'CA', dialCode: '+1', name: 'Canada'),
  CountryCodeItem(flag: '🇦🇺', code: 'AU', dialCode: '+61', name: 'Australia'),
  CountryCodeItem(flag: '🇸🇬', code: 'SG', dialCode: '+65', name: 'Singapore'),
  CountryCodeItem(flag: '🇩🇪', code: 'DE', dialCode: '+49', name: 'Germany'),
  CountryCodeItem(flag: '🇫🇷', code: 'FR', dialCode: '+33', name: 'France'),
  CountryCodeItem(flag: '🇯🇵', code: 'JP', dialCode: '+81', name: 'Japan'),
  CountryCodeItem(flag: '🇳🇵', code: 'NP', dialCode: '+977', name: 'Nepal'),
  CountryCodeItem(flag: '🇧🇩', code: 'BD', dialCode: '+880', name: 'Bangladesh'),
  CountryCodeItem(flag: '🇱🇰', code: 'LK', dialCode: '+94', name: 'Sri Lanka'),
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Empty text controllers (No prefilled default values)
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  CountryCodeItem _selectedCountry = countryCodesList[0]; // Default India 🇮🇳 IN +91

  int _selectedTab = 0; // 0 = Login, 1 = Register
  bool _isEmailLogin = false; // Default false: Phone Number login first!
  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  final db = DatabaseService();

  Future<void> _handleAuthAction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_selectedTab == 1) {
        if (mounted) {
          Navigator.push(
            context,
            SlideUpPageRoute(page: const SignupScreen()),
          );
        }
        return;
      }

      bool success = false;
      if (!_isEmailLogin) {
        // Phone Number Mode
        final phone = _phoneController.text.trim();
        if (phone.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter your mobile number';
            _isLoading = false;
          });
          return;
        }
        // Login user via phone
        success = await db.loginUser('owner@apnapos.com', '123456');
      } else {
        // Email & Password Mode
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        if (email.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter your email address';
            _isLoading = false;
          });
          return;
        }
        if (password.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter your password';
            _isLoading = false;
          });
          return;
        }
        success = await db.loginUser(email, password);
      }

      if (!mounted) return;

      if (success) {
        final rest = db.restaurant;
        if (rest != null && rest.isOnboarded) {
          Navigator.pushReplacement(
            context,
            SlideUpPageRoute(page: const MainLayout()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            SlideUpPageRoute(page: const RestaurantOnboardingScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid credentials. Please check your details.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Modal to Pick Country Code with Flag
  void _showCountryCodePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Country Code',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: countryCodesList.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Color(0xFFF1F5F9), height: 1),
                    itemBuilder: (context, index) {
                      final country = countryCodesList[index];
                      final isSelected = country.code == _selectedCountry.code;

                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Text(country.flag, style: const TextStyle(fontSize: 26)),
                        title: Text(
                          '${country.name} (${country.code})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        trailing: Text(
                          country.dialCode,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? GlassTheme.primaryBlue
                                : const Color(0xFF64748B),
                          ),
                        ),
                        onTap: () {
                          setState(() => _selectedCountry = country);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Google Account Chooser Modal
  void _showGoogleAccountPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _buildGoogleColoredIcon(size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      'Choose Google Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select an account to sign in to Apna POS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),

                // Logged-in Google Accounts list
                _buildGoogleAccountTile(
                  name: 'Apna POS Owner',
                  email: 'owner@apnapos.com',
                  avatarBg: const Color(0xFF0052FF),
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                _buildGoogleAccountTile(
                  name: 'Restaurant Manager',
                  email: 'admin@restaurant.com',
                  avatarBg: const Color(0xFF10B981),
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                _buildGoogleAccountTile(
                  name: 'Staff Account',
                  email: 'staff@apnapos.com',
                  avatarBg: const Color(0xFF8B5CF6),
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 1),

                // Add Another Account option
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.person_add_alt_1_rounded,
                        color: Color(0xFF475569), size: 20),
                  ),
                  title: const Text(
                    'Add another account',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _isEmailLogin = true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoogleAccountTile({
    required String name,
    required String email,
    required Color avatarBg,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: avatarBg,
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        email,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B),
        ),
      ),
      onTap: () async {
        Navigator.pop(context);
        setState(() => _isLoading = true);
        await db.loginUser(email, '123456');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          SlideUpPageRoute(page: const MainLayout()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040814),
      body: Stack(
        children: [
          // 1. Deep Midnight Background Gradient matching Theme
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.4),
                  radius: 1.25,
                  colors: [
                    Color(0x550052FF), // Logo Electric Blue Ambient Glow
                    Color(0xFF071126),
                    Color(0xFF03060F),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // 2. Main Layout (Sliding up from bottom)
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Circular Back Button
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 16),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Top Header Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedTab == 0
                            ? "Go ahead and set up\nyour account"
                            : "Create your new\nPOS account",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.25,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedTab == 0
                            ? "Sign in-up to enjoy the best managing experience"
                            : "Join Apna POS to manage your restaurant effortlessly",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 3. Bottom Rounded White Card Container
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(36),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 30,
                          offset: Offset(0, -10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Segmented Tab Pill (Login / Register)
                          Container(
                            height: 52,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedTab = 0),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: _selectedTab == 0
                                            ? Colors.white
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: _selectedTab == 0
                                            ? [
                                                const BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 8,
                                                  offset: Offset(0, 2),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: _selectedTab == 0
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedTab = 1);
                                      Navigator.push(
                                        context,
                                        SlideUpPageRoute(page: const SignupScreen()),
                                      );
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: _selectedTab == 1
                                            ? Colors.white
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: _selectedTab == 1
                                            ? [
                                                const BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 8,
                                                  offset: Offset(0, 2),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Register',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: _selectedTab == 1
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Error Banner
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Color(0xFFEF4444), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFFB91C1C),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 4. Form Input Fields with Smooth Fade Transition (AnimatedCrossFade)
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 300),
                            crossFadeState: !_isEmailLogin
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            firstChild: Column(
                              key: const ValueKey('phone_login_form'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Phone Number Input Pill (Exact Match with Reference Image media__1785507766664.png)
                                Container(
                                  height: 56,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: const Color(0xFF00C2FF), // Cyan/Teal border from image
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Clickable Country Selector (Flag + Code + DialCode + Dropdown)
                                      InkWell(
                                        onTap: _showCountryCodePicker,
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _selectedCountry.flag,
                                                style: const TextStyle(fontSize: 20),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _selectedCountry.code,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _selectedCountry.dialCode,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.keyboard_arrow_down_rounded,
                                                color: Color(0xFF94A3B8),
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Vertical Separator Line
                                      Container(
                                        height: 24,
                                        width: 1,
                                        margin: const EdgeInsets.symmetric(horizontal: 12),
                                        color: const Color(0xFFE2E8F0),
                                      ),

                                      // Phone Input Field
                                      Expanded(
                                        child: TextField(
                                          controller: _phoneController,
                                          keyboardType: TextInputType.phone,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'Mobile',
                                            hintStyle: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Color(0xFFCBD5E1),
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Right-aligned "Login with email" link (Exact Match with Reference Image)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() => _isEmailLogin = true);
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Login with email',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF00C2FF), // Matching cyan color
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            secondChild: Column(
                              key: const ValueKey('email_login_form'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Email Address Field
                                _buildInputCard(
                                  label: 'Email Address',
                                  hint: 'Enter email address',
                                  icon: Icons.mail_outline_rounded,
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                ),

                                const SizedBox(height: 16),

                                // Password Field
                                _buildInputCard(
                                  label: 'Password',
                                  hint: 'Enter password',
                                  icon: Icons.lock_outline_rounded,
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  suffixWidget: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(
                                          () => _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Right-aligned "Login with mobile" link
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() => _isEmailLogin = false);
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Login as OTP',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF00C2FF),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // LOGICAL UX RULE: Only show "Remember me" & "Forgot Password?" when in Email & Password mode!
                          if (_isEmailLogin) ...[
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: GlassTheme.primaryBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFCBD5E1),
                                          width: 1.5,
                                        ),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _rememberMe = val);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Remember me',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Password reset link sent to your email'),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: GlassTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Primary Action Button ("Continue" for Phone mode / "Login" for Email mode)
                          Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: GlassTheme.primaryButtonGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: GlassTheme.primaryBlue.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleAuthAction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      _selectedTab == 1
                                          ? 'Register Account'
                                          : (!_isEmailLogin ? 'Continue' : 'Login'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // "Or login with" Divider
                          Row(
                            children: const [
                              Expanded(
                                  child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Or login with',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              Expanded(
                                  child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Google Login Button (Full Width, Displays Account Selector Modal on Tap)
                          OutlinedButton(
                            onPressed: _showGoogleAccountPicker,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(
                                  color: Color(0xFFE2E8F0), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildGoogleColoredIcon(size: 22),
                                const SizedBox(width: 10),
                                const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for Input Field Cards
  Widget _buildInputCard({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? prefixWidget,
    Widget? suffixWidget,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: GlassTheme.primaryBlue, size: 22),
          const SizedBox(width: 12),
          if (prefixWidget != null) prefixWidget,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFCBD5E1),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          if (suffixWidget != null) suffixWidget,
        ],
      ),
    );
  }

  // Helper Widget for Google Colored Logo
  Widget _buildGoogleColoredIcon({double size = 20}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

// Custom Painter for Authentic Multi-color Google "G" Logo
class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);

    final Paint redPaint = Paint()..color = const Color(0xFFEA4335);
    final Paint yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final Paint greenPaint = Paint()..color = const Color(0xFF34A853);
    final Paint bluePaint = Paint()..color = const Color(0xFF4285F4);

    final double stroke = size.width * 0.22;
    final Rect rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);

    final Paint basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Red arc (Top)
    canvas.drawArc(rect, -0.7, 1.8, false, basePaint..color = redPaint.color);
    // Yellow arc (Left)
    canvas.drawArc(rect, 1.1, 1.1, false, basePaint..color = yellowPaint.color);
    // Green arc (Bottom)
    canvas.drawArc(rect, 2.2, 1.3, false, basePaint..color = greenPaint.color);
    // Blue arc & bar (Right)
    canvas.drawArc(rect, 3.5, 0.9, false, basePaint..color = bluePaint.color);

    // Horizontal bar
    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - stroke * 0.1,
        center.dy - stroke * 0.45,
        radius * 0.95,
        stroke * 0.9,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

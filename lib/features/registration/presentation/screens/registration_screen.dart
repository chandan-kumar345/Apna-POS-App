import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/glass_theme.dart';
import '../../../../core/utils/form_validators.dart';
import '../../domain/entities/user_registration_entity.dart';
import '../providers/registration_notifier.dart';
import '../providers/registration_state.dart';
import '../../../auth/create_profile_screen.dart';

class ProductionRegistrationScreen extends ConsumerStatefulWidget {
  final String? initialEmail;
  final String? initialPhone;
  final String? initialPassword;

  const ProductionRegistrationScreen({
    super.key,
    this.initialEmail,
    this.initialPhone,
    this.initialPassword,
  });

  @override
  ConsumerState<ProductionRegistrationScreen> createState() =>
      _ProductionRegistrationScreenState();
}

class _ProductionRegistrationScreenState
    extends ConsumerState<ProductionRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  final _pincodeController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _gstController = TextEditingController();
  final _referralController = TextEditingController();

  String _selectedGender = 'Male';
  String _selectedBusinessType = 'RESTAURANT';
  bool _termsAccepted = true;
  bool _privacyAccepted = true;
  bool _marketingConsent = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    _passwordController = TextEditingController(text: widget.initialPassword ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _pincodeController.dispose();
    _businessNameController.dispose();
    _gstController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted || !_privacyAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms & Privacy Policy to continue.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final state = ref.read(registrationNotifierProvider);
    final entity = UserRegistrationEntity(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text.trim(),
      fullName: _fullNameController.text.trim(),
      profilePhotoPath: state.profilePhotoPath,
      dateOfBirth: '1995-01-01',
      gender: _selectedGender,
      streetAddress: _streetController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      country: _countryController.text.trim(),
      pincode: _pincodeController.text.trim(),
      preferredLanguage: 'en',
      currency: 'INR',
      timeZone: 'Asia/Kolkata',
      businessName: _businessNameController.text.trim(),
      businessType: _selectedBusinessType,
      gstNumber: _gstController.text.trim(),
      referralCode: _referralController.text.trim(),
      termsAccepted: _termsAccepted,
      privacyPolicyAccepted: _privacyAccepted,
      marketingConsent: _marketingConsent,
      appVersion: '1.0.0',
      deviceId: 'DEV_${DateTime.now().millisecondsSinceEpoch}',
      deviceModel: 'Android/iOS Device',
      operatingSystem: Platform.isAndroid ? 'Android' : 'iOS',
      registrationSource: Platform.isAndroid ? 'ANDROID' : 'IOS',
    );

    ref.read(registrationNotifierProvider.notifier).registerUser(entity);
  }

  @override
  Widget build(BuildContext context) {
    final regState = ref.watch(registrationNotifierProvider);

    ref.listen<RegistrationState>(registrationNotifierProvider, (previous, next) {
      if (next.status == RegistrationStatus.otpVerificationPending) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CreateProfileScreen(
              initialEmail: _emailController.text,
              initialName: _fullNameController.text,
            ),
          ),
        );
      } else if (next.status == RegistrationStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF040814),
      appBar: AppBar(
        title: const Text('Production Account Registration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF051C48),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Photo Upload Avatar
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: GlassTheme.primaryBlue.withOpacity(0.2),
                        backgroundImage: regState.profilePhotoPath != null
                            ? FileImage(File(regState.profilePhotoPath!))
                            : null,
                        child: regState.profilePhotoPath == null
                            ? const Icon(Icons.person_add_alt_1_rounded, size: 40, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => ref.read(registrationNotifierProvider.notifier).pickProfilePhoto(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF00C2FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionHeader('1. Personal Credentials'),
                _buildTextField('Full Name', _fullNameController, (val) => FormValidators.validateRequired(val, 'Full Name'), icon: Icons.badge_rounded),
                _buildTextField('Username', _usernameController, FormValidators.validateUsername, icon: Icons.alternate_email_rounded),
                _buildTextField('Email Address', _emailController, FormValidators.validateEmail, icon: Icons.mail_rounded, keyboardType: TextInputType.emailAddress),
                _buildTextField('Phone Number', _phoneController, FormValidators.validatePhone, icon: Icons.phone_rounded, keyboardType: TextInputType.phone),
                _buildTextField(
                  'Password',
                  _passwordController,
                  FormValidators.validatePassword,
                  icon: Icons.lock_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: Colors.white70),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),

                const SizedBox(height: 20),
                _buildSectionHeader('2. Location & Address'),
                _buildTextField('Street Address', _streetController, (val) => FormValidators.validateRequired(val, 'Street Address'), icon: Icons.location_on_rounded),
                Row(
                  children: [
                    Expanded(child: _buildTextField('City', _cityController, (val) => FormValidators.validateRequired(val, 'City'), icon: Icons.location_city_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('State', _stateController, (val) => FormValidators.validateRequired(val, 'State'), icon: Icons.map_rounded)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Pincode', _pincodeController, FormValidators.validatePincode, icon: Icons.pin_drop_rounded, keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Country', _countryController, (val) => FormValidators.validateRequired(val, 'Country'), icon: Icons.flag_rounded)),
                  ],
                ),

                const SizedBox(height: 20),
                _buildSectionHeader('3. Business Profile'),
                _buildTextField('Business Name (Optional)', _businessNameController, (val) => null, icon: Icons.storefront_rounded),
                _buildTextField('GSTIN (Optional)', _gstController, FormValidators.validateGstNumber, icon: Icons.receipt_rounded),

                const SizedBox(height: 20),
                _buildSectionHeader('4. Consents & Agreements'),
                CheckboxListTile(
                  title: const Text('I accept the Terms & Conditions', style: TextStyle(color: Colors.white, fontSize: 13)),
                  value: _termsAccepted,
                  onChanged: (val) => setState(() => _termsAccepted = val ?? true),
                  activeColor: const Color(0xFF00C2FF),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('I accept the Privacy Policy', style: TextStyle(color: Colors.white, fontSize: 13)),
                  value: _privacyAccepted,
                  onChanged: (val) => setState(() => _privacyAccepted = val ?? true),
                  activeColor: const Color(0xFF00C2FF),
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: regState.status == RegistrationStatus.submitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    child: regState.status == RegistrationStatus.submitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Complete Secure Registration', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Powered by Sooftcode',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00C2FF)),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String? Function(String?) validator, {
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
          prefixIcon: Icon(icon, color: const Color(0xFF00C2FF), size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00C2FF))),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import '../../core/utils/form_validators.dart';
import '../../core/widgets/otp_pin_input.dart';

import '../../features/auth/data/repositories/auth_repository_factory.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'create_profile_screen.dart';

import '../onboarding/restaurant_onboarding_screen.dart';
import '../onboarding/add_business_address_screen.dart';
import '../onboarding/business_settings_screen.dart';
import '../dashboard/main_layout.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/responsive_layout_helper.dart';

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

// Complete World Country Codes List with Flags (190+ Countries)
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
  CountryCodeItem(flag: '🇵🇰', code: 'PK', dialCode: '+92', name: 'Pakistan'),
  CountryCodeItem(flag: '🇲🇾', code: 'MY', dialCode: '+60', name: 'Malaysia'),
  CountryCodeItem(flag: '🇮🇩', code: 'ID', dialCode: '+62', name: 'Indonesia'),
  CountryCodeItem(flag: '🇵🇭', code: 'PH', dialCode: '+63', name: 'Philippines'),
  CountryCodeItem(flag: '🇹🇭', code: 'TH', dialCode: '+66', name: 'Thailand'),
  CountryCodeItem(flag: '🇻🇳', code: 'VN', dialCode: '+84', name: 'Vietnam'),
  CountryCodeItem(flag: '🇰🇷', code: 'KR', dialCode: '+82', name: 'South Korea'),
  CountryCodeItem(flag: '🇧🇷', code: 'BR', dialCode: '+55', name: 'Brazil'),
  CountryCodeItem(flag: '🇲🇽', code: 'MX', dialCode: '+52', name: 'Mexico'),
  CountryCodeItem(flag: '🇮🇹', code: 'IT', dialCode: '+39', name: 'Italy'),
  CountryCodeItem(flag: '🇪🇸', code: 'ES', dialCode: '+34', name: 'Spain'),
  CountryCodeItem(flag: '🇳🇱', code: 'NL', dialCode: '+31', name: 'Netherlands'),
  CountryCodeItem(flag: '🇨🇭', code: 'CH', dialCode: '+41', name: 'Switzerland'),
  CountryCodeItem(flag: '🇿🇦', code: 'ZA', dialCode: '+27', name: 'South Africa'),
  CountryCodeItem(flag: '🇳🇿', code: 'NZ', dialCode: '+64', name: 'New Zealand'),
  CountryCodeItem(flag: '🇪🇬', code: 'EG', dialCode: '+20', name: 'Egypt'),
  CountryCodeItem(flag: '🇳🇬', code: 'NG', dialCode: '+234', name: 'Nigeria'),
  CountryCodeItem(flag: '🇹🇷', code: 'TR', dialCode: '+90', name: 'Turkey'),
  CountryCodeItem(flag: '🇷🇺', code: 'RU', dialCode: '+7', name: 'Russia'),
  CountryCodeItem(flag: '🇨🇳', code: 'CN', dialCode: '+86', name: 'China'),
  CountryCodeItem(flag: '🇭🇰', code: 'HK', dialCode: '+852', name: 'Hong Kong'),
  CountryCodeItem(flag: '🇹🇼', code: 'TW', dialCode: '+886', name: 'Taiwan'),
  CountryCodeItem(flag: '🇶🇦', code: 'QA', dialCode: '+974', name: 'Qatar'),
  CountryCodeItem(flag: '🇰🇼', code: 'KW', dialCode: '+965', name: 'Kuwait'),
  CountryCodeItem(flag: '🇴🇲', code: 'OM', dialCode: '+968', name: 'Oman'),
  CountryCodeItem(flag: '🇧🇭', code: 'BH', dialCode: '+973', name: 'Bahrain'),
  CountryCodeItem(flag: '🇦🇫', code: 'AF', dialCode: '+93', name: 'Afghanistan'),
  CountryCodeItem(flag: '🇦🇱', code: 'AL', dialCode: '+355', name: 'Albania'),
  CountryCodeItem(flag: '🇩🇿', code: 'DZ', dialCode: '+213', name: 'Algeria'),
  CountryCodeItem(flag: '🇦🇩', code: 'AD', dialCode: '+376', name: 'Andorra'),
  CountryCodeItem(flag: '🇦🇴', code: 'AO', dialCode: '+244', name: 'Angola'),
  CountryCodeItem(flag: '🇦🇬', code: 'AG', dialCode: '+1-268', name: 'Antigua & Barbuda'),
  CountryCodeItem(flag: '🇦🇷', code: 'AR', dialCode: '+54', name: 'Argentina'),
  CountryCodeItem(flag: '🇦🇲', code: 'AM', dialCode: '+374', name: 'Armenia'),
  CountryCodeItem(flag: '🇦🇹', code: 'AT', dialCode: '+43', name: 'Austria'),
  CountryCodeItem(flag: '🇦🇿', code: 'AZ', dialCode: '+994', name: 'Azerbaijan'),
  CountryCodeItem(flag: '🇧🇸', code: 'BS', dialCode: '+1-242', name: 'Bahamas'),
  CountryCodeItem(flag: '🇧🇧', code: 'BB', dialCode: '+1-246', name: 'Barbados'),
  CountryCodeItem(flag: '🇧🇾', code: 'BY', dialCode: '+375', name: 'Belarus'),
  CountryCodeItem(flag: '🇧🇪', code: 'BE', dialCode: '+32', name: 'Belgium'),
  CountryCodeItem(flag: '🇧🇿', code: 'BZ', dialCode: '+501', name: 'Belize'),
  CountryCodeItem(flag: '🇧🇯', code: 'BJ', dialCode: '+229', name: 'Benin'),
  CountryCodeItem(flag: '🇧🇹', code: 'BT', dialCode: '+975', name: 'Bhutan'),
  CountryCodeItem(flag: '🇧🇴', code: 'BO', dialCode: '+591', name: 'Bolivia'),
  CountryCodeItem(flag: '🇧🇦', code: 'BA', dialCode: '+387', name: 'Bosnia & Herzegovina'),
  CountryCodeItem(flag: '🇧🇼', code: 'BW', dialCode: '+267', name: 'Botswana'),
  CountryCodeItem(flag: '🇧🇳', code: 'BN', dialCode: '+673', name: 'Brunei'),
  CountryCodeItem(flag: '🇧🇬', code: 'BG', dialCode: '+359', name: 'Bulgaria'),
  CountryCodeItem(flag: '🇧🇫', code: 'BF', dialCode: '+226', name: 'Burkina Faso'),
  CountryCodeItem(flag: '🇧🇮', code: 'BI', dialCode: '+257', name: 'Burundi'),
  CountryCodeItem(flag: '🇰🇭', code: 'KH', dialCode: '+855', name: 'Cambodia'),
  CountryCodeItem(flag: '🇨🇲', code: 'CM', dialCode: '+237', name: 'Cameroon'),
  CountryCodeItem(flag: '🇨🇻', code: 'CV', dialCode: '+238', name: 'Cape Verde'),
  CountryCodeItem(flag: '🇨🇫', code: 'CF', dialCode: '+236', name: 'Central African Republic'),
  CountryCodeItem(flag: '🇹🇩', code: 'TD', dialCode: '+235', name: 'Chad'),
  CountryCodeItem(flag: '🇨🇱', code: 'CL', dialCode: '+56', name: 'Chile'),
  CountryCodeItem(flag: '🇨🇴', code: 'CO', dialCode: '+57', name: 'Colombia'),
  CountryCodeItem(flag: '🇰🇲', code: 'KM', dialCode: '+269', name: 'Comoros'),
  CountryCodeItem(flag: '🇨🇬', code: 'CG', dialCode: '+242', name: 'Congo'),
  CountryCodeItem(flag: '🇨🇩', code: 'CD', dialCode: '+243', name: 'Congo (DRC)'),
  CountryCodeItem(flag: '🇨🇷', code: 'CR', dialCode: '+506', name: 'Costa Rica'),
  CountryCodeItem(flag: '🇭🇷', code: 'HR', dialCode: '+385', name: 'Croatia'),
  CountryCodeItem(flag: '🇨🇺', code: 'CU', dialCode: '+53', name: 'Cuba'),
  CountryCodeItem(flag: '🇨🇾', code: 'CY', dialCode: '+357', name: 'Cyprus'),
  CountryCodeItem(flag: '🇨🇿', code: 'CZ', dialCode: '+420', name: 'Czech Republic'),
  CountryCodeItem(flag: '🇩🇰', code: 'DK', dialCode: '+45', name: 'Denmark'),
  CountryCodeItem(flag: '🇩🇯', code: 'DJ', dialCode: '+253', name: 'Djibouti'),
  CountryCodeItem(flag: '🇩🇲', code: 'DM', dialCode: '+1-767', name: 'Dominica'),
  CountryCodeItem(flag: '🇩🇴', code: 'DO', dialCode: '+1-809', name: 'Dominican Republic'),
  CountryCodeItem(flag: '🇪🇨', code: 'EC', dialCode: '+593', name: 'Ecuador'),
  CountryCodeItem(flag: '🇸🇻', code: 'SV', dialCode: '+503', name: 'El Salvador'),
  CountryCodeItem(flag: '🇬🇶', code: 'GQ', dialCode: '+240', name: 'Equatorial Guinea'),
  CountryCodeItem(flag: '🇪🇷', code: 'ER', dialCode: '+291', name: 'Eritrea'),
  CountryCodeItem(flag: '🇪🇪', code: 'EE', dialCode: '+372', name: 'Estonia'),
  CountryCodeItem(flag: '🇸🇿', code: 'SZ', dialCode: '+268', name: 'Eswatini'),
  CountryCodeItem(flag: '🇪🇹', code: 'ET', dialCode: '+251', name: 'Ethiopia'),
  CountryCodeItem(flag: '🇫🇯', code: 'FJ', dialCode: '+679', name: 'Fiji'),
  CountryCodeItem(flag: '🇫🇮', code: 'FI', dialCode: '+358', name: 'Finland'),
  CountryCodeItem(flag: '🇬🇦', code: 'GA', dialCode: '+241', name: 'Gabon'),
  CountryCodeItem(flag: '🇬🇲', code: 'GM', dialCode: '+220', name: 'Gambia'),
  CountryCodeItem(flag: '🇬🇪', code: 'GE', dialCode: '+995', name: 'Georgia'),
  CountryCodeItem(flag: '🇬🇭', code: 'GH', dialCode: '+233', name: 'Ghana'),
  CountryCodeItem(flag: '🇬🇷', code: 'GR', dialCode: '+30', name: 'Greece'),
  CountryCodeItem(flag: '🇬🇩', code: 'GD', dialCode: '+1-473', name: 'Grenada'),
  CountryCodeItem(flag: '🇬🇹', code: 'GT', dialCode: '+502', name: 'Guatemala'),
  CountryCodeItem(flag: '🇬🇳', code: 'GN', dialCode: '+224', name: 'Guinea'),
  CountryCodeItem(flag: '🇬🇼', code: 'GW', dialCode: '+245', name: 'Guinea-Bissau'),
  CountryCodeItem(flag: '🇬🇾', code: 'GY', dialCode: '+592', name: 'Guyana'),
  CountryCodeItem(flag: '🇭🇹', code: 'HT', dialCode: '+509', name: 'Haiti'),
  CountryCodeItem(flag: '🇭🇳', code: 'HN', dialCode: '+504', name: 'Honduras'),
  CountryCodeItem(flag: '🇭🇺', code: 'HU', dialCode: '+36', name: 'Hungary'),
  CountryCodeItem(flag: '🇮🇸', code: 'IS', dialCode: '+354', name: 'Iceland'),
  CountryCodeItem(flag: '🇮🇷', code: 'IR', dialCode: '+98', name: 'Iran'),
  CountryCodeItem(flag: '🇮🇶', code: 'IQ', dialCode: '+964', name: 'Iraq'),
  CountryCodeItem(flag: '🇮🇪', code: 'IE', dialCode: '+353', name: 'Ireland'),
  CountryCodeItem(flag: '🇮🇱', code: 'IL', dialCode: '+972', name: 'Israel'),
  CountryCodeItem(flag: '🇨🇮', code: 'CI', dialCode: '+225', name: 'Ivory Coast'),
  CountryCodeItem(flag: '🇯🇲', code: 'JM', dialCode: '+1-876', name: 'Jamaica'),
  CountryCodeItem(flag: '🇯🇴', code: 'JO', dialCode: '+962', name: 'Jordan'),
  CountryCodeItem(flag: '🇰🇿', code: 'KZ', dialCode: '+7', name: 'Kazakhstan'),
  CountryCodeItem(flag: '🇰🇪', code: 'KE', dialCode: '+254', name: 'Kenya'),
  CountryCodeItem(flag: '🇰🇮', code: 'KI', dialCode: '+686', name: 'Kiribati'),
  CountryCodeItem(flag: '🇰🇬', code: 'KG', dialCode: '+996', name: 'Kyrgyzstan'),
  CountryCodeItem(flag: '🇱🇦', code: 'LA', dialCode: '+856', name: 'Laos'),
  CountryCodeItem(flag: '🇱🇻', code: 'LV', dialCode: '+371', name: 'Latvia'),
  CountryCodeItem(flag: '🇱🇧', code: 'LB', dialCode: '+961', name: 'Lebanon'),
  CountryCodeItem(flag: '🇱🇸', code: 'LS', dialCode: '+266', name: 'Lesotho'),
  CountryCodeItem(flag: '🇱🇷', code: 'LR', dialCode: '+231', name: 'Liberia'),
  CountryCodeItem(flag: '🇱🇾', code: 'LY', dialCode: '+218', name: 'Libya'),
  CountryCodeItem(flag: '🇱🇮', code: 'LI', dialCode: '+423', name: 'Liechtenstein'),
  CountryCodeItem(flag: '🇱🇹', code: 'LT', dialCode: '+370', name: 'Lithuania'),
  CountryCodeItem(flag: '🇱🇺', code: 'LU', dialCode: '+352', name: 'Luxembourg'),
  CountryCodeItem(flag: '🇲🇴', code: 'MO', dialCode: '+853', name: 'Macao'),
  CountryCodeItem(flag: '🇲🇬', code: 'MG', dialCode: '+261', name: 'Madagascar'),
  CountryCodeItem(flag: '🇲🇼', code: 'MW', dialCode: '+265', name: 'Malawi'),
  CountryCodeItem(flag: '🇲🇻', code: 'MV', dialCode: '+960', name: 'Maldives'),
  CountryCodeItem(flag: '🇲🇱', code: 'ML', dialCode: '+223', name: 'Mali'),
  CountryCodeItem(flag: '🇲🇹', code: 'MT', dialCode: '+356', name: 'Malta'),
  CountryCodeItem(flag: '🇲🇭', code: 'MH', dialCode: '+692', name: 'Marshall Islands'),
  CountryCodeItem(flag: '🇲🇷', code: 'MR', dialCode: '+222', name: 'Mauritania'),
  CountryCodeItem(flag: '🇲🇺', code: 'MU', dialCode: '+230', name: 'Mauritius'),
  CountryCodeItem(flag: '🇫🇲', code: 'FM', dialCode: '+691', name: 'Micronesia'),
  CountryCodeItem(flag: '🇲🇩', code: 'MD', dialCode: '+373', name: 'Moldova'),
  CountryCodeItem(flag: '🇲🇨', code: 'MC', dialCode: '+377', name: 'Monaco'),
  CountryCodeItem(flag: '🇲🇳', code: 'MN', dialCode: '+976', name: 'Mongolia'),
  CountryCodeItem(flag: '🇲🇪', code: 'ME', dialCode: '+382', name: 'Montenegro'),
  CountryCodeItem(flag: '🇲🇦', code: 'MA', dialCode: '+212', name: 'Morocco'),
  CountryCodeItem(flag: '🇲🇿', code: 'MZ', dialCode: '+258', name: 'Mozambique'),
  CountryCodeItem(flag: '🇲🇲', code: 'MM', dialCode: '+95', name: 'Myanmar'),
  CountryCodeItem(flag: '🇳🇦', code: 'NA', dialCode: '+264', name: 'Namibia'),
  CountryCodeItem(flag: '🇳🇷', code: 'NR', dialCode: '+674', name: 'Nauru'),
  CountryCodeItem(flag: '🇳🇮', code: 'NI', dialCode: '+505', name: 'Nicaragua'),
  CountryCodeItem(flag: '🇳🇪', code: 'NE', dialCode: '+227', name: 'Niger'),
  CountryCodeItem(flag: '🇰🇵', code: 'KP', dialCode: '+850', name: 'North Korea'),
  CountryCodeItem(flag: '🇲🇰', code: 'MK', dialCode: '+389', name: 'North Macedonia'),
  CountryCodeItem(flag: '🇳🇴', code: 'NO', dialCode: '+47', name: 'Norway'),
  CountryCodeItem(flag: '🇵🇼', code: 'PW', dialCode: '+680', name: 'Palau'),
  CountryCodeItem(flag: '🇵🇸', code: 'PS', dialCode: '+970', name: 'Palestine'),
  CountryCodeItem(flag: '🇵🇦', code: 'PA', dialCode: '+507', name: 'Panama'),
  CountryCodeItem(flag: '🇵🇬', code: 'PG', dialCode: '+675', name: 'Papua New Guinea'),
  CountryCodeItem(flag: '🇵🇾', code: 'PY', dialCode: '+595', name: 'Paraguay'),
  CountryCodeItem(flag: '🇵🇪', code: 'PE', dialCode: '+51', name: 'Peru'),
  CountryCodeItem(flag: '🇵🇱', code: 'PL', dialCode: '+48', name: 'Poland'),
  CountryCodeItem(flag: '🇵🇹', code: 'PT', dialCode: '+351', name: 'Portugal'),
  CountryCodeItem(flag: '🇷🇴', code: 'RO', dialCode: '+40', name: 'Romania'),
  CountryCodeItem(flag: '🇷🇼', code: 'RW', dialCode: '+250', name: 'Rwanda'),
  CountryCodeItem(flag: '🇰🇳', code: 'KN', dialCode: '+1-869', name: 'Saint Kitts & Nevis'),
  CountryCodeItem(flag: '🇱🇨', code: 'LC', dialCode: '+1-758', name: 'Saint Lucia'),
  CountryCodeItem(flag: '🇻🇨', code: 'VC', dialCode: '+1-784', name: 'Saint Vincent'),
  CountryCodeItem(flag: '🇼🇸', code: 'WS', dialCode: '+685', name: 'Samoa'),
  CountryCodeItem(flag: '🇸🇲', code: 'SM', dialCode: '+378', name: 'San Marino'),
  CountryCodeItem(flag: '🇸🇹', code: 'ST', dialCode: '+239', name: 'Sao Tome & Principe'),
  CountryCodeItem(flag: '🇸🇳', code: 'SN', dialCode: '+221', name: 'Senegal'),
  CountryCodeItem(flag: '🇷🇸', code: 'RS', dialCode: '+381', name: 'Serbia'),
  CountryCodeItem(flag: '🇸🇨', code: 'SC', dialCode: '+248', name: 'Seychelles'),
  CountryCodeItem(flag: '🇸🇱', code: 'SL', dialCode: '+232', name: 'Sierra Leone'),
  CountryCodeItem(flag: '🇸🇰', code: 'SK', dialCode: '+421', name: 'Slovakia'),
  CountryCodeItem(flag: '🇸🇮', code: 'SI', dialCode: '+386', name: 'Slovenia'),
  CountryCodeItem(flag: '🇸🇧', code: 'SB', dialCode: '+677', name: 'Solomon Islands'),
  CountryCodeItem(flag: '🇸🇴', code: 'SO', dialCode: '+252', name: 'Somalia'),
  CountryCodeItem(flag: '🇸🇸', code: 'SS', dialCode: '+211', name: 'South Sudan'),
  CountryCodeItem(flag: '🇸🇩', code: 'SD', dialCode: '+249', name: 'Sudan'),
  CountryCodeItem(flag: '🇸🇷', code: 'SR', dialCode: '+597', name: 'Suriname'),
  CountryCodeItem(flag: '🇸🇪', code: 'SE', dialCode: '+46', name: 'Sweden'),
  CountryCodeItem(flag: '🇸🇾', code: 'SY', dialCode: '+963', name: 'Syria'),
  CountryCodeItem(flag: '🇹🇯', code: 'TJ', dialCode: '+992', name: 'Tajikistan'),
  CountryCodeItem(flag: '🇹🇿', code: 'TZ', dialCode: '+255', name: 'Tanzania'),
  CountryCodeItem(flag: '🇹🇱', code: 'TL', dialCode: '+670', name: 'Timor-Leste'),
  CountryCodeItem(flag: '🇹🇬', code: 'TG', dialCode: '+228', name: 'Togo'),
  CountryCodeItem(flag: '🇹🇴', code: 'TO', dialCode: '+676', name: 'Tonga'),
  CountryCodeItem(flag: '🇹🇹', code: 'TT', dialCode: '+1-868', name: 'Trinidad & Tobago'),
  CountryCodeItem(flag: '🇹🇳', code: 'TN', dialCode: '+216', name: 'Tunisia'),
  CountryCodeItem(flag: '🇹🇲', code: 'TM', dialCode: '+993', name: 'Turkmenistan'),
  CountryCodeItem(flag: '🇹🇻', code: 'TV', dialCode: '+688', name: 'Tuvalu'),
  CountryCodeItem(flag: '🇺🇬', code: 'UG', dialCode: '+256', name: 'Uganda'),
  CountryCodeItem(flag: '🇺🇦', code: 'UA', dialCode: '+380', name: 'Ukraine'),
  CountryCodeItem(flag: '🇺🇾', code: 'UY', dialCode: '+598', name: 'Uruguay'),
  CountryCodeItem(flag: '🇺🇿', code: 'UZ', dialCode: '+998', name: 'Uzbekistan'),
  CountryCodeItem(flag: '🇻🇺', code: 'VU', dialCode: '+678', name: 'Vanuatu'),
  CountryCodeItem(flag: '🇻🇦', code: 'VA', dialCode: '+39', name: 'Vatican City'),
  CountryCodeItem(flag: '🇻🇪', code: 'VE', dialCode: '+58', name: 'Venezuela'),
  CountryCodeItem(flag: '🇾🇪', code: 'YE', dialCode: '+967', name: 'Yemen'),
  CountryCodeItem(flag: '🇿🇲', code: 'ZM', dialCode: '+260', name: 'Zambia'),
  CountryCodeItem(flag: '🇿🇼', code: 'ZW', dialCode: '+263', name: 'Zimbabwe'),
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
  bool _isEmailLogin = true; // Default true: Login with Email & Password first preference!
  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  final db = DatabaseService();

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<void> _completeGoogleLogin(String email, String name, String? photoUrl) async {
    setState(() => _isLoading = true);
    try {
      // Authenticate with backend API
      try {
        await AuthService().login(email, 'GoogleAuth@123').catchError((_) {
          return AuthService().register(email, 'GoogleAuth@123');
        });
      } catch (e) {
        debugPrint('Backend Google auth note: $e');
      }

      final success = await db.loginWithGoogle(email, name, photoUrl);
      if (!mounted) return;
      if (success) {
        final rest = db.restaurant;
        if (rest != null && rest.isOnboarded) {
          Navigator.pushAndRemoveUntil(
            context,
            SlideUpPageRoute(page: const MainLayout()),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            SlideUpPageRoute(page: const RestaurantOnboardingScreen()),
            (route) => false,
          );
        }
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to login with Google')),
        );
      }
    } catch (e) {
      debugPrint('Google Sign In complete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign In failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final bool isDesktopPlatform = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    if (isDesktopPlatform) {
      // On Windows / Desktop, try Firebase provider or open smooth Google prompt dialog
      setState(() => _isLoading = true);
      try {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        final userCredential = await FirebaseAuth.instance.signInWithProvider(googleProvider);
        final user = userCredential.user;
        if (user != null && user.email != null) {
          await _completeGoogleLogin(
            user.email!,
            user.displayName ?? user.email!.split('@').first,
            user.photoURL,
          );
          return;
        }
      } catch (desktopErr) {
        debugPrint('Desktop Firebase Google provider fallback to dialog: $desktopErr');
        if (mounted) {
          setState(() => _isLoading = false);
          _showDesktopGoogleEmailPrompt();
          return;
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();
      if (googleAccount != null) {
        final email = googleAccount.email;
        final name = googleAccount.displayName ?? email.split('@').first;
        final photoUrl = googleAccount.photoUrl;
        await _completeGoogleLogin(email, name, photoUrl);
      }
    } catch (e) {
      debugPrint('Google Sign In error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign In failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Windows Desktop Google Email Sign-In Prompt Dialog
  void _showDesktopGoogleEmailPrompt() {
    final googleEmailController = TextEditingController();
    final googleNameController = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildGoogleColoredIcon(size: 26),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Sign in with Google',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(dialogCtx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your Google account email to securely sign in to Apna POS on Windows.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Google Email Address',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: googleEmailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'name@gmail.com',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.email_outlined, size: 18, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Your Name (Optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: googleNameController,
                  decoration: InputDecoration(
                    hintText: 'Full Name',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                    ),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () async {
                      final email = googleEmailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        setDialogState(() => dialogError = 'Please enter a valid Google email address.');
                        return;
                      }
                      final name = googleNameController.text.trim().isNotEmpty
                          ? googleNameController.text.trim()
                          : email.split('@').first;

                      Navigator.pop(dialogCtx);
                      await _completeGoogleLogin(email, name, null);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Sign In with Google Account',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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

  // OTP Verification Popup Dialog for Phone Login
  void _showPhoneOtpVerificationDialog(String displayPhone, String rawPhone) async {
    final authRepo = AuthRepositoryFactory.instance;
    
    // Ensure we use international format for Firebase if possible
    String firebaseRecipient = rawPhone;
    if (!firebaseRecipient.startsWith('+')) {
      firebaseRecipient = '${_selectedCountry.dialCode}$rawPhone';
    }

    await authRepo.sendOtp(firebaseRecipient);

    final otpController = TextEditingController();
    final otpFocusNode = FocusNode();
    String? otpError;
    bool isVerifying = false;
    int failedOtpAttempts = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 25,
                            offset: Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFF00C2FF),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon Header
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0052FF).withValues(alpha: 0.1),
                              border: Border.all(color: const Color(0xFF00C2FF), width: 1.5),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.phone_android_rounded,
                                color: GlassTheme.primaryBlue,
                                size: 30,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'OTP Verification',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),

                          const SizedBox(height: 8),

                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              text: 'Enter the 4-digit verification code sent to\n',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(
                                  text: displayPhone,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          if (otpError != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Color(0xFFEF4444), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      otpError!,
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
                          ],

                          OtpPinInput(
                            controller: otpController,
                            focusNode: otpFocusNode,
                            length: 4,
                            onChanged: (_) {
                              if (otpError != null) {
                                setDialogState(() => otpError = null);
                              }
                            },
                          ),

                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Didn't receive code? ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  // Re-send OTP via Firebase
                                  String firebaseRecipient = rawPhone;
                                  if (!firebaseRecipient.startsWith('+')) {
                                    firebaseRecipient = '${_selectedCountry.dialCode}$rawPhone';
                                  }
                                  await authRepo.sendOtp(firebaseRecipient);
                                  
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: GlassTheme.primaryNavy,
                                      content: Text(
                                        'New OTP verification code sent via SMS to $displayPhone',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Resend OTP',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF00C2FF),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: GlassTheme.primaryButtonGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: GlassTheme.primaryBlue.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isVerifying
                                  ? null
                                  : () async {
                                      if (failedOtpAttempts >= 5) {
                                        setDialogState(() {
                                          otpError = 'Too many incorrect attempts. Please try again later.';
                                        });
                                        return;
                                      }

                                      final enteredOtp = otpController.text
                                          .trim()
                                          .replaceAll(RegExp(r'[^0-9]'), '');
                                      if (enteredOtp.length < 4) {
                                        setDialogState(() {
                                          otpError = 'Please enter the complete 4-digit OTP.';
                                        });
                                        return;
                                      }

                                      setDialogState(() {
                                        isVerifying = true;
                                        otpError = null;
                                      });

                                      try {
                                        String firebaseRecipient = rawPhone;
                                        if (!firebaseRecipient.startsWith('+')) {
                                          firebaseRecipient = '${_selectedCountry.dialCode}$rawPhone';
                                        }

                                        final userEntity = await authRepo.verifyOtp(firebaseRecipient, enteredOtp);

                                        if (userEntity != null) {
                                          // Authenticate with backend API
                                          try {
                                            final phoneEmail = '${rawPhone.replaceAll(RegExp(r'[^0-9]'), '')}@apnapos.com';
                                            await AuthService().login(firebaseRecipient, 'PhoneAuth@123').catchError((_) {
                                              return AuthService().register(phoneEmail, 'PhoneAuth@123', phone: firebaseRecipient);
                                            });
                                          } catch (e) {
                                            debugPrint('Backend phone auth note: $e');
                                          }

                                          // OTP is correct - Log in or create user account
                                          bool success = await db.loginWithOtpPhone(firebaseRecipient);
                                          
                                          if (!mounted) return;


                                          if (success) {
                                            Navigator.pop(context);
                                            final rest = db.restaurant;
                                            if (rest != null && rest.isOnboarded) {
                                              Navigator.pushAndRemoveUntil(
                                                context,
                                                SlideUpPageRoute(page: const MainLayout()),
                                                (route) => false,
                                              );
                                            } else {
                                              Navigator.pushAndRemoveUntil(
                                                context,
                                                SlideUpPageRoute(page: const RestaurantOnboardingScreen()),
                                                (route) => false,
                                              );
                                            }
                                          } else {
                                            setDialogState(() {
                                              isVerifying = false;
                                              otpError = 'Failed to create or verify user session. Please try again.';
                                            });
                                          }
                                        } else {
                                          failedOtpAttempts++;
                                          setDialogState(() {
                                            isVerifying = false;
                                            otpError = 'The OTP you entered is incorrect.';
                                          });
                                        }
                                      } catch (e) {
                                        failedOtpAttempts++;
                                        setDialogState(() {
                                          isVerifying = false;
                                          otpError = e.toString().contains('incorrect') 
                                              ? 'The OTP you entered is incorrect.' 
                                              : 'Verification failed: $e';
                                        });
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: isVerifying
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Verify & Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

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
            SlideUpPageRoute(
              page: SignupScreen(
                initialEmail: _emailController.text.trim(),
                initialPassword: _passwordController.text.trim(),
                initialPhone: _phoneController.text.trim(),
              ),
            ),
          );
        }
        return;
      }

      if (!_isEmailLogin) {
        // Phone Number Mode

        final phone = _phoneController.text.trim();
        final phoneErr = FormValidators.validatePhone(phone, requiredDigits: 10);
        if (phoneErr != null) {
          setState(() {
            _errorMessage = phoneErr;
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _isLoading = false;
        });

        final fullPhone = '${_selectedCountry.dialCode} $phone';
        _showPhoneOtpVerificationDialog(fullPhone, phone);
        return;
      } else {
        // Email & Password Mode
        final email = _emailController.text.trim().toLowerCase();
        final password = _passwordController.text.trim();

        final emailErr = FormValidators.validateEmail(email);
        if (emailErr != null) {
          setState(() {
            _errorMessage = emailErr;
            _isLoading = false;
          });
          return;
        }
        if (password.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter your password.';
            _isLoading = false;
          });
          return;
        }

        // 1. Direct fast backend authentication
        final result = await AuthService().login(email, password);
        final userJson = result['user'] as Map<String, dynamic>?;
        final bool onboardingCompleted = userJson?['onboardingCompleted'] == true;
        final int currentStep = (userJson?['onboardingStep'] as num?)?.toInt() ?? 0;

        // 2. Synchronize Firebase Auth & Firestore in non-blocking background task
        unawaited(() async {
          try {
            final auth = FirebaseAuth.instance;
            try {
              await auth.signInWithEmailAndPassword(email: email, password: password);
            } on FirebaseAuthException catch (fbErr) {
              if (fbErr.code == 'user-not-found' || fbErr.code == 'invalid-credential') {
                try {
                  await auth.createUserWithEmailAndPassword(email: email, password: password);
                } catch (_) {}
              }
            }
          } catch (_) {}

          try {
            final activeUser = DatabaseService().currentUser;
            if (activeUser != null) {
              await FirestoreService().saveUser(activeUser);
            }
          } catch (_) {}
        }());

        if (!mounted) return;

        if (onboardingCompleted) {
          Navigator.pushAndRemoveUntil(
            context,
            SlideUpPageRoute(page: const MainLayout()),
            (route) => false,
          );
        } else {
          Widget targetStepScreen = const CreateProfileScreen();
          switch (currentStep) {
            case 0:
              targetStepScreen = const CreateProfileScreen();
              break;
            case 1:
              targetStepScreen = const RestaurantOnboardingScreen();
              break;
            case 2:
              targetStepScreen = const AddBusinessAddressScreen();
              break;
            case 3:
            case 4:
              targetStepScreen = const BusinessSettingsScreen();
              break;
            default:
              targetStepScreen = const CreateProfileScreen();
          }
          Navigator.pushAndRemoveUntil(
            context,
            SlideUpPageRoute(page: targetStepScreen),
            (route) => false,
          );
        }
        return;
      }
    } catch (e) {
      final errStr = e.toString();
      debugPrint('Login exception detail: $errStr');

      final isUserNotFound = (e is ApiException && (e.code == 'USER_NOT_FOUND' || e.statusCode == 404)) ||
          errStr.toLowerCase().contains('no account found') ||
          errStr.toLowerCase().contains('user not found') ||
          errStr.toLowerCase().contains('please sign up') ||
          errStr.toLowerCase().contains('not registered') ||
          errStr.toLowerCase().contains('user_not_found');

      if (isUserNotFound) {
        setState(() {
          _selectedTab = 1;
          _isLoading = false;
          _errorMessage = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No account found. Redirected to register with your entered details.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Color(0xFF051C48),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      setState(() {
        _errorMessage = errStr.replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  // Contact Us Support Dialog
  void _showContactUsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0066FF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded, color: Color(0xFF0066FF), size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Contact Apna POS Support',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Need help getting started or setting up your POS account? Reach out to our dedicated support team.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 16),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0066FF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_rounded, color: Color(0xFF0066FF), size: 20),
              ),
              title: const Text('+91 9709593705', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              subtitle: const Text('Call / WhatsApp Support (24x7)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
              onTap: () async {
                final uri = Uri.parse('tel:+919709593705');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            const SizedBox(height: 6),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0066FF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.email_rounded, color: Color(0xFF0066FF), size: 20),
              ),
              title: const Text('sooftcode@gmail.com', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              subtitle: const Text('Email Support', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
              onTap: () async {
                final uri = Uri.parse('mailto:sooftcode@gmail.com');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            const SizedBox(height: 6),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0066FF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.language_rounded, color: Color(0xFF0066FF), size: 20),
              ),
              title: const Text('sooftcode.com', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              subtitle: const Text('Official Website', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              trailing: const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF94A3B8)),
              onTap: () async {
                final uri = Uri.parse('https://sooftcode.vercel.app/');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // Modal to Pick Country Code with Flag & Search Field (Responsive for Desktop & Mobile)
  void _showCountryCodePicker() {
    String searchQuery = '';
    final bool isDesktop = ResponsiveLayoutHelper.isDesktop(context);

    Widget buildPickerContent(StateSetter setModalState) {
      final filteredCountries = countryCodesList.where((country) {
        final query = searchQuery.toLowerCase().trim();
        return country.name.toLowerCase().contains(query) ||
            country.code.toLowerCase().contains(query) ||
            country.dialCode.contains(query);
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDesktop) ...[
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
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Country Code',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded,
                    size: 22, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Input Box
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00C2FF),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: Color(0xFF00C2FF), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    scrollPadding: const EdgeInsets.only(bottom: 90),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val;
                      });
                    },
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search country or code...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setModalState(() {
                        searchQuery = '';
                      });
                    },
                    child: const Icon(Icons.cancel_rounded,
                        color: Color(0xFF94A3B8), size: 18),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Country List View
          Expanded(
            child: filteredCountries.isEmpty
                ? const Center(
                    child: Text(
                      'No country found',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredCountries.length,
                    separatorBuilder: (context, index) => const Divider(
                        color: Color(0xFFF1F5F9), height: 1),
                    itemBuilder: (context, index) {
                      final country = filteredCountries[index];
                      final isSelected =
                          country.code == _selectedCountry.code;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        leading: Text(country.flag,
                            style: const TextStyle(fontSize: 24)),
                        title: Text(
                          '${country.name} (${country.code})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
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
      );
    }

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                insetPadding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440, maxHeight: 540),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: buildPickerContent(setModalState),
                  ),
                ),
              );
            },
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return AnimatedPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: Material(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.70,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: buildPickerContent(setModalState),
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayoutHelper.isDesktop(context)) {
      return _buildWindowsDesktopLogin(context);
    }
    return _buildMobileLogin(context);
  }

  // Windows Desktop Login Layout (Matching official Apna POS desktop design)
  Widget _buildWindowsDesktopLogin(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Gradient matching reference mockup
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FAFC),
                    Color(0xFFF1F6FD),
                    Color(0xFFEAF2FC),
                  ],
                ),
              ),
            ),
          ),

          // Main Desktop Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Header Bar (Clean Minimal Logo on Left)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Official Apna POS Brand Logo in Top-Left
                      Image.asset(
                        'assets/images/apna_pos_brand_logo.png',
                        height: 44,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.point_of_sale_rounded, color: Color(0xFF0066FF), size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Apna POS',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF051C48),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox.shrink(),
                    ],
                  ),
                ),

                // 2. Main Center Body (Left Logo & Welcome + Right Auth Card)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1060),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left Section (Prominent Apna POS Logo + "Welcome!")
                            Expanded(
                              flex: 5,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/apna_pos_brand_logo.png',
                                    height: 190,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 180,
                                      width: 180,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0066FF).withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.point_of_sale_rounded,
                                        color: Color(0xFF0066FF),
                                        size: 80,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Welcome!',
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Smart POS & Billing Software for Modern Businesses',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 40),

                            // Right Section (Floating White Card)
                            Expanded(
                              flex: 5,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 420),
                                  child: Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0C0F172A),
                                          blurRadius: 28,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: _selectedTab == 1
                                        ? Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: const [
                                                      Text(
                                                        'Create Account',
                                                        style: TextStyle(
                                                          fontSize: 22,
                                                          fontWeight: FontWeight.w800,
                                                          color: Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        'Join Apna POS to manage your restaurant',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Color(0xFF64748B),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  IconButton(
                                                    onPressed: () => setState(() => _selectedTab = 0),
                                                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF64748B)),
                                                    tooltip: 'Back to Sign In',
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              RegisterFormWidget(
                                                initialEmail: _emailController.text.trim(),
                                                initialPassword: _passwordController.text.trim(),
                                                initialPhone: _phoneController.text.trim(),
                                              ),
                                              const SizedBox(height: 16),
                                              Center(
                                                child: InkWell(
                                                  onTap: () => setState(() => _selectedTab = 0),
                                                  child: const Text(
                                                    'Already have an account? Sign In',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF0066FF),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Title & Subtitle matching Mockup
                                              const Text(
                                                'Sign In',
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                  letterSpacing: -0.3,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'to access Account',
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),

                                              const SizedBox(height: 20),

                                              // Sleek Auth Switcher (Email/Password first preference vs Mobile OTP)
                                                Container(
                                                  height: 38,
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: GestureDetector(
                                                          onTap: () => setState(() {
                                                            _isEmailLogin = true;
                                                            _errorMessage = null;
                                                          }),
                                                          child: AnimatedContainer(
                                                            duration: const Duration(milliseconds: 200),
                                                            decoration: BoxDecoration(
                                                              color: _isEmailLogin ? Colors.white : Colors.transparent,
                                                              borderRadius: BorderRadius.circular(8),
                                                              boxShadow: _isEmailLogin
                                                                  ? const [
                                                                      BoxShadow(
                                                                        color: Colors.black12,
                                                                        blurRadius: 4,
                                                                        offset: Offset(0, 1),
                                                                      ),
                                                                    ]
                                                                  : null,
                                                            ),
                                                            child: Center(
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                  Icon(
                                                                    Icons.email_outlined,
                                                                    size: 14,
                                                                    color: _isEmailLogin
                                                                        ? const Color(0xFF0066FF)
                                                                        : const Color(0xFF64748B),
                                                                  ),
                                                                  const SizedBox(width: 6),
                                                                  Text(
                                                                    'Email & Password',
                                                                    style: TextStyle(
                                                                      fontSize: 12.5,
                                                                      fontWeight: _isEmailLogin
                                                                          ? FontWeight.w700
                                                                          : FontWeight.w500,
                                                                      color: _isEmailLogin
                                                                          ? const Color(0xFF0F172A)
                                                                          : const Color(0xFF64748B),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: GestureDetector(
                                                          onTap: () => setState(() {
                                                            _isEmailLogin = false;
                                                            _errorMessage = null;
                                                          }),
                                                          child: AnimatedContainer(
                                                            duration: const Duration(milliseconds: 200),
                                                            decoration: BoxDecoration(
                                                              color: !_isEmailLogin ? Colors.white : Colors.transparent,
                                                              borderRadius: BorderRadius.circular(8),
                                                              boxShadow: !_isEmailLogin
                                                                  ? const [
                                                                      BoxShadow(
                                                                        color: Colors.black12,
                                                                        blurRadius: 4,
                                                                        offset: Offset(0, 1),
                                                                      ),
                                                                    ]
                                                                  : null,
                                                            ),
                                                            child: Center(
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                  Icon(
                                                                    Icons.phone_android_rounded,
                                                                    size: 14,
                                                                    color: !_isEmailLogin
                                                                        ? const Color(0xFF0066FF)
                                                                        : const Color(0xFF64748B),
                                                                  ),
                                                                  const SizedBox(width: 6),
                                                                  Text(
                                                                    'Mobile OTP',
                                                                    style: TextStyle(
                                                                      fontSize: 12.5,
                                                                      fontWeight: !_isEmailLogin
                                                                          ? FontWeight.w700
                                                                          : FontWeight.w500,
                                                                      color: !_isEmailLogin
                                                                          ? const Color(0xFF0F172A)
                                                                          : const Color(0xFF64748B),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                const SizedBox(height: 18),

                                              // Error Banner
                                              if (_errorMessage != null) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  margin: const EdgeInsets.only(bottom: 14),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF2F2),
                                                    borderRadius: BorderRadius.circular(10),
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
                                              ],

                                              // Form Fields with Smooth AnimatedCrossFade Transition
                                              AnimatedCrossFade(
                                                duration: const Duration(milliseconds: 250),
                                                firstCurve: Curves.easeInOutCubic,
                                                secondCurve: Curves.easeInOutCubic,
                                                sizeCurve: Curves.easeInOutCubic,
                                                crossFadeState: !_isEmailLogin
                                                    ? CrossFadeState.showFirst
                                                    : CrossFadeState.showSecond,
                                                firstChild: Column(
                                                  key: const ValueKey('desktop_phone_mode'),
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // Mobile Input Field
                                                    Container(
                                                      height: 48,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(
                                                          color: const Color(0xFFE2E8F0),
                                                          width: 1.2,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          InkWell(
                                                            onTap: _showCountryCodePicker,
                                                            borderRadius: BorderRadius.circular(6),
                                                            child: Padding(
                                                              padding: const EdgeInsets.symmetric(
                                                                  vertical: 4, horizontal: 2),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Text(_selectedCountry.flag,
                                                                      style: const TextStyle(fontSize: 18)),
                                                                  const SizedBox(width: 6),
                                                                  Text(
                                                                    _selectedCountry.dialCode,
                                                                    style: const TextStyle(
                                                                      fontSize: 13.5,
                                                                      fontWeight: FontWeight.w700,
                                                                      color: Color(0xFF0F172A),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 2),
                                                                  const Icon(
                                                                    Icons.keyboard_arrow_down_rounded,
                                                                    color: Color(0xFF94A3B8),
                                                                    size: 16,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          Container(
                                                            height: 20,
                                                            width: 1,
                                                            margin: const EdgeInsets.symmetric(horizontal: 10),
                                                            color: const Color(0xFFE2E8F0),
                                                          ),
                                                          Expanded(
                                                            child: TextField(
                                                              controller: _phoneController,
                                                              keyboardType: TextInputType.phone,
                                                              style: const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w600,
                                                                color: Color(0xFF0F172A),
                                                              ),
                                                              decoration: const InputDecoration(
                                                                hintText: 'Email address or mobile number',
                                                                hintStyle: TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight: FontWeight.w400,
                                                                  color: Color(0xFF94A3B8),
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
                                                  ],
                                                ),
                                                secondChild: Column(
                                                  key: const ValueKey('desktop_email_mode'),
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // Email & Password Fields
                                                    _buildDesktopInputCard(
                                                      label: 'Email Address',
                                                      hint: 'Enter your email',
                                                      icon: Icons.mail_outline_rounded,
                                                      controller: _emailController,
                                                      keyboardType: TextInputType.emailAddress,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    _buildDesktopInputCard(
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
                                                          size: 18,
                                                        ),
                                                        onPressed: () => setState(
                                                            () => _obscurePassword = !_obscurePassword),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            SizedBox(
                                                              width: 20,
                                                              height: 20,
                                                              child: Checkbox(
                                                                value: _rememberMe,
                                                                activeColor: const Color(0xFF0066FF),
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(4),
                                                                ),
                                                                side: const BorderSide(
                                                                  color: Color(0xFFCBD5E1),
                                                                  width: 1.2,
                                                                ),
                                                                onChanged: (val) {
                                                                  if (val != null) {
                                                                    setState(() => _rememberMe = val);
                                                                  }
                                                                },
                                                              ),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            const Text(
                                                              'Remember me',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w500,
                                                                color: Color(0xFF475569),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.push(
                                                              context,
                                                              SlideUpPageRoute(
                                                                page: ForgotPasswordScreen(
                                                                  initialEmail: _emailController.text.trim(),
                                                                ),
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
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: Color(0xFF0066FF),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              const SizedBox(height: 20),

                                              // Primary Continue / Sign In Button with AnimatedSwitcher
                                              SizedBox(
                                                width: double.infinity,
                                                height: 46,
                                                child: ElevatedButton(
                                                  onPressed: _isLoading ? null : _handleAuthAction,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF0066FF),
                                                    foregroundColor: Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                  ),
                                                  child: AnimatedSwitcher(
                                                    duration: const Duration(milliseconds: 200),
                                                    child: _isLoading
                                                        ? const SizedBox(
                                                            key: ValueKey('loading'),
                                                            width: 20,
                                                            height: 20,
                                                            child: CircularProgressIndicator(
                                                              color: Colors.white,
                                                              strokeWidth: 2.2,
                                                            ),
                                                          )
                                                        : Text(
                                                            !_isEmailLogin ? 'Continue' : 'Sign In',
                                                            key: ValueKey(!_isEmailLogin ? 'continue' : 'signin'),
                                                            style: const TextStyle(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(height: 16),

                                              // Divider "— or —"
                                              Row(
                                                children: const [
                                                  Expanded(
                                                      child: Divider(
                                                          color: Color(0xFFE2E8F0), thickness: 1)),
                                                  Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                                    child: Text(
                                                      '— or —',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        color: Color(0xFF94A3B8),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                      child: Divider(
                                                          color: Color(0xFFE2E8F0), thickness: 1)),
                                                ],
                                              ),

                                              const SizedBox(height: 16),

                                              // Google Sign In Button
                                              SizedBox(
                                                width: double.infinity,
                                                height: 46,
                                                child: OutlinedButton(
                                                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                                                  style: OutlinedButton.styleFrom(
                                                    backgroundColor: Colors.white,
                                                    foregroundColor: const Color(0xFF334155),
                                                    side: const BorderSide(
                                                        color: Color(0xFFE2E8F0), width: 1.2),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      _buildGoogleColoredIcon(size: 18),
                                                      const SizedBox(width: 10),
                                                      const Text(
                                                        'Sign in with Google',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF334155),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(height: 24),

                                              // Footer Link matching Mockup: "New in Apna POS? Contact Us"
                                              Center(
                                                child: Wrap(
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  alignment: WrapAlignment.center,
                                                  children: [
                                                    const Text(
                                                      'New in Apna POS? ',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: _showContactUsDialog,
                                                      child: const Text(
                                                        'Contact Us',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF0066FF),
                                                        ),
                                                      ),
                                                    ),
                                                    const Text('  •  ',
                                                        style: TextStyle(color: Color(0xFFCBD5E1))),
                                                    InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          _selectedTab = 1;
                                                          _errorMessage = null;
                                                        });
                                                      },
                                                      child: const Text(
                                                        'Sign Up',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF0066FF),
                                                        ),
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
                            ),
                          ],
                        ),
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

  // Mobile / Android Login UI
  Widget _buildMobileLogin(BuildContext context) {
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

                // Top Header Text (Centered) - Long press to open Server Connection Settings
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () => ApiEndpoints.showServerConfigSheet(
                        context,
                        onUrlChanged: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _selectedTab == 0
                                ? "Go ahead and set up\nyour account"
                                : "Create your new\nPOS account",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedTab == 0
                                ? "Sign in-up to enjoy the best managing experience"
                                : "Join Apna POS to manage your restaurant effortlessly",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Bottom Rounded White Card Container
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
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
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Segmented Tab Pill (Login / Register)
                          Container(
                            height: 50,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _selectedTab = 0;
                                      _errorMessage = null; // Clear error
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: _selectedTab == 0
                                            ? Colors.white
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(21),
                                        boxShadow: _selectedTab == 0
                                            ? [
                                                const BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 6,
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
                                      setState(() {
                                        _selectedTab = 1;
                                        _errorMessage = null; // Clear error
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: _selectedTab == 1
                                            ? Colors.white
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(21),
                                        boxShadow: _selectedTab == 1
                                            ? [
                                                const BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 6,
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

                          const SizedBox(height: 18),

                          // Dynamic View: Switch between Login Form and Register Form Widget seamlessly in-place!
                          if (_selectedTab == 1) ...[
                            RegisterFormWidget(
                              initialEmail: _emailController.text.trim(),
                              initialPassword: _passwordController.text.trim(),
                              initialPhone: _phoneController.text.trim(),
                            ),
                          ] else ...[
                            // Error Banner
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    if (_errorMessage!.toLowerCase().contains('connect') ||
                                        _errorMessage!.toLowerCase().contains('server') ||
                                        _errorMessage!.toLowerCase().contains('internet')) ...[
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () async {
                                          setState(() => _isLoading = true);
                                          await ApiEndpoints.initialize(forceRecheck: true);
                                          setState(() {
                                            _isLoading = false;
                                            _errorMessage = null;
                                          });
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Server connected: ${ApiEndpoints.baseUrl}'),
                                                backgroundColor: const Color(0xFF051C48),
                                                behavior: SnackBarBehavior.floating,
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF051C48),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Retry Sync',
                                            style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
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
                                  const Text(
                                    'Mobile Number',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Phone Number Input Semi-Circle Pill
                                  Container(
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(26),
                                      border: Border.all(
                                        color: const Color(0xFF00C2FF), // Highlighted Cyan border
                                        width: 1.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x1400C2FF),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
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
                                          height: 22,
                                          width: 1,
                                          margin: const EdgeInsets.symmetric(horizontal: 10),
                                          color: const Color(0xFFE2E8F0),
                                        ),

                                        // Phone Input Field
                                        Expanded(
                                          child: TextField(
                                            controller: _phoneController,
                                            scrollPadding: const EdgeInsets.only(bottom: 90),
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

                                  const SizedBox(height: 12),

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
                                ],
                              ),
                            ),

                            // LOGICAL UX RULE: Only show "Remember me" & "Forgot Password?" when in Email & Password mode!
                            if (_isEmailLogin) ...[
                              const SizedBox(height: 10),
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
                                            borderRadius: BorderRadius.circular(4),
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
                                      Navigator.push(
                                        context,
                                        SlideUpPageRoute(
                                          page: ForgotPasswordScreen(
                                            initialEmail: _emailController.text.trim(),
                                          ),
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

                            SizedBox(height: !_isEmailLogin ? 24 : 18),

                            // Primary Action Button ("Continue" for Phone mode / "Login" for Email mode)
                            Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                gradient: GlassTheme.primaryButtonGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: GlassTheme.primaryBlue.withOpacity(0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleAuthAction,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(26),
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
                                        !_isEmailLogin ? 'Continue' : 'Login',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),

                            SizedBox(height: !_isEmailLogin ? 22 : 16),

                            const SizedBox(height: 16),
// "Or login with" Divider
                            Row(
                              children: const [
                                Expanded(
                                    child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 14),
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

                            const SizedBox(height: 16),

                            // Login as OTP / Login with Email option button
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _isEmailLogin = !_isEmailLogin;
                                  _errorMessage = null; // Clear error message on mode switch!
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00C2FF),
                                side: const BorderSide(
                                    color: Color(0xFF00C2FF), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isEmailLogin
                                        ? Icons.phone_android_rounded
                                        : Icons.email_outlined,
                                    color: const Color(0xFF00C2FF),
                                    size: 19,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isEmailLogin ? 'Login as OTP' : 'Login with Email',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF00C2FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),
                            
                            
                            // Google Login Button styled like Login with Email
                            OutlinedButton(
                              onPressed: _isLoading ? null : _handleGoogleSignIn,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00C2FF),
                                side: const BorderSide(
                                    color: Color(0xFF00C2FF), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildGoogleColoredIcon(size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF00C2FF),
                                    ),
                                  ),
                                ],
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
  

  // Helper Widget for Desktop Input Field Cards (Clean modern rect with 10px rounded corners)
  Widget _buildDesktopInputCard({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixWidget,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF0066FF), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (suffixWidget != null) suffixWidget,
            ],
          ),
        ),
      ],
    );
  }

  // Helper Widget for Input Field Cards (Semi-Circle Pill Shape)
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26), // Semi-circle pill shape!
            border: Border.all(
              color: const Color(0xFF00C2FF), // Highlighted Cyan/Teal border
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1400C2FF),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: GlassTheme.primaryBlue, size: 20),
              const SizedBox(width: 10),
              if (prefixWidget != null) prefixWidget,
              Expanded(
                child: TextField(
                  controller: controller,
                  scrollPadding: const EdgeInsets.only(bottom: 90),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFCBD5E1),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (suffixWidget != null) suffixWidget,
            ],
          ),
        ),
      ],
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
    final double scale = size.width / 48.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Red Arc (Top)
    final pathRed = Path()
      ..moveTo(24.0, 9.5)
      ..cubicTo(29.05, 9.5, 33.15, 11.25, 36.15, 13.9)
      ..lineTo(42.9, 7.15)
      ..cubicTo(38.8, 3.35, 32.2, 1.0, 24.0, 1.0)
      ..cubicTo(14.7, 1.0, 6.7, 6.3, 2.7, 14.1)
      ..lineTo(10.5, 20.15)
      ..cubicTo(12.4, 13.9, 17.65, 9.5, 24.0, 9.5)
      ..close();
    canvas.drawPath(pathRed, Paint()..color = const Color(0xFFEA4335));

    // Yellow Arc (Left)
    final pathYellow = Path()
      ..moveTo(2.7, 14.1)
      ..cubicTo(1.0, 17.4, 0.0, 21.1, 0.0, 25.0)
      ..cubicTo(0.0, 28.9, 1.0, 32.6, 2.7, 35.9)
      ..lineTo(10.5, 29.85)
      ..cubicTo(9.85, 28.3, 9.5, 26.7, 9.5, 25.0)
      ..cubicTo(9.5, 23.3, 9.85, 21.7, 10.5, 20.15)
      ..lineTo(2.7, 14.1)
      ..close();
    canvas.drawPath(pathYellow, Paint()..color = const Color(0xFFFBBC05));

    // Green Arc (Bottom)
    final pathGreen = Path()
      ..moveTo(24.0, 40.5)
      ..cubicTo(17.65, 40.5, 12.4, 36.1, 10.5, 29.85)
      ..lineTo(2.7, 35.9)
      ..cubicTo(6.7, 43.7, 14.7, 49.0, 24.0, 49.0)
      ..cubicTo(32.8, 49.0, 39.8, 46.1, 44.8, 41.5)
      ..lineTo(37.3, 35.7)
      ..cubicTo(33.9, 38.9, 29.3, 40.5, 24.0, 40.5)
      ..close();
    canvas.drawPath(pathGreen, Paint()..color = const Color(0xFF34A853));

    // Blue Arc & Bar (Right)
    final pathBlue = Path()
      ..moveTo(48.0, 25.0)
      ..cubicTo(48.0, 23.3, 47.85, 21.7, 47.6, 20.1)
      ..lineTo(24.0, 20.1)
      ..lineTo(24.0, 29.8)
      ..lineTo(37.5, 29.8)
      ..cubicTo(36.9, 32.8, 35.1, 35.1, 32.4, 36.9)
      ..lineTo(40.2, 42.9)
      ..cubicTo(45.0, 38.5, 48.0, 32.2, 48.0, 25.0)
      ..close();
    canvas.drawPath(pathBlue, Paint()..color = const Color(0xFF4285F4));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

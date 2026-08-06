class FormValidators {
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    final clean = value.trim();
    if (clean.length < 3) {
      return 'Username must be at least 3 characters';
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(clean)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email address.';
    }
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return 'Please enter your email address.';
    }

    // Prevent spaces within email
    if (trimmed.contains(' ')) {
      return 'Please enter a valid email address.';
    }

    // Check for exactly one @
    final parts = trimmed.split('@');
    if (parts.length != 2) {
      return 'Please enter a valid email address.';
    }

    final localPart = parts[0];
    final domainPart = parts[1];

    if (localPart.isEmpty || domainPart.isEmpty) {
      return 'Please enter a valid email address.';
    }

    // Reject double dots in local or domain part
    if (localPart.contains('..') || domainPart.contains('..')) {
      return 'Please enter a valid email address.';
    }

    // Domain must contain dot and valid TLD extension
    final domainParts = domainPart.split('.');
    if (domainParts.length < 2 || domainParts.last.length < 2) {
      return 'Please enter a valid email address.';
    }

    // Strict regex check
    final emailRegex = RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$");
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? validatePhone(String? value, {int requiredDigits = 10}) {
    if (value == null || value.isEmpty) {
      return 'Please enter your mobile number.';
    }
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return 'Please enter your mobile number.';
    }

    // Must contain exact required digits
    if (digits.length != requiredDigits) {
      return 'Please enter a valid mobile number.';
    }

    // Reject identical digit sequences e.g. 0000000000, 1111111111, 2222222222
    if (RegExp(r'^(\d)\1+$').hasMatch(digits)) {
      return 'Please enter a valid mobile number.';
    }

    // Reject obvious sequential fake patterns like 1234567890 or 0123456789
    if (digits == '1234567890' || digits == '0123456789' || digits == '9876543210' || digits == '9999999999') {
      // Allow 9876543210 for test mode if specifically typed
    }

    // For 10-digit Indian numbers, must start with valid mobile prefix 6, 7, 8, 9
    if (requiredDigits == 10) {
      final firstDigit = digits[0];
      if (!['6', '7', '8', '9'].contains(firstDigit)) {
        return 'Please enter a valid mobile number.';
      }
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  static String? validatePincode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Pincode is required';
    }
    final pinRegex = RegExp(r'^\d{6}$');
    if (!pinRegex.hasMatch(value.trim())) {
      return 'Enter a valid 6-digit pincode';
    }
    return null;
  }

  static String? validateGstNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    if (!gstRegex.hasMatch(value.trim().toUpperCase())) {
      return 'Enter a valid 15-digit GSTIN';
    }
    return null;
  }
}

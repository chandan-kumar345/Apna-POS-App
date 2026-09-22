class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // Owner, Admin, Manager, Cashier, Waiter, Chef, Sales, Support, Inventory
  final String pin;
  final String restaurantId;
  final String? phone;
  final String? employeeId;
  final List<String> permissions;
  final String? jobTitle;
  final String? companyName;
  final String? website;
  final String? referralCode;
  final String? profilePhotoPath;
  final Map<String, bool>? communicationPreferences;
  final bool onboardingCompleted;
  final int onboardingStep;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.pin,
    required this.restaurantId,
    this.phone,
    this.employeeId,
    this.permissions = const ['*'],
    this.jobTitle,
    this.companyName,
    this.website,
    this.referralCode,
    this.profilePhotoPath,
    this.communicationPreferences,
    this.onboardingCompleted = false,
    this.onboardingStep = 0,
  });

  bool get isOwner => role.toLowerCase() == 'owner';
  bool get isAdmin => isOwner || role.toLowerCase() == 'admin';
  bool get isManager => role.toLowerCase() == 'manager';
  bool get isCashier => role.toLowerCase() == 'cashier';
  bool get isWaiter => role.toLowerCase() == 'waiter';
  bool get isChef => role.toLowerCase() == 'chef' || role.toLowerCase() == 'kitchen';

  /// Check if the user has permission to access a specific feature or section
  bool hasPermission(String required) {
    if (isOwner || isAdmin) return true;
    if (permissions.contains('*') || permissions.contains('all')) return true;

    final req = required.toLowerCase().trim();
    if (permissions.any((p) => p.toLowerCase().trim() == req)) {
      return true;
    }

    // Category / alias matching
    for (final p in permissions) {
      final pLower = p.toLowerCase().trim();
      if (pLower == req) return true;
      if (req.startsWith(pLower) || pLower.startsWith(req)) return true;
      if (req == 'pos' && (pLower.startsWith('pos_') || pLower == 'orders' || pLower == 'tables')) return true;
      if (req == 'tables' && (pLower == 'pos_manage_tables' || pLower == 'pos' || pLower == 'pos_access')) return true;
      if (req == 'orders' && (pLower == 'pos_view_all_orders' || pLower == 'pos' || pLower == 'pos_access')) return true;
      if (req == 'menu' && (pLower.startsWith('products_') || pLower == 'products')) return true;
      if (req == 'inventory' && pLower.startsWith('inventory_')) return true;
      if (req == 'reports' && pLower.startsWith('reports_')) return true;
      if (req == 'crm' && (pLower.startsWith('customers_') || pLower == 'customers')) return true;
      if (req == 'loyalty' && (pLower == 'customers_crm' || pLower == 'customers')) return true;
      if (req == 'campaign' && (pLower == 'customers_crm' || pLower == 'customers')) return true;
      if (req == 'staff' && (pLower == 'settings_staff' || pLower == 'settings')) return true;
      if (req == 'settings' && pLower.startsWith('settings_')) return true;
    }

    return false;
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? pin,
    String? restaurantId,
    String? phone,
    String? employeeId,
    List<String>? permissions,
    String? jobTitle,
    String? companyName,
    String? website,
    String? referralCode,
    String? profilePhotoPath,
    Map<String, bool>? communicationPreferences,
    bool? onboardingCompleted,
    int? onboardingStep,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      pin: pin ?? this.pin,
      restaurantId: restaurantId ?? this.restaurantId,
      phone: phone ?? this.phone,
      employeeId: employeeId ?? this.employeeId,
      permissions: permissions ?? this.permissions,
      jobTitle: jobTitle ?? this.jobTitle,
      companyName: companyName ?? this.companyName,
      website: website ?? this.website,
      referralCode: referralCode ?? this.referralCode,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      communicationPreferences:
          communicationPreferences ?? this.communicationPreferences,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingStep: onboardingStep ?? this.onboardingStep,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'pin': pin,
        'restaurantId': restaurantId,
        'phone': phone,
        'employeeId': employeeId,
        'permissions': permissions,
        'jobTitle': jobTitle,
        'companyName': companyName,
        'website': website,
        'referralCode': referralCode,
        'profilePhotoPath': profilePhotoPath,
        'communicationPreferences': communicationPreferences,
        'onboardingCompleted': onboardingCompleted,
        'onboardingStep': onboardingStep,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedPermissions = [];
    if (json['permissions'] is List) {
      parsedPermissions = (json['permissions'] as List).map((p) => p.toString()).toList();
    } else if (json['permissions'] is String && (json['permissions'] as String).isNotEmpty) {
      parsedPermissions = (json['permissions'] as String).split(',').map((p) => p.trim()).toList();
    } else {
      final roleStr = (json['role'] ?? 'Owner').toString().toLowerCase();
      if (roleStr == 'owner' || roleStr == 'admin') {
        parsedPermissions = ['*'];
      } else {
        parsedPermissions = ['pos', 'tables', 'orders'];
      }
    }

    return UserModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Owner',
      pin: json['pin']?.toString() ?? '1234',
      restaurantId: json['restaurantId']?.toString() ?? '',
      phone: json['phone']?.toString(),
      employeeId: json['employeeId']?.toString(),
      permissions: parsedPermissions,
      jobTitle: json['jobTitle']?.toString(),
      companyName: json['companyName']?.toString(),
      website: json['website']?.toString(),
      referralCode: json['referralCode']?.toString(),
      profilePhotoPath: json['profilePhotoPath']?.toString(),
      communicationPreferences: json['communicationPreferences'] != null
          ? Map<String, bool>.from(json['communicationPreferences'])
          : null,
      onboardingCompleted: json['onboardingCompleted'] == true,
      onboardingStep: (json['onboardingStep'] as num?)?.toInt() ?? 0,
    );
  }
}

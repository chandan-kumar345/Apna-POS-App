import 'package:flutter/material.dart';

class StaffModel {
  final String id;
  final String name;
  final String employeeId;
  final String phone;
  final String email;
  final String role;
  final String status;
  final String pin;
  final String avatarUrl;
  final List<String> permissions;
  final double salary;
  final DateTime? joiningDate;
  final String notes;
  final String department;
  final String workLocation;
  final String reportingTo;
  final String shift;
  final String language;
  final String theme;
  final String defaultScreen;
  final bool enableBiometric;
  final bool sendWelcomeEmail;
  final bool forcePasswordChange;
  final String? password;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const StaffModel({
    required this.id,
    required this.name,
    required this.employeeId,
    this.phone = '',
    this.email = '',
    this.role = 'Cashier',
    this.status = 'Active',
    this.pin = '1234',
    this.avatarUrl = '',
    this.permissions = const ['pos', 'tables', 'orders'],
    this.salary = 0.0,
    this.joiningDate,
    this.notes = '',
    this.department = '',
    this.workLocation = '',
    this.reportingTo = '',
    this.shift = 'Morning Shift (8 AM - 4 PM)',
    this.language = 'English',
    this.theme = 'Light',
    this.defaultScreen = 'Dashboard',
    this.enableBiometric = false,
    this.sendWelcomeEmail = true,
    this.forcePasswordChange = false,
    this.password,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isManager => role.toLowerCase() == 'manager';
  bool get isCashier => role.toLowerCase() == 'cashier';

  String get initials {
    if (name.trim().isEmpty) return 'ST';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  Color get roleTextColor {
    switch (role.toLowerCase()) {
      case 'admin':
        return const Color(0xFF7C3AED);
      case 'manager':
        return const Color(0xFF2563EB);
      case 'cashier':
        return const Color(0xFF0284C7);
      case 'sales':
        return const Color(0xFFEA580C);
      case 'inventory':
      case 'support':
        return const Color(0xFF475569);
      case 'chef':
      case 'kitchen':
        return const Color(0xFFD97706);
      case 'waiter':
        return const Color(0xFF9333EA);
      default:
        return const Color(0xFF475569);
    }
  }

  Color get roleBgColor {
    switch (role.toLowerCase()) {
      case 'admin':
        return const Color(0xFFEDE9FE);
      case 'manager':
        return const Color(0xFFDBEAFE);
      case 'cashier':
        return const Color(0xFFE0F2FE);
      case 'sales':
        return const Color(0xFFFFEDD5);
      case 'inventory':
      case 'support':
        return const Color(0xFFF1F5F9);
      case 'chef':
      case 'kitchen':
        return const Color(0xFFFEF3C7);
      case 'waiter':
        return const Color(0xFFF3E8FF);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  StaffModel copyWith({
    String? id,
    String? name,
    String? employeeId,
    String? phone,
    String? email,
    String? role,
    String? status,
    String? pin,
    String? avatarUrl,
    List<String>? permissions,
    double? salary,
    DateTime? joiningDate,
    String? notes,
    String? department,
    String? workLocation,
    String? reportingTo,
    String? shift,
    String? language,
    String? theme,
    String? defaultScreen,
    bool? enableBiometric,
    bool? sendWelcomeEmail,
    bool? forcePasswordChange,
    String? password,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffModel(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      pin: pin ?? this.pin,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      permissions: permissions ?? this.permissions,
      salary: salary ?? this.salary,
      joiningDate: joiningDate ?? this.joiningDate,
      notes: notes ?? this.notes,
      department: department ?? this.department,
      workLocation: workLocation ?? this.workLocation,
      reportingTo: reportingTo ?? this.reportingTo,
      shift: shift ?? this.shift,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      defaultScreen: defaultScreen ?? this.defaultScreen,
      enableBiometric: enableBiometric ?? this.enableBiometric,
      sendWelcomeEmail: sendWelcomeEmail ?? this.sendWelcomeEmail,
      forcePasswordChange: forcePasswordChange ?? this.forcePasswordChange,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'employeeId': employeeId,
      'phone': phone,
      'email': email,
      'role': role,
      'status': status,
      'pin': pin,
      'avatarUrl': avatarUrl,
      'permissions': permissions,
      'salary': salary,
      'joiningDate': joiningDate?.toIso8601String(),
      'notes': notes,
      'department': department,
      'workLocation': workLocation,
      'reportingTo': reportingTo,
      'shift': shift,
      'language': language,
      'theme': theme,
      'defaultScreen': defaultScreen,
      'enableBiometric': enableBiometric,
      'sendWelcomeEmail': sendWelcomeEmail,
      'forcePasswordChange': forcePasswordChange,
      if (password != null && password!.isNotEmpty) 'password': password,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreated = DateTime.now();
    if (json['createdAt'] != null) {
      final parsed = DateTime.tryParse(json['createdAt'].toString());
      if (parsed != null) parsedCreated = parsed;
    }

    DateTime? parsedJoining;
    if (json['joiningDate'] != null) {
      parsedJoining = DateTime.tryParse(json['joiningDate'].toString());
    }

    DateTime? parsedUpdated;
    if (json['updatedAt'] != null) {
      parsedUpdated = DateTime.tryParse(json['updatedAt'].toString());
    }

    List<String> parsedPermissions = [];
    if (json['permissions'] is List) {
      parsedPermissions = (json['permissions'] as List).map((p) => p.toString()).toList();
    } else if (json['permissions'] is String && (json['permissions'] as String).isNotEmpty) {
      parsedPermissions = (json['permissions'] as String).split(',').map((p) => p.trim()).toList();
    } else {
      parsedPermissions = ['pos', 'tables', 'orders'];
    }

    double parsedSalary = 0.0;
    if (json['salary'] is num) {
      parsedSalary = (json['salary'] as num).toDouble();
    } else if (json['salary'] != null) {
      parsedSalary = double.tryParse(json['salary'].toString()) ?? 0.0;
    }

    return StaffModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Staff Member',
      employeeId: json['employeeId']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Cashier',
      status: json['status']?.toString() ?? 'Active',
      pin: json['pin']?.toString() ?? '1234',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      permissions: parsedPermissions,
      salary: parsedSalary,
      joiningDate: parsedJoining,
      notes: json['notes']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      workLocation: json['workLocation']?.toString() ?? '',
      reportingTo: json['reportingTo']?.toString() ?? '',
      shift: json['shift']?.toString() ?? 'Morning Shift (8 AM - 4 PM)',
      language: json['language']?.toString() ?? 'English',
      theme: json['theme']?.toString() ?? 'Light',
      defaultScreen: json['defaultScreen']?.toString() ?? 'Dashboard',
      enableBiometric: json['enableBiometric'] == true,
      sendWelcomeEmail: json['sendWelcomeEmail'] != false,
      forcePasswordChange: json['forcePasswordChange'] == true,
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
    );
  }
}

class StaffStatsModel {
  final int total;
  final int active;
  final int inactive;
  final int admins;

  const StaffStatsModel({
    this.total = 0,
    this.active = 0,
    this.inactive = 0,
    this.admins = 0,
  });

  factory StaffStatsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StaffStatsModel();
    int parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val != null) return int.tryParse(val.toString()) ?? 0;
      return 0;
    }

    return StaffStatsModel(
      total: parseInt(json['total']),
      active: parseInt(json['active']),
      inactive: parseInt(json['inactive']),
      admins: parseInt(json['admins']),
    );
  }

  Map<String, dynamic> toJson() => {
        'total': total,
        'active': active,
        'inactive': inactive,
        'admins': admins,
      };
}

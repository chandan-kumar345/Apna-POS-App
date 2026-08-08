/// Domain entity representing a user in the system.
/// Contains pure business logic fields independent of database or API drivers.
class UserEntity {
  final int? id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;
  final String? profileImage;
  final String createdAt;
  final String? onboardingDetails;

  const UserEntity({
    this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    this.profileImage,
    required this.createdAt,
    this.onboardingDetails,
  });

  /// Create a copy of [UserEntity] with modified fields
  UserEntity copyWith({
    int? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? password,
    String? profileImage,
    String? createdAt,
    String? onboardingDetails,
  }) {
    return UserEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      password: password ?? this.password,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      onboardingDetails: onboardingDetails ?? this.onboardingDetails,
    );
  }

  /// Converts Map from SQLite row into domain [UserEntity]
  factory UserEntity.fromMap(Map<String, dynamic> map) {
    return UserEntity(
      id: map['id'] is int ? map['id'] as int : int.tryParse(map['id']?.toString() ?? ''),
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      password: map['password'] ?? '',
      profileImage: map['profileImage'],
      createdAt: map['createdAt'] ?? '',
      onboardingDetails: map['onboardingDetails'],
    );
  }

  /// Converts [UserEntity] into a Map for SQLite database insertion
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'fullName': fullName,
      'email': email.trim().toLowerCase(),
      'phoneNumber': phoneNumber.trim(),
      'password': password,
      'profileImage': profileImage,
      'createdAt': createdAt,
      'onboardingDetails': onboardingDetails,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }
}

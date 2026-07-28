class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // Owner, Manager, Cashier, Waiter
  final String pin;
  final String restaurantId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.pin,
    required this.restaurantId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'pin': pin,
        'restaurantId': restaurantId,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        role: json['role'] ?? 'Owner',
        pin: json['pin'] ?? '1234',
        restaurantId: json['restaurantId'] ?? '',
      );
}

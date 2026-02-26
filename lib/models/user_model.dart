class UserModel {
  final String id;
  final String fullName;
  final String role;
  final String email;
  final String? phone;
  final String? avatar;

  UserModel({
    required this.id,
    required this.fullName,
    required this.role,
    required this.email,
    this.phone,
    this.avatar,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      fullName: json['fullName'] ?? '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
      role: json['role'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      avatar: json['avatar'],
    );
  }
}
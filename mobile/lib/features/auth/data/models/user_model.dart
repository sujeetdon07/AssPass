import '../../domain/entities/user_entity.dart';

class UserModel {
  UserModel._();

  static UserEntity fromJson(Map<String, dynamic> json) {
    final localityData = json['locality'] as Map<String, dynamic>?;

    return UserEntity(
      id: json['id'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      username: json['username'] as String?,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      isPhoneVerified: (json['phoneVerified'] as bool?) ?? true,
      accountStatus: json['accountStatus'] as String? ?? 'active',
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      countryCode: (localityData?['countryCode'] ?? json['countryCode'] ?? 'IN')
          as String,
      state: (localityData?['state'] ?? json['state']) as String?,
      district: (localityData?['district'] ?? json['district']) as String?,
      city: (localityData?['city'] ?? json['city']) as String?,
      locality: (localityData?['locality'] ?? json['locality']) as String?,
      neighborhood:
          (localityData?['neighborhood'] ?? json['neighborhood']) as String?,
    );
  }
}

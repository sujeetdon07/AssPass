/// Pure domain entity representing an Aaspaas user.
class UserEntity {
  const UserEntity({
    required this.id,
    required this.phoneNumber,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.isPhoneVerified = true,
    this.accountStatus = 'active',
    this.onboardingCompleted = false,
    this.countryCode = 'IN',
    this.state,
    this.district,
    this.city,
    this.locality,
    this.neighborhood,
  });

  final String id;
  final String phoneNumber; // Masked representation from backend
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final bool isPhoneVerified;
  final String accountStatus;
  final bool onboardingCompleted;
  final String countryCode;
  final String? state;
  final String? district;
  final String? city;
  final String? locality;
  final String? neighborhood;

  /// Returns the presentation handle with leading '@' (e.g. '@sujeet') or null if not set.
  String? get handle =>
      username != null && username!.trim().isNotEmpty ? '@${username!.trim()}' : null;

  /// User-friendly display location summary.
  String get localitySummary {
    if (locality != null && city != null) return '$locality, $city';
    if (city != null) return city!;
    if (locality != null) return locality!;
    return 'No locality selected';
  }

  UserEntity copyWith({
    String? id,
    String? phoneNumber,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    bool? isPhoneVerified,
    String? accountStatus,
    bool? onboardingCompleted,
    String? countryCode,
    String? state,
    String? district,
    String? city,
    String? locality,
    String? neighborhood,
  }) {
    return UserEntity(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      accountStatus: accountStatus ?? this.accountStatus,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      countryCode: countryCode ?? this.countryCode,
      state: state ?? this.state,
      district: district ?? this.district,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      neighborhood: neighborhood ?? this.neighborhood,
    );
  }
}

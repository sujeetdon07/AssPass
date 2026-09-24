/// Privacy-safe public seller summary projection for marketplace listings.
class SellerProfileEntity {
  const SellerProfileEntity({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.locality,
    this.city,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? locality;
  final String? city;

  factory SellerProfileEntity.fromJson(Map<String, dynamic> json) {
    return SellerProfileEntity(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Neighbor',
      avatarUrl: json['avatarUrl'] as String?,
      locality: json['locality'] as String?,
      city: json['city'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'locality': locality,
      'city': city,
    };
  }
}

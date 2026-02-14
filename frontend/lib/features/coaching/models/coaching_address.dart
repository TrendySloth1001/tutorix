/// Coaching main address with GPS coordinates
class CoachingAddress {
  final String id;
  final String coachingId;
  final String addressLine1;
  final String? addressLine2;
  final String? landmark;
  final String city;
  final String state;
  final String pincode;
  final String country;
  final double? latitude;
  final double? longitude;
  final String? openingTime;
  final String? closingTime;
  final List<String> workingDays;

  const CoachingAddress({
    required this.id,
    required this.coachingId,
    required this.addressLine1,
    this.addressLine2,
    this.landmark,
    required this.city,
    required this.state,
    required this.pincode,
    this.country = 'India',
    this.latitude,
    this.longitude,
    this.openingTime,
    this.closingTime,
    this.workingDays = const [],
  });

  factory CoachingAddress.fromJson(Map<String, dynamic> json) {
    return CoachingAddress(
      id: json['id'] as String,
      coachingId: json['coachingId'] as String,
      addressLine1: json['addressLine1'] as String,
      addressLine2: json['addressLine2'] as String?,
      landmark: json['landmark'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      pincode: json['pincode'] as String,
      country: json['country'] as String? ?? 'India',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      openingTime: json['openingTime'] as String?,
      closingTime: json['closingTime'] as String?,
      workingDays:
          (json['workingDays'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'landmark': landmark,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'workingDays': workingDays,
    };
  }

  String get fullAddress {
    final parts = <String>[addressLine1];
    if (addressLine2 != null && addressLine2!.isNotEmpty) {
      parts.add(addressLine2!);
    }
    if (landmark != null && landmark!.isNotEmpty) {
      parts.add('Near $landmark');
    }
    parts.add('$city, $state - $pincode');
    return parts.join(', ');
  }
}

/// Coaching branch
class CoachingBranch {
  final String id;
  final String coachingId;
  final String name;
  final String addressLine1;
  final String? addressLine2;
  final String? landmark;
  final String city;
  final String state;
  final String pincode;
  final String country;
  final String? contactPhone;
  final String? contactEmail;
  final String? openingTime;
  final String? closingTime;
  final List<String> workingDays;
  final bool isActive;

  const CoachingBranch({
    required this.id,
    required this.coachingId,
    required this.name,
    required this.addressLine1,
    this.addressLine2,
    this.landmark,
    required this.city,
    required this.state,
    required this.pincode,
    this.country = 'India',
    this.contactPhone,
    this.contactEmail,
    this.openingTime,
    this.closingTime,
    this.workingDays = const [],
    this.isActive = true,
  });

  factory CoachingBranch.fromJson(Map<String, dynamic> json) {
    return CoachingBranch(
      id: json['id'] as String,
      coachingId: json['coachingId'] as String,
      name: json['name'] as String,
      addressLine1: json['addressLine1'] as String,
      addressLine2: json['addressLine2'] as String?,
      landmark: json['landmark'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      pincode: json['pincode'] as String,
      country: json['country'] as String? ?? 'India',
      contactPhone: json['contactPhone'] as String?,
      contactEmail: json['contactEmail'] as String?,
      openingTime: json['openingTime'] as String?,
      closingTime: json['closingTime'] as String?,
      workingDays:
          (json['workingDays'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'landmark': landmark,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'workingDays': workingDays,
    };
  }

  String get fullAddress {
    final parts = <String>[addressLine1];
    if (addressLine2 != null && addressLine2!.isNotEmpty) {
      parts.add(addressLine2!);
    }
    parts.add('$city, $state - $pincode');
    return parts.join(', ');
  }
}

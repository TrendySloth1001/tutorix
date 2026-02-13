import 'package:flutter/foundation.dart';

class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? phone;
  final String? picture;
  final bool isAdmin;
  final bool isTeacher;
  final bool isParent;
  final bool isWard;
  final bool onboardingComplete;
  final List<CoachingModel> ownedCoachings;
  final List<WardModel> wards;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    this.picture,
    this.isAdmin = false,
    this.isTeacher = false,
    this.isParent = false,
    this.isWard = false,
    this.onboardingComplete = false,
    this.ownedCoachings = const [],
    this.wards = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      return UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String?,
        phone: json['phone'] as String?,
        picture: json['picture'] as String?,
        isAdmin: json['isAdmin'] as bool? ?? false,
        isTeacher: json['isTeacher'] as bool? ?? false,
        isParent: json['isParent'] as bool? ?? false,
        isWard: json['isWard'] as bool? ?? false,
        onboardingComplete: json['onboardingComplete'] as bool? ?? false,
        ownedCoachings:
            (json['ownedCoachings'] as List<dynamic>?)
                ?.map((e) => CoachingModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        wards:
            (json['wards'] as List<dynamic>?)
                ?.map((e) => WardModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
    } catch (e) {
      debugPrint('Error parsing UserModel from JSON: $e');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'picture': picture,
      'isAdmin': isAdmin,
      'isTeacher': isTeacher,
      'isParent': isParent,
      'isWard': isWard,
      'onboardingComplete': onboardingComplete,
      'ownedCoachings': ownedCoachings.map((e) => e.toJson()).toList(),
      'wards': wards.map((e) => e.toJson()).toList(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? picture,
    bool? isAdmin,
    bool? isTeacher,
    bool? isParent,
    bool? isWard,
    bool? onboardingComplete,
    List<CoachingModel>? ownedCoachings,
    List<WardModel>? wards,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      picture: picture ?? this.picture,
      isAdmin: isAdmin ?? this.isAdmin,
      isTeacher: isTeacher ?? this.isTeacher,
      isParent: isParent ?? this.isParent,
      isWard: isWard ?? this.isWard,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      ownedCoachings: ownedCoachings ?? this.ownedCoachings,
      wards: wards ?? this.wards,
    );
  }

  bool get hasAnyRole => isAdmin || isTeacher || isParent || isWard;
}

class WardModel {
  final String id;
  final String name;
  final String? picture;
  final String parentId;

  WardModel({
    required this.id,
    required this.name,
    this.picture,
    required this.parentId,
  });

  factory WardModel.fromJson(Map<String, dynamic> json) {
    return WardModel(
      id: json['id'] as String,
      name: json['name'] as String,
      picture: json['picture'] as String?,
      parentId: json['parentId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'picture': picture, 'parentId': parentId};
  }
}

class CoachingModel {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? logo;
  final String status;
  final String ownerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CoachingModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.logo,
    this.status = 'active',
    required this.ownerId,
    this.createdAt,
    this.updatedAt,
  });

  factory CoachingModel.fromJson(Map<String, dynamic> json) {
    return CoachingModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      logo: json['logo'] as String?,
      status: json['status'] as String? ?? 'active',
      ownerId: json['ownerId'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'logo': logo,
      'status': status,
      'ownerId': ownerId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class LoginSession {
  final String id;
  final String userId;
  final String? ip;
  final String? userAgent;
  final DateTime createdAt;

  LoginSession({
    required this.id,
    required this.userId,
    this.ip,
    this.userAgent,
    required this.createdAt,
  });

  factory LoginSession.fromJson(Map<String, dynamic> json) {
    return LoginSession(
      id: json['id'] as String,
      userId: json['userId'] as String,
      ip: json['ip'] as String?,
      userAgent: json['userAgent'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'ip': ip,
      'userAgent': userAgent,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

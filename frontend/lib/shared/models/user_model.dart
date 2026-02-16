import '../../features/coaching/models/coaching_model.dart';
import 'ward_model.dart';

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
  final bool showEmailInSearch;
  final bool showPhoneInSearch;
  final bool showWardsInSearch;
  final List<CoachingModel> ownedCoachings;
  final List<WardModel> wards;

  const UserModel({
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
    this.showEmailInSearch = true,
    this.showPhoneInSearch = true,
    this.showWardsInSearch = false,
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
        showEmailInSearch: json['showEmailInSearch'] as bool? ?? true,
        showPhoneInSearch: json['showPhoneInSearch'] as bool? ?? true,
        showWardsInSearch: json['showWardsInSearch'] as bool? ?? false,
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
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
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
    'showEmailInSearch': showEmailInSearch,
    'showPhoneInSearch': showPhoneInSearch,
    'showWardsInSearch': showWardsInSearch,
    'ownedCoachings': ownedCoachings.map((e) => e.toJson()).toList(),
    'wards': wards.map((e) => e.toJson()).toList(),
  };

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
    bool? showEmailInSearch,
    bool? showPhoneInSearch,
    bool? showWardsInSearch,
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
      showEmailInSearch: showEmailInSearch ?? this.showEmailInSearch,
      showPhoneInSearch: showPhoneInSearch ?? this.showPhoneInSearch,
      showWardsInSearch: showWardsInSearch ?? this.showWardsInSearch,
      ownedCoachings: ownedCoachings ?? this.ownedCoachings,
      wards: wards ?? this.wards,
    );
  }

  bool get hasAnyRole => isAdmin || isTeacher || isParent || isWard;
}

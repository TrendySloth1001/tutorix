import '../../../core/constants/api_constants.dart';
import '../../../shared/services/api_client.dart';
import '../models/coaching_address.dart';
import '../models/coaching_masters.dart';
import '../models/coaching_model.dart';

class CoachingOnboardingService {
  final ApiClient _api = ApiClient.instance;

  // Cache for master data
  static CoachingMasters? _mastersCache;

  /// GET /coaching/masters - Fetch all coaching master data
  Future<CoachingMasters> getMasters({bool forceRefresh = false}) async {
    if (!forceRefresh && _mastersCache != null) {
      return _mastersCache!;
    }

    final data = await _api.getPublic(ApiConstants.coachingMasters);
    _mastersCache = CoachingMasters.fromJson(data);
    return _mastersCache!;
  }

  /// POST /coaching - Create a new coaching (basic info)
  Future<CoachingModel> createCoaching({
    required String name,
    String? description,
    String? logo,
  }) async {
    final data = await _api.postAuthenticated(
      ApiConstants.coaching,
      body: {'name': name, 'description': ?description, 'logo': ?logo},
    );
    return CoachingModel.fromJson(data['coaching']);
  }

  /// POST /coaching/:id/onboarding/profile - Update profile details
  Future<CoachingModel> updateProfile({
    required String coachingId,
    String? tagline,
    String? aboutUs,
    int? foundedYear,
    String? websiteUrl,
    String? contactEmail,
    String? contactPhone,
    String? whatsappPhone,
    String? category,
    List<String>? subjects,
    String? facebookUrl,
    String? instagramUrl,
    String? youtubeUrl,
    String? linkedinUrl,
  }) async {
    final body = <String, dynamic>{};
    if (tagline != null) body['tagline'] = tagline;
    if (aboutUs != null) body['aboutUs'] = aboutUs;
    if (foundedYear != null) body['foundedYear'] = foundedYear;
    if (websiteUrl != null) body['websiteUrl'] = websiteUrl;
    if (contactEmail != null) body['contactEmail'] = contactEmail;
    if (contactPhone != null) body['contactPhone'] = contactPhone;
    if (whatsappPhone != null) body['whatsappPhone'] = whatsappPhone;
    if (category != null) body['category'] = category;
    if (subjects != null) body['subjects'] = subjects;
    if (facebookUrl != null) body['facebookUrl'] = facebookUrl;
    if (instagramUrl != null) body['instagramUrl'] = instagramUrl;
    if (youtubeUrl != null) body['youtubeUrl'] = youtubeUrl;
    if (linkedinUrl != null) body['linkedinUrl'] = linkedinUrl;

    final data = await _api.postAuthenticated(
      ApiConstants.coachingOnboardingProfile(coachingId),
      body: body,
    );
    return CoachingModel.fromJson(data['coaching']);
  }

  /// POST /coaching/:id/onboarding/address - Set main address with GPS
  Future<CoachingAddress> setAddress({
    required String coachingId,
    required String addressLine1,
    String? addressLine2,
    String? landmark,
    required String city,
    required String state,
    required String pincode,
    String country = 'India',
    double? latitude,
    double? longitude,
    String? openingTime,
    String? closingTime,
    List<String>? workingDays,
  }) async {
    final body = <String, dynamic>{
      'addressLine1': addressLine1,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,
    };
    if (addressLine2 != null) body['addressLine2'] = addressLine2;
    if (landmark != null) body['landmark'] = landmark;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (openingTime != null) body['openingTime'] = openingTime;
    if (closingTime != null) body['closingTime'] = closingTime;
    if (workingDays != null) body['workingDays'] = workingDays;

    final data = await _api.postAuthenticated(
      ApiConstants.coachingOnboardingAddress(coachingId),
      body: body,
    );
    return CoachingAddress.fromJson(data['address']);
  }

  /// POST /coaching/:id/onboarding/branch - Add a branch
  Future<CoachingBranch> addBranch({
    required String coachingId,
    required String name,
    required String addressLine1,
    String? addressLine2,
    String? landmark,
    required String city,
    required String state,
    required String pincode,
    String country = 'India',
    String? contactPhone,
    String? contactEmail,
    String? openingTime,
    String? closingTime,
    List<String>? workingDays,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'addressLine1': addressLine1,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,
    };
    if (addressLine2 != null) body['addressLine2'] = addressLine2;
    if (landmark != null) body['landmark'] = landmark;
    if (contactPhone != null) body['contactPhone'] = contactPhone;
    if (contactEmail != null) body['contactEmail'] = contactEmail;
    if (openingTime != null) body['openingTime'] = openingTime;
    if (closingTime != null) body['closingTime'] = closingTime;
    if (workingDays != null) body['workingDays'] = workingDays;

    final data = await _api.postAuthenticated(
      ApiConstants.coachingOnboardingBranch(coachingId),
      body: body,
    );
    return CoachingBranch.fromJson(data['branch']);
  }

  /// GET /coaching/:id/branches - Get all branches
  Future<List<CoachingBranch>> getBranches(String coachingId) async {
    final data = await _api.getPublic(
      ApiConstants.coachingBranches(coachingId),
    );
    return (data['branches'] as List<dynamic>)
        .map((e) => CoachingBranch.fromJson(e))
        .toList();
  }

  /// DELETE /coaching/:id/branches/:branchId - Delete a branch
  Future<void> deleteBranch(String coachingId, String branchId) async {
    await _api.deleteAuthenticated(
      ApiConstants.deleteBranch(coachingId, branchId),
    );
  }

  /// POST /coaching/:id/onboarding/complete - Mark onboarding complete
  Future<CoachingModel> completeOnboarding(String coachingId) async {
    final data = await _api.postAuthenticated(
      ApiConstants.coachingOnboardingComplete(coachingId),
      body: {},
    );
    return CoachingModel.fromJson(data['coaching']);
  }
}

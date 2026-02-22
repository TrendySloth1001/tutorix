/// Represents a subscription plan tier.
class PlanModel {
  final String id;
  final String slug; // free, basic, standard, premium
  final String name;
  final double priceMonthly; // INR (rupees)
  final double priceYearly; // INR (rupees)
  final double mrpMonthly; // Original/MRP price (0 = no offer)
  final double mrpYearly;

  // Display order
  final int order;

  // Quotas
  final int maxStudents;
  final int maxParents;
  final int maxTeachers;
  final int maxAdmins;
  final int maxBatches;
  final int maxAssessmentsPerMonth;
  final int storageLimitBytes;

  // Feature flags
  final bool hasRazorpay;
  final bool hasAutoRemind;
  final bool hasFeeReports;
  final bool hasFeeLedger;
  final bool hasRoutePayouts;
  final bool hasPushNotify;
  final bool hasEmailNotify;
  final bool hasSmsNotify;
  final bool hasWhatsappNotify;
  final bool hasCustomLogo;
  final bool hasWhiteLabel;
  final bool hasWebManagement;

  const PlanModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.priceMonthly,
    required this.priceYearly,
    this.mrpMonthly = 0,
    this.mrpYearly = 0,
    this.order = 0,
    this.maxStudents = 0,
    this.maxParents = 0,
    this.maxTeachers = 0,
    this.maxAdmins = 0,
    this.maxBatches = 0,
    this.maxAssessmentsPerMonth = 0,
    this.storageLimitBytes = 0,
    this.hasRazorpay = false,
    this.hasAutoRemind = false,
    this.hasFeeReports = false,
    this.hasFeeLedger = false,
    this.hasRoutePayouts = false,
    this.hasPushNotify = false,
    this.hasEmailNotify = false,
    this.hasSmsNotify = false,
    this.hasWhatsappNotify = false,
    this.hasCustomLogo = false,
    this.hasWhiteLabel = false,
    this.hasWebManagement = false,
  });

  bool get isFree => slug == 'free';
  bool get isPopular => slug == 'standard';
  bool get isWebPortal => slug == 'web-portal';

  /// Whether this plan has a discounted offer (MRP > actual price).
  bool get hasOffer => mrpMonthly > 0 && mrpMonthly > priceMonthly;

  /// Monthly discount percentage.
  int get discountPercent {
    if (!hasOffer) return 0;
    return (((mrpMonthly - priceMonthly) / mrpMonthly) * 100).round();
  }

  /// Effective monthly when billed yearly.
  double get effectiveMonthlyRupees => priceYearly / 12;

  /// Yearly savings percent compared to monthly billing.
  int get yearlySavingsPercent {
    if (priceMonthly == 0) return 0;
    final yearlyIfMonthly = priceMonthly * 12;
    return (((yearlyIfMonthly - priceYearly) / yearlyIfMonthly) * 100).round();
  }

  String formatQuota(int value) => value == -1 ? 'Unlimited' : '$value';

  String get storageLabel {
    if (storageLimitBytes == -1) return 'Unlimited';
    final mb = storageLimitBytes / (1024 * 1024);
    if (mb >= 1024) return '${(mb / 1024).round()} GB';
    return '${mb.round()} MB';
  }

  /// Human-readable feature list for the plan.
  List<String> get featureLabels {
    return [
      if (hasRazorpay) 'Online Pay',
      if (hasAutoRemind) 'Auto Remind',
      if (hasFeeReports) 'Fee Reports',
      if (hasFeeLedger) 'Fee Ledger',
      if (hasRoutePayouts) 'Route Payouts',
      if (hasPushNotify) 'Push Notify',
      if (hasEmailNotify) 'Email Notify',
      if (hasSmsNotify) 'SMS Notify',
      if (hasWhatsappNotify) 'WhatsApp',
      if (hasCustomLogo) 'Custom Logo',
      if (hasWhiteLabel) 'White Label',
      if (hasWebManagement) 'Web Management',
    ];
  }

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      priceMonthly: (json['priceMonthly'] as num?)?.toDouble() ?? 0,
      priceYearly: (json['priceYearly'] as num?)?.toDouble() ?? 0,
      mrpMonthly: (json['mrpMonthly'] as num?)?.toDouble() ?? 0,
      mrpYearly: (json['mrpYearly'] as num?)?.toDouble() ?? 0,
      order: (json['order'] as num?)?.toInt() ?? 0,
      maxStudents: (json['maxStudents'] as num?)?.toInt() ?? 0,
      maxParents: (json['maxParents'] as num?)?.toInt() ?? 0,
      maxTeachers: (json['maxTeachers'] as num?)?.toInt() ?? 0,
      maxAdmins: (json['maxAdmins'] as num?)?.toInt() ?? 0,
      maxBatches: (json['maxBatches'] as num?)?.toInt() ?? 0,
      maxAssessmentsPerMonth:
          (json['maxAssessmentsPerMonth'] as num?)?.toInt() ?? 0,
      storageLimitBytes: (json['storageLimitBytes'] as num?)?.toInt() ?? 0,
      hasRazorpay: json['hasRazorpay'] as bool? ?? false,
      hasAutoRemind: json['hasAutoRemind'] as bool? ?? false,
      hasFeeReports: json['hasFeeReports'] as bool? ?? false,
      hasFeeLedger: json['hasFeeLedger'] as bool? ?? false,
      hasRoutePayouts: json['hasRoutePayouts'] as bool? ?? false,
      hasPushNotify: json['hasPushNotify'] as bool? ?? false,
      hasEmailNotify: json['hasEmailNotify'] as bool? ?? false,
      hasSmsNotify: json['hasSmsNotify'] as bool? ?? false,
      hasWhatsappNotify: json['hasWhatsappNotify'] as bool? ?? false,
      hasCustomLogo: json['hasCustomLogo'] as bool? ?? false,
      hasWhiteLabel: json['hasWhiteLabel'] as bool? ?? false,
      hasWebManagement: json['hasWebManagement'] as bool? ?? false,
    );
  }
}

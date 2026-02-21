import '../../../core/constants/api_constants.dart';
import '../../../core/services/cache_manager.dart';
import '../../../shared/services/api_client.dart';
import '../models/fee_model.dart';

class FeeService {
  final ApiClient _api = ApiClient.instance;
  final CacheManager _cache = CacheManager.instance;

  // ── Cache Helpers ────────────────────────────────────────────────

  /// Network-first with cache fallback. On success the response is cached;
  /// on network failure the stale cache (if any) is returned.
  Future<T> _cachedFetch<T>(
    String key,
    Future<dynamic> Function() fetcher,
    T Function(dynamic) parser, {
    Duration maxAge = const Duration(minutes: 30),
  }) async {
    try {
      final raw = await fetcher();
      await _cache.put(key, raw);
      return parser(raw);
    } catch (e) {
      final cached = await _cache.get(key, maxAge: maxAge);
      if (cached != null) {
        try {
          return parser(cached);
        } catch (_) {
          // Corrupted cache — rethrow original error.
        }
      }
      rethrow;
    }
  }

  /// Invalidate all fee cache keys for a coaching.
  Future<void> _invalidateCoaching(String coachingId) async {
    await _cache.invalidatePrefix('fee:$coachingId:');
  }

  // ── Fee Structures ───────────────────────────────────────────────

  Future<List<FeeStructureModel>> listStructures(String coachingId) async {
    return _cachedFetch(
      'fee:$coachingId:structures',
      () => _api.getAuthenticatedRaw(ApiConstants.feeStructures(coachingId)),
      (raw) => (raw as List<dynamic>)
          .map((e) => FeeStructureModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<FeeStructureModel?> getCurrentStructure(String coachingId) async {
    try {
      return await _cachedFetch(
        'fee:$coachingId:structure:current',
        () =>
            _api.getAuthenticated(ApiConstants.feeStructureCurrent(coachingId)),
        (raw) => FeeStructureModel.fromJson(raw as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getStructureReplacePreview(
    String coachingId,
  ) async {
    final data = await _api.getAuthenticated(
      ApiConstants.feeStructureReplacePreview(coachingId),
    );
    return data;
  }

  Future<FeeStructureModel> createStructure(
    String coachingId, {
    required String name,
    String? description,
    required double amount,
    String cycle = 'MONTHLY',
    double lateFinePerDay = 0,
    String? taxType,
    double? gstRate,
    String? sacCode,
    String? hsnCode,
    String? gstSupplyType,
    double? cessRate,
    List<Map<String, dynamic>>? lineItems,
    bool allowInstallments = false,
    int installmentCount = 0,
    List<Map<String, dynamic>>? installmentAmounts,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'amount': amount,
      'cycle': cycle,
      'lateFinePerDay': lateFinePerDay,
      'description': ?description,
      'taxType': ?taxType,
      'gstRate': ?gstRate,
      'sacCode': ?sacCode,
      'hsnCode': ?hsnCode,
      'gstSupplyType': ?gstSupplyType,
      'cessRate': ?cessRate,
      'lineItems': ?lineItems,
      'allowInstallments': allowInstallments,
      if (allowInstallments && installmentCount > 0)
        'installmentCount': installmentCount,
      if (allowInstallments && installmentAmounts != null)
        'installmentAmounts': installmentAmounts,
    };
    final data = await _api.postAuthenticated(
      ApiConstants.feeStructures(coachingId),
      body: body,
    );
    return FeeStructureModel.fromJson(data);
  }

  Future<FeeStructureModel> updateStructure(
    String coachingId,
    String structureId, {
    String? name,
    String? description,
    double? amount,
    String? cycle,
    double? lateFinePerDay,
    bool? isActive,
    String? taxType,
    double? gstRate,
    String? sacCode,
    String? hsnCode,
    String? gstSupplyType,
    double? cessRate,
    List<Map<String, dynamic>>? lineItems,
    bool? allowInstallments,
    int? installmentCount,
    List<Map<String, dynamic>>? installmentAmounts,
  }) async {
    final body = <String, dynamic>{
      'name': ?name,
      'description': ?description,
      'amount': ?amount,
      'cycle': ?cycle,
      'lateFinePerDay': ?lateFinePerDay,
      'isActive': ?isActive,
      'taxType': ?taxType,
      'gstRate': ?gstRate,
      'sacCode': ?sacCode,
      'hsnCode': ?hsnCode,
      'gstSupplyType': ?gstSupplyType,
      'cessRate': ?cessRate,
      'lineItems': ?lineItems,
      'allowInstallments': ?allowInstallments,
      'installmentCount': ?installmentCount,
      'installmentAmounts': ?installmentAmounts,
    };
    final data = await _api.patchAuthenticated(
      ApiConstants.feeStructureById(coachingId, structureId),
      body: body,
    );
    return FeeStructureModel.fromJson(data);
  }

  Future<void> deleteStructure(String coachingId, String structureId) async {
    await _api.deleteAuthenticated(
      ApiConstants.feeStructureById(coachingId, structureId),
    );
    await _invalidateCoaching(coachingId);
  }

  Future<Map<String, dynamic>> listAuditLog(
    String coachingId, {
    String? entityType,
    String? entityId,
    String? event,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int limit = 30,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'entityType': ?entityType,
      'entityId': ?entityId,
      'event': ?event,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    final uri = Uri.parse(
      ApiConstants.feeAuditLog(coachingId),
    ).replace(queryParameters: params);
    final data = await _api.getAuthenticated(uri.toString());
    return {
      'total': data['total'],
      'page': data['page'],
      'limit': data['limit'],
      'logs': (data['logs'] as List<dynamic>)
          .map((e) => FeeAuditLogModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    };
  }

  // ── Assignments ─────────────────────────────────────────────────

  Future<void> assignFee(
    String coachingId, {
    required String memberId,
    required String feeStructureId,
    double? customAmount,
    double? discountAmount,
    String? discountReason,
    String? scholarshipTag,
    double? scholarshipAmount,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final body = <String, dynamic>{
      'memberId': memberId,
      'feeStructureId': feeStructureId,
      'customAmount': ?customAmount,
      'discountAmount': ?discountAmount,
      'discountReason': ?discountReason,
      'scholarshipTag': ?scholarshipTag,
      'scholarshipAmount': ?scholarshipAmount,
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    };
    await _api.postAuthenticated(
      ApiConstants.assignFees(coachingId),
      body: body,
    );
    await _invalidateCoaching(coachingId);
  }

  Future<Map<String, dynamic>> toggleFeePause(
    String coachingId,
    String assignmentId, {
    required bool pause,
    String? note,
  }) async {
    final body = <String, dynamic>{'pause': pause, 'note': ?note};
    return _api.patchAuthenticated(
      ApiConstants.feeAssignmentPause(coachingId, assignmentId),
      body: body,
    );
  }

  Future<Map<String, dynamic>> getMemberFeeProfile(
    String coachingId,
    String memberId,
  ) async {
    final data = await _api.getAuthenticated(
      ApiConstants.feeMember(coachingId, memberId),
    );
    return data;
  }

  Future<Map<String, dynamic>> getAssignmentPreview(
    String coachingId,
    String memberId,
  ) async {
    final data = await _api.getAuthenticated(
      ApiConstants.feeAssignmentPreview(coachingId, memberId),
    );
    return data;
  }

  // ── Fee Records ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> listRecords(
    String coachingId, {
    String? memberId,
    String? status,
    String? search,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int limit = 30,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'memberId': ?memberId,
      'status': ?status,
      'search': ?search,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    final uri = Uri.parse(
      ApiConstants.feeRecords(coachingId),
    ).replace(queryParameters: params);
    final cacheKey = 'fee:$coachingId:records:${uri.query}';
    return _cachedFetch(cacheKey, () => _api.getAuthenticated(uri.toString()), (
      raw,
    ) {
      final map = raw as Map<String, dynamic>;
      return {
        'total': map['total'],
        'page': map['page'],
        'limit': map['limit'],
        'records': (map['records'] as List<dynamic>)
            .map((e) => FeeRecordModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      };
    });
  }

  /// Returns { record: FeeRecordModel, onlinePaymentEnabled: bool }
  Future<Map<String, dynamic>> getRecordWithMeta(
    String coachingId,
    String recordId,
  ) async {
    final json = await _api.getAuthenticated(
      ApiConstants.feeRecordById(coachingId, recordId),
    );
    return {
      'record': FeeRecordModel.fromJson(json),
      'onlinePaymentEnabled': json['onlinePaymentEnabled'] as bool? ?? false,
    };
  }

  Future<FeeRecordModel> getRecord(String coachingId, String recordId) async {
    return _cachedFetch(
      'fee:$coachingId:record:$recordId',
      () => _api.getAuthenticated(
        ApiConstants.feeRecordById(coachingId, recordId),
      ),
      (raw) => FeeRecordModel.fromJson(raw as Map<String, dynamic>),
    );
  }

  Future<FeeRecordModel> recordRefund(
    String coachingId,
    String recordId, {
    required double amount,
    String? reason,
    String? mode,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'reason': ?reason,
      'mode': ?mode,
    };
    final data = await _api.postAuthenticated(
      ApiConstants.feeRecordRefund(coachingId, recordId),
      body: body,
    );
    await _invalidateCoaching(coachingId);
    return FeeRecordModel.fromJson(data);
  }

  Future<FeeRecordModel> recordPayment(
    String coachingId,
    String recordId, {
    required double amount,
    required String mode,
    String? transactionRef,
    String? notes,
    DateTime? paidAt,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'mode': mode,
      'transactionRef': ?transactionRef,
      'notes': ?notes,
      if (paidAt != null) 'paidAt': paidAt.toIso8601String(),
    };
    final data = await _api.postAuthenticated(
      ApiConstants.feeRecordPay(coachingId, recordId),
      body: body,
    );
    await _invalidateCoaching(coachingId);
    return FeeRecordModel.fromJson(data);
  }

  Future<FeeRecordModel> waiveFee(
    String coachingId,
    String recordId, {
    String? notes,
  }) async {
    await _api.postAuthenticated(
      ApiConstants.feeRecordWaive(coachingId, recordId),
      body: {'notes': ?notes},
    );
    await _invalidateCoaching(coachingId);
    // Backend returns minimal updated record — re-fetch full record
    final data = await _api.getAuthenticated(
      ApiConstants.feeRecordById(coachingId, recordId),
    );
    return FeeRecordModel.fromJson(data);
  }

  Future<void> sendReminder(String coachingId, String recordId) async {
    await _api.postAuthenticated(
      ApiConstants.feeRecordRemind(coachingId, recordId),
      body: {},
    );
  }

  // ── Summary, Reports & My Fees ────────────────────────────────────

  Future<FeeSummaryModel> getSummary(
    String coachingId, {
    String? financialYear,
  }) async {
    final url = financialYear != null
        ? '${ApiConstants.feeSummary(coachingId)}?fy=$financialYear'
        : ApiConstants.feeSummary(coachingId);
    return _cachedFetch(
      'fee:$coachingId:summary:${financialYear ?? 'default'}',
      () => _api.getAuthenticated(url),
      (raw) => FeeSummaryModel.fromJson(raw as Map<String, dynamic>),
      maxAge: const Duration(minutes: 10),
    );
  }

  Future<List<FeeRecordModel>> getOverdueReport(String coachingId) async {
    final data = await _api.getAuthenticatedRaw(
      ApiConstants.feeOverdueReport(coachingId),
    );
    return (data as List<dynamic>)
        .map((e) => FeeRecordModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getStudentLedger(
    String coachingId,
    String memberId,
  ) async {
    return _cachedFetch(
      'fee:$coachingId:ledger:$memberId',
      () => _api.getAuthenticated(
        ApiConstants.feeMemberLedger(coachingId, memberId),
      ),
      (raw) => raw as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> bulkRemind(
    String coachingId, {
    String statusFilter = 'OVERDUE',
    List<String>? memberIds,
  }) async {
    final body = <String, dynamic>{
      'statusFilter': statusFilter,
      'memberIds': ?memberIds,
    };
    return _api.postAuthenticated(
      ApiConstants.feeBulkRemind(coachingId),
      body: body,
    );
  }

  // ── Calendar ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getFeeCalendarStats(
    String coachingId,
    DateTime from,
    DateTime to,
  ) async {
    final uri = Uri.parse(ApiConstants.feeCalendar(coachingId)).replace(
      queryParameters: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    );
    final data = await _api.getAuthenticatedRaw(uri.toString());
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getMyFees(String coachingId) async {
    return _cachedFetch(
      'fee:$coachingId:my',
      () => _api.getAuthenticated(ApiConstants.feesMy(coachingId)),
      (raw) {
        final data = raw as Map<String, dynamic>;
        return {
          'summary': data['summary'],
          'records': (data['records'] as List<dynamic>)
              .map((e) => FeeRecordModel.fromJson(e as Map<String, dynamic>))
              .toList(),
        };
      },
    );
  }
}

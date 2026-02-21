import '../../../core/constants/api_constants.dart';
import '../../../shared/services/api_client.dart';
import '../models/fee_model.dart';

class FeeService {
  final ApiClient _api = ApiClient.instance;

  // ── Fee Structures ───────────────────────────────────────────────

  Future<List<FeeStructureModel>> listStructures(String coachingId) async {
    final data = await _api.getAuthenticatedRaw(
      ApiConstants.feeStructures(coachingId),
    );
    return (data as List<dynamic>)
        .map((e) => FeeStructureModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FeeStructureModel?> getCurrentStructure(String coachingId) async {
    try {
      final data = await _api.getAuthenticated(
        ApiConstants.feeStructureCurrent(coachingId),
      );
      return FeeStructureModel.fromJson(data);
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
    final data = await _api.getAuthenticated(uri.toString());
    final map = data;
    return {
      'total': map['total'],
      'page': map['page'],
      'limit': map['limit'],
      'records': (map['records'] as List<dynamic>)
          .map((e) => FeeRecordModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    };
  }

  Future<FeeRecordModel> getRecord(String coachingId, String recordId) async {
    final data = await _api.getAuthenticated(
      ApiConstants.feeRecordById(coachingId, recordId),
    );
    return FeeRecordModel.fromJson(data);
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
    final data = await _api.getAuthenticated(url);
    return FeeSummaryModel.fromJson(data);
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
    return _api.getAuthenticated(
      ApiConstants.feeMemberLedger(coachingId, memberId),
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
    final data = await _api.getAuthenticated(ApiConstants.feesMy(coachingId));
    return {
      'summary': data['summary'],
      'records': (data['records'] as List<dynamic>)
          .map((e) => FeeRecordModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    };
  }
}

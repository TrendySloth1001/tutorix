import '../../../core/constants/api_constants.dart';
import '../../../core/services/cache_manager.dart';
import '../../../shared/services/api_client.dart';
import '../models/batch_model.dart';
import '../models/batch_member_model.dart';
import '../models/batch_note_model.dart';
import '../models/batch_notice_model.dart';

class BatchService {
  final ApiClient _api = ApiClient.instance;
  final CacheManager _cache = CacheManager.instance;

  // ── File Upload ───────────────────────────────────────────────────

  /// Upload a single note file, returns the URL and metadata.
  Future<Map<String, dynamic>> uploadNoteFile(String filePath) async {
    return await _api.uploadFile(
      ApiConstants.uploadNote,
      fieldName: 'file',
      filePath: filePath,
    );
  }

  /// Upload multiple note files in one request.
  /// Returns { files: [...], totalSize: int }.
  Future<Map<String, dynamic>> uploadNoteFiles(List<String> filePaths) async {
    return await _api.uploadFiles(
      ApiConstants.uploadNotes,
      fieldName: 'files',
      filePaths: filePaths,
    );
  }

  /// GET /coaching/:coachingId/batches/storage
  Future<Map<String, dynamic>> getStorageUsage(String coachingId) async {
    return await _api.getAuthenticated(ApiConstants.batchStorage(coachingId));
  }

  // ── CRUD ──────────────────────────────────────────────────────────

  /// POST /coaching/:coachingId/batches
  Future<BatchModel> createBatch(
    String coachingId, {
    required String name,
    String? subject,
    String? description,
    String? startTime,
    String? endTime,
    List<String>? days,
    int? maxStudents,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (subject != null) body['subject'] = subject;
    if (description != null) body['description'] = description;
    if (startTime != null) body['startTime'] = startTime;
    if (endTime != null) body['endTime'] = endTime;
    if (days != null) body['days'] = days;
    if (maxStudents != null) body['maxStudents'] = maxStudents;

    final data = await _api.postAuthenticated(
      ApiConstants.batches(coachingId),
      body: body,
    );
    await _cache.invalidatePrefix('batch:$coachingId');
    return BatchModel.fromJson(data['batch'] as Map<String, dynamic>);
  }

  /// GET /coaching/:coachingId/batches
  /// Stream: emits cached list first, then fresh from network.
  Stream<List<BatchModel>> watchBatches(String coachingId, {String? status}) {
    final key = 'batch:$coachingId:list${status != null ? ':$status' : ''}';
    return _cache.swr<List<BatchModel>>(
      key,
      () async {
        var url = ApiConstants.batches(coachingId);
        if (status != null) url += '?status=$status';
        return await _api.getAuthenticated(url);
      },
      (raw) {
        final list = (raw['batches'] as List<dynamic>?) ?? [];
        return list
            .map(
              (e) => BatchModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      },
    );
  }

  Future<List<BatchModel>> listBatches(String coachingId, {String? status}) =>
      watchBatches(coachingId, status: status).last;

  /// GET /coaching/:coachingId/batches/my
  Stream<List<BatchModel>> watchMyBatches(String coachingId) {
    final key = 'batch:$coachingId:my';
    return _cache.swr<List<BatchModel>>(
      key,
      () => _api.getAuthenticated(ApiConstants.myBatches(coachingId)),
      (raw) {
        final list = (raw['batches'] as List<dynamic>?) ?? [];
        return list
            .map(
              (e) => BatchModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      },
    );
  }

  Future<List<BatchModel>> getMyBatches(String coachingId) =>
      watchMyBatches(coachingId).last;

  /// GET /coaching/:coachingId/batches/:batchId
  Stream<BatchModel> watchBatchById(String coachingId, String batchId) {
    final key = 'batch:$coachingId:$batchId';
    return _cache.swr<BatchModel>(
      key,
      () => _api.getAuthenticated(ApiConstants.batchById(coachingId, batchId)),
      (raw) =>
          BatchModel.fromJson(Map<String, dynamic>.from(raw['batch'] as Map)),
    );
  }

  Future<BatchModel> getBatchById(String coachingId, String batchId) =>
      watchBatchById(coachingId, batchId).last;

  /// PATCH /coaching/:coachingId/batches/:batchId
  Future<BatchModel> updateBatch(
    String coachingId,
    String batchId, {
    String? name,
    String? subject,
    String? description,
    String? startTime,
    String? endTime,
    List<String>? days,
    int? maxStudents,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (subject != null) body['subject'] = subject;
    if (description != null) body['description'] = description;
    if (startTime != null) body['startTime'] = startTime;
    if (endTime != null) body['endTime'] = endTime;
    if (days != null) body['days'] = days;
    if (maxStudents != null) body['maxStudents'] = maxStudents;
    if (status != null) body['status'] = status;

    final data = await _api.patchAuthenticated(
      ApiConstants.batchById(coachingId, batchId),
      body: body,
    );
    await _cache.invalidatePrefix('batch:$coachingId');
    return BatchModel.fromJson(data['batch'] as Map<String, dynamic>);
  }

  /// DELETE /coaching/:coachingId/batches/:batchId
  Future<bool> deleteBatch(String coachingId, String batchId) async {
    final ok = await _api.deleteAuthenticated(
      ApiConstants.batchById(coachingId, batchId),
    );
    if (ok) await _cache.invalidatePrefix('batch:$coachingId');
    return ok;
  }

  // ── Members ───────────────────────────────────────────────────────

  /// POST /coaching/:coachingId/batches/:batchId/members
  Future<List<BatchMemberModel>> addMembers(
    String coachingId,
    String batchId, {
    required List<String> memberIds,
    String role = 'STUDENT',
  }) async {
    final data = await _api.postAuthenticated(
      ApiConstants.batchMembers(coachingId, batchId),
      body: {'memberIds': memberIds, 'role': role},
    );
    await _cache.invalidate('batch:$coachingId:$batchId:members');
    final list = data['members'] as List<dynamic>;
    return list
        .map((e) => BatchMemberModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /coaching/:coachingId/batches/:batchId/members
  Stream<List<BatchMemberModel>> watchMembers(
    String coachingId,
    String batchId,
  ) {
    final key = 'batch:$coachingId:$batchId:members';
    return _cache.swr<List<BatchMemberModel>>(
      key,
      () =>
          _api.getAuthenticated(ApiConstants.batchMembers(coachingId, batchId)),
      (raw) {
        final list = (raw['members'] as List<dynamic>?) ?? [];
        return list
            .map(
              (e) => BatchMemberModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      },
    );
  }

  Future<List<BatchMemberModel>> getMembers(
    String coachingId,
    String batchId,
  ) => watchMembers(coachingId, batchId).last;

  /// GET /coaching/:coachingId/batches/:batchId/members/available?role=...
  Future<List<dynamic>> getAvailableMembers(
    String coachingId,
    String batchId, {
    String? role,
  }) async {
    var url = ApiConstants.batchAvailableMembers(coachingId, batchId);
    if (role != null) url += '?role=$role';
    final data = await _api.getAuthenticated(url);
    return data['members'] as List<dynamic>;
  }

  /// DELETE /coaching/:coachingId/batches/:batchId/members/:batchMemberId
  Future<bool> removeMember(
    String coachingId,
    String batchId,
    String batchMemberId,
  ) async {
    final ok = await _api.deleteAuthenticated(
      ApiConstants.removeBatchMember(coachingId, batchId, batchMemberId),
    );
    if (ok) await _cache.invalidate('batch:$coachingId:$batchId:members');
    return ok;
  }

  // ── Notes ─────────────────────────────────────────────────────────

  /// POST /coaching/:coachingId/batches/:batchId/notes
  Future<BatchNoteModel> createNote(
    String coachingId,
    String batchId, {
    required String title,
    String? description,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final body = <String, dynamic>{'title': title};
    if (description != null) body['description'] = description;
    if (attachments != null && attachments.isNotEmpty) {
      body['attachments'] = attachments;
    }

    final data = await _api.postAuthenticated(
      ApiConstants.batchNotes(coachingId, batchId),
      body: body,
    );
    await Future.wait([
      _cache.invalidate('batch:$coachingId:$batchId:notes'),
      _cache.invalidate('batch:$coachingId:recent-notes'),
    ]);
    return BatchNoteModel.fromJson(data['note'] as Map<String, dynamic>);
  }

  /// GET /coaching/:coachingId/batches/:batchId/notes
  Stream<List<BatchNoteModel>> watchNotes(String coachingId, String batchId) {
    final key = 'batch:$coachingId:$batchId:notes';
    return _cache.swr<List<BatchNoteModel>>(
      key,
      () => _api.getAuthenticated(ApiConstants.batchNotes(coachingId, batchId)),
      (raw) {
        final list = (raw['notes'] as List<dynamic>?) ?? [];
        return list
            .map(
              (e) =>
                  BatchNoteModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      },
    );
  }

  Future<List<BatchNoteModel>> listNotes(String coachingId, String batchId) =>
      watchNotes(coachingId, batchId).last;

  /// GET /coaching/:coachingId/batches/recent-notes
  Stream<List<BatchNoteModel>> watchRecentNotes(String coachingId) {
    final key = 'batch:$coachingId:recent-notes';
    return _cache.swr<List<BatchNoteModel>>(
      key,
      () => _api.getAuthenticated(ApiConstants.recentNotes(coachingId)),
      (raw) {
        final list = (raw['notes'] as List<dynamic>?) ?? [];
        return list
            .map(
              (e) =>
                  BatchNoteModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      },
    );
  }

  Future<List<BatchNoteModel>> getRecentNotes(String coachingId) =>
      watchRecentNotes(coachingId).last;

  /// GET /coaching/:coachingId/batches/dashboard-feed
  /// Returns { assessments, assignments, notices } from last 7 days.
  Stream<Map<String, dynamic>> watchDashboardFeed(String coachingId) {
    final key = 'batch:$coachingId:dashboard-feed';
    return _cache.swr<Map<String, dynamic>>(
      key,
      () => _api.getAuthenticated(ApiConstants.dashboardFeed(coachingId)),
      (raw) => raw,
    );
  }

  Future<Map<String, dynamic>> getDashboardFeed(String coachingId) =>
      watchDashboardFeed(coachingId).last;

  /// DELETE /coaching/:coachingId/batches/:batchId/notes/:noteId
  Future<bool> deleteNote(
    String coachingId,
    String batchId,
    String noteId,
  ) async {
    final ok = await _api.deleteAuthenticated(
      ApiConstants.deleteBatchNote(coachingId, batchId, noteId),
    );
    if (ok) {
      await Future.wait([
        _cache.invalidate('batch:$coachingId:$batchId:notes'),
        _cache.invalidate('batch:$coachingId:recent-notes'),
      ]);
    }
    return ok;
  }

  // ── Notices ───────────────────────────────────────────────────────

  /// POST /coaching/:coachingId/batches/:batchId/notices
  Future<BatchNoticeModel> createNotice(
    String coachingId,
    String batchId, {
    required String title,
    required String message,
    String priority = 'normal',
    String type = 'general',
    String? date,
    String? startTime,
    String? endTime,
    String? day,
    String? location,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'message': message,
      'priority': priority,
      'type': type,
    };
    if (date != null) body['date'] = date;
    if (startTime != null) body['startTime'] = startTime;
    if (endTime != null) body['endTime'] = endTime;
    if (day != null) body['day'] = day;
    if (location != null) body['location'] = location;

    final data = await _api.postAuthenticated(
      ApiConstants.batchNotices(coachingId, batchId),
      body: body,
    );
    await _cache.invalidate('batch:$coachingId:$batchId:notices');
    return BatchNoticeModel.fromJson(data['notice'] as Map<String, dynamic>);
  }

  /// GET /coaching/:coachingId/batches/:batchId/notices
  Stream<List<BatchNoticeModel>> watchNotices(
    String coachingId,
    String batchId,
  ) {
    final key = 'batch:$coachingId:$batchId:notices';
    return _cache.swr<List<BatchNoticeModel>>(
      key,
      () =>
          _api.getAuthenticated(ApiConstants.batchNotices(coachingId, batchId)),
      (raw) {
        final list = (raw['notices'] as List<dynamic>?) ?? [];
        return list
            .map(
              (e) => BatchNoticeModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      },
    );
  }

  Future<List<BatchNoticeModel>> listNotices(
    String coachingId,
    String batchId,
  ) => watchNotices(coachingId, batchId).last;

  /// DELETE /coaching/:coachingId/batches/:batchId/notices/:noticeId
  Future<bool> deleteNotice(
    String coachingId,
    String batchId,
    String noticeId,
  ) async {
    final ok = await _api.deleteAuthenticated(
      ApiConstants.deleteBatchNotice(coachingId, batchId, noticeId),
    );
    if (ok) await _cache.invalidate('batch:$coachingId:$batchId:notices');
    return ok;
  }
}

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
  Future<List<BatchModel>> listBatches(
    String coachingId, {
    String? status,
  }) async {
    final key = 'batch:$coachingId:list${status != null ? ':$status' : ''}';
    try {
      var url = ApiConstants.batches(coachingId);
      if (status != null) url += '?status=$status';
      final data = await _api.getAuthenticated(url);
      await _cache.put(key, data);
      final list = data['batches'] as List<dynamic>;
      return list
          .map((e) => BatchModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) {
        final list = (cached['batches'] as List<dynamic>);
        return list
            .map((e) =>
                BatchModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      rethrow;
    }
  }

  /// GET /coaching/:coachingId/batches/my
  Future<List<BatchModel>> getMyBatches(String coachingId) async {
    final key = 'batch:$coachingId:my';
    try {
      final data = await _api.getAuthenticated(
        ApiConstants.myBatches(coachingId),
      );
      await _cache.put(key, data);
      final list = data['batches'] as List<dynamic>;
      return list
          .map((e) => BatchModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) {
        final list = (cached['batches'] as List<dynamic>);
        return list
            .map((e) =>
                BatchModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      rethrow;
    }
  }

  /// GET /coaching/:coachingId/batches/:batchId
  Future<BatchModel> getBatchById(String coachingId, String batchId) async {
    final key = 'batch:$coachingId:$batchId';
    try {
      final data = await _api.getAuthenticated(
        ApiConstants.batchById(coachingId, batchId),
      );
      await _cache.put(key, data);
      return BatchModel.fromJson(data['batch'] as Map<String, dynamic>);
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) {
        return BatchModel.fromJson(
            Map<String, dynamic>.from(cached['batch'] as Map));
      }
      rethrow;
    }
  }

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
    final ok =
        await _api.deleteAuthenticated(ApiConstants.batchById(coachingId, batchId));
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
  Future<List<BatchMemberModel>> getMembers(
    String coachingId,
    String batchId,
  ) async {
    final key = 'batch:$coachingId:$batchId:members';
    try {
      final data = await _api.getAuthenticated(
        ApiConstants.batchMembers(coachingId, batchId),
      );
      await _cache.put(key, data);
      final list = data['members'] as List<dynamic>;
      return list
          .map((e) => BatchMemberModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) {
        final list = (cached['members'] as List<dynamic>);
        return list
            .map((e) => BatchMemberModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      rethrow;
    }
  }

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
  Future<List<BatchNoteModel>> listNotes(
    String coachingId,
    String batchId,
  ) async {
    final key = 'batch:$coachingId:$batchId:notes';
    try {
      final data = await _api.getAuthenticated(
        ApiConstants.batchNotes(coachingId, batchId),
      );
      await _cache.put(key, data);
      final list = data['notes'] as List<dynamic>;
      return list
          .map((e) => BatchNoteModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) {
        final list = (cached['notes'] as List<dynamic>);
        return list
            .map((e) => BatchNoteModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      rethrow;
    }
  }

  /// GET /coaching/:coachingId/batches/recent-notes
  Future<List<BatchNoteModel>> getRecentNotes(String coachingId) async {
    final key = 'batch:$coachingId:recent-notes';
    try {
      final data = await _api.getAuthenticated(
        ApiConstants.recentNotes(coachingId),
      );
      await _cache.put(key, data);
      final list = data['notes'] as List<dynamic>;
      return list
          .map((e) => BatchNoteModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) {
        final list = (cached['notes'] as List<dynamic>);
        return list
            .map((e) => BatchNoteModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    }
  }

  /// DELETE /coaching/:coachingId/batches/:batchId/notes/:noteId
  Future<bool> deleteNote(String coachingId, String batchId, String noteId) async {
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
  Future<List<BatchNoticeModel>> listNotices(
    String coachingId,
    String batchId,
  ) async {
    final key = 'batch:$coachingId:$batchId:notices';
    try {
      final data = await _api.getAuthenticated(
        ApiConstants.batchNotices(coachingId, batchId),
      );
      await _cache.put(key, data);
      final list = data['notices'] as List<dynamic>;
      return list
          .map((e) => BatchNoticeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) {
        final list = (cached['notices'] as List<dynamic>);
        return list
            .map((e) => BatchNoticeModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      rethrow;
    }
  }

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

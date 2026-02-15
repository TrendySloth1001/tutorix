/// A note uploaded by a teacher inside a batch.
class BatchNoteModel {
  final String id;
  final String batchId;
  final String title;
  final String? description;
  final List<NoteAttachment> attachments;
  final String uploadedById;
  final NoteUploader? uploadedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BatchNoteModel({
    required this.id,
    required this.batchId,
    required this.title,
    this.description,
    this.attachments = const [],
    required this.uploadedById,
    this.uploadedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory BatchNoteModel.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'] as List<dynamic>?;
    return BatchNoteModel(
      id: json['id'] as String,
      batchId: json['batchId'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String?,
      attachments:
          rawAttachments
              ?.map((e) => NoteAttachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      uploadedById: json['uploadedById'] as String? ?? '',
      uploadedBy: json['uploadedBy'] != null
          ? NoteUploader.fromJson(json['uploadedBy'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Total size of all attachments in bytes.
  int get totalSize => attachments.fold(0, (s, a) => s + a.fileSize);

  String get displayName => title;
}

/// A single file/link attached to a note.
class NoteAttachment {
  final String id;
  final String url;
  final String? fileName;
  final String fileType;
  final int fileSize;
  final String? mimeType;

  const NoteAttachment({
    required this.id,
    required this.url,
    this.fileName,
    this.fileType = 'pdf',
    this.fileSize = 0,
    this.mimeType,
  });

  factory NoteAttachment.fromJson(Map<String, dynamic> json) {
    return NoteAttachment(
      id: json['id'] as String,
      url: json['url'] as String,
      fileName: json['fileName'] as String?,
      fileType: json['fileType'] as String? ?? 'pdf',
      fileSize: json['fileSize'] as int? ?? 0,
      mimeType: json['mimeType'] as String?,
    );
  }

  /// Human-readable file size.
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Icon data based on file type.
  static const typeConfig = {
    'pdf': 'PDF',
    'image': 'Image',
    'doc': 'Document',
    'link': 'Link',
  };
}

class NoteUploader {
  final String id;
  final String? name;
  final String? picture;

  const NoteUploader({required this.id, this.name, this.picture});

  factory NoteUploader.fromJson(Map<String, dynamic> json) {
    return NoteUploader(
      id: json['id'] as String,
      name: json['name'] as String?,
      picture: json['picture'] as String?,
    );
  }
}

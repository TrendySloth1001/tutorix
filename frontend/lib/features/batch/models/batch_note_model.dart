/// A note uploaded by a teacher inside a batch.
class BatchNoteModel {
  final String id;
  final String batchId;
  final String title;
  final String? description;
  final String fileUrl;
  final String fileType; // pdf, image, doc, video, link
  final String? fileName;
  final String uploadedById;
  final NoteUploader? uploadedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BatchNoteModel({
    required this.id,
    required this.batchId,
    required this.title,
    this.description,
    required this.fileUrl,
    this.fileType = 'pdf',
    this.fileName,
    required this.uploadedById,
    this.uploadedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory BatchNoteModel.fromJson(Map<String, dynamic> json) {
    return BatchNoteModel(
      id: json['id'] as String,
      batchId: json['batchId'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String?,
      fileUrl: json['fileUrl'] as String,
      fileType: json['fileType'] as String? ?? 'pdf',
      fileName: json['fileName'] as String?,
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

  /// Icon for the file type.
  String get fileTypeIcon {
    switch (fileType) {
      case 'pdf':
        return '📄';
      case 'image':
        return '🖼️';
      case 'doc':
        return '📝';
      case 'video':
        return '🎥';
      case 'link':
        return '🔗';
      default:
        return '📎';
    }
  }

  String get displayName => fileName ?? title;
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

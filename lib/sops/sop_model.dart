// sop_model.dart - FacilitySop model: title, document type, status, version,
// file path, upload date, author, tags; fromMap serialisation.

import '/core/sop_db_schema.dart';

class FacilitySop {
  final int? id;
  final String? code;
  final String name;
  final String? version;
  final String? type;
  final String? category;
  final String? status;
  final String? description;
  final String? tags;
  // PDF slot
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final String? fileMime;
  // TXT slot
  final String? txtFilePath;
  final String? txtFileName;
  final int? txtFileSize;
  // DOC/DOCX slot
  final String? docFilePath;
  final String? docFileName;
  final int? docFileSize;
  final DateTime? effectiveDate;
  final DateTime? reviewDate;
  final DateTime? lastReviewed;
  final String? responsible;
  final int? responsibleId;
  final String? author;
  final String? lastUpdatedBy;
  final String? revisionNotes;
  final String? sopContext;      // 'fish_facility' | 'culture_collection'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FacilitySop({
    this.id,
    this.code,
    required this.name,
    this.version,
    this.type,
    this.category,
    this.status,
    this.description,
    this.tags,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.fileMime,
    this.txtFilePath,
    this.txtFileName,
    this.txtFileSize,
    this.docFilePath,
    this.docFileName,
    this.docFileSize,
    this.effectiveDate,
    this.reviewDate,
    this.lastReviewed,
    this.responsible,
    this.responsibleId,
    this.author,
    this.lastUpdatedBy,
    this.revisionNotes,
    this.sopContext,
    this.createdAt,
    this.updatedAt,
  });

  factory FacilitySop.fromMap(Map<String, dynamic> m) => FacilitySop(
    id:            m[SopSch.id]            as int?,
    code:          m[SopSch.code]          as String?,
    name:          (m[SopSch.name]         as String?) ?? '',
    version:       m[SopSch.version]       as String?,
    type:          m[SopSch.type]          as String?,
    category:      m[SopSch.category]      as String?,
    status:        m[SopSch.status]        as String?,
    description:   m[SopSch.description]   as String?,
    tags:          m[SopSch.tags]          as String?,
    filePath:      m[SopSch.filePath]      as String?,
    fileName:      m[SopSch.fileName]      as String?,
    fileSize:      m[SopSch.fileSize]      as int?,
    fileMime:      m[SopSch.fileMime]      as String?,
    txtFilePath:   m[SopSch.txtFilePath]   as String?,
    txtFileName:   m[SopSch.txtFileName]   as String?,
    txtFileSize:   m[SopSch.txtFileSize]   as int?,
    docFilePath:   m[SopSch.docFilePath]   as String?,
    docFileName:   m[SopSch.docFileName]   as String?,
    docFileSize:   m[SopSch.docFileSize]   as int?,
    effectiveDate: _parseDate(m[SopSch.effectiveDate]),
    reviewDate:    _parseDate(m[SopSch.reviewDate]),
    lastReviewed:  _parseDate(m[SopSch.lastReviewed]),
    responsible:   m[SopSch.responsible]   as String?,
    responsibleId: m[SopSch.responsibleId] as int?,
    author:        m[SopSch.author]        as String?,
    lastUpdatedBy: m[SopSch.lastUpdatedBy] as String?,
    revisionNotes: m[SopSch.revisionNotes] as String?,
    sopContext:    m[SopSch.context]       as String?,
    createdAt:     _parseDate(m[SopSch.createdAt]),
    updatedAt:     _parseDate(m[SopSch.updatedAt]),
  );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  bool get hasPdfFile => filePath    != null && filePath!.isNotEmpty;
  bool get hasTxtFile => txtFilePath != null && txtFilePath!.isNotEmpty;
  bool get hasDocFile => docFilePath != null && docFilePath!.isNotEmpty;
  bool get hasAnyFile => hasPdfFile || hasTxtFile || hasDocFile;

  // kept for backward compat
  bool get hasFile => hasPdfFile;

  bool get isPdf    => fileMime == 'application/pdf' ||
                       (fileName?.toLowerCase().endsWith('.pdf') ?? false);

  String get pdfFileSizeLabel => _sizeLabel(fileSize);
  String get txtFileSizeLabel => _sizeLabel(txtFileSize);
  String get docFileSizeLabel => _sizeLabel(docFileSize);

  static String _sizeLabel(int? size) {
    if (size == null) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // kept for card display
  String get fileSizeLabel => pdfFileSizeLabel;

  bool get isReviewOverdue {
    if (reviewDate == null) return false;
    return reviewDate!.isBefore(DateTime.now());
  }

  bool get isReviewSoon {
    if (reviewDate == null || isReviewOverdue) return false;
    return reviewDate!.isBefore(DateTime.now().add(const Duration(days: 30)));
  }


  static const List<String> types = [
    'sop', 'protocol', 'guideline', 'checklist', 'form', 'training',
  ];

  static const List<String> statuses = [
    'draft', 'active', 'under_review', 'archived', 'superseded',
  ];

  static String typeLabel(String? t) {
    switch (t) {
      case 'sop':        return 'SOP';
      case 'protocol':   return 'Protocol';
      case 'guideline':  return 'Guideline';
      case 'checklist':  return 'Checklist';
      case 'form':       return 'Form';
      case 'training':   return 'Training';
      default:           return t ?? 'SOP';
    }
  }

  static String statusLabel(String? s) {
    switch (s) {
      case 'draft':        return 'Draft';
      case 'active':       return 'Active';
      case 'under_review': return 'Under Review';
      case 'archived':     return 'Archived';
      case 'superseded':   return 'Superseded';
      default:             return s ?? 'Draft';
    }
  }
}

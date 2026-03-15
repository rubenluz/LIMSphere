// Schema constants for the facility_sops table and its Supabase Storage bucket.
class SopSch {
  // Table name
  static const table    = 'facility_sops';

  // Storage bucket
  static const bucket   = 'facility-sops';

  // Columns
  static const id            = 'sop_id';
  static const code          = 'sop_code';
  static const name          = 'sop_name';
  static const version       = 'sop_version';
  static const type          = 'sop_type';
  static const category      = 'sop_category';
  static const status        = 'sop_status';
  static const description   = 'sop_description';
  static const tags          = 'sop_tags';
  // PDF file slot (primary — viewable in-app)
  static const filePath      = 'sop_file_path';
  static const fileName      = 'sop_file_name';
  static const fileSize      = 'sop_file_size';
  static const fileMime      = 'sop_file_mime';

  // TXT file slot
  static const txtFilePath   = 'sop_txt_file_path';
  static const txtFileName   = 'sop_txt_file_name';
  static const txtFileSize   = 'sop_txt_file_size';

  // DOC/DOCX file slot
  static const docFilePath   = 'sop_doc_file_path';
  static const docFileName   = 'sop_doc_file_name';
  static const docFileSize   = 'sop_doc_file_size';
  static const effectiveDate = 'sop_effective_date';
  static const reviewDate    = 'sop_review_date';
  static const lastReviewed  = 'sop_last_reviewed';
  static const responsible   = 'sop_responsible';
  static const responsibleId = 'sop_responsible_id';
  static const author        = 'sop_author';
  static const lastUpdatedBy = 'sop_last_updated_by';
  static const revisionNotes = 'sop_revision_notes';
  static const context       = 'sop_context';    // 'fish_facility' | 'culture_collection'
  static const createdAt     = 'sop_created_at';
  static const updatedAt     = 'sop_updated_at';
}

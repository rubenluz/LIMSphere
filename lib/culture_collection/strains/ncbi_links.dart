const ncbiGenBankFieldPrefix = 'strain_genbank_';

bool isGenBankAccessionField(String key) =>
    key.startsWith(ncbiGenBankFieldPrefix);

Uri buildNcbiBlastSearchUri(String accession) => Uri.https(
  'blast.ncbi.nlm.nih.gov',
  '/Blast.cgi',
  {'PROGRAM': 'blastn', 'PAGE_TYPE': 'BlastSearch', 'QUERY': accession.trim()},
);

Uri? buildNcbiReferenceUri(String key, String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;

  final parsed = Uri.tryParse(normalized);
  if (parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https')) {
    return parsed;
  }

  if (key == 'strain_gca_accession') {
    return Uri.https(
      'www.ncbi.nlm.nih.gov',
      '/datasets/genome/${Uri.encodeComponent(normalized)}/',
    );
  }
  if (isGenBankAccessionField(key)) {
    return buildNcbiBlastSearchUri(normalized);
  }
  if (key == 'strain_sequence_literature_ids') {
    return Uri.https('pubmed.ncbi.nlm.nih.gov', '/', {'term': normalized});
  }
  return null;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/culture_collection/strains/ncbi_links.dart';

void main() {
  group('NCBI accession links', () {
    test(
      'GenBank fields open nucleotide BLAST with the accession prefilled',
      () {
        final uri = buildNcbiReferenceUri(
          'strain_genbank_18s',
          '  PP897820.1  ',
        );

        expect(uri?.host, 'blast.ncbi.nlm.nih.gov');
        expect(uri?.path, '/Blast.cgi');
        expect(uri?.queryParameters['PROGRAM'], 'blastn');
        expect(uri?.queryParameters['PAGE_TYPE'], 'BlastSearch');
        expect(uri?.queryParameters['QUERY'], 'PP897820.1');
      },
    );

    test('GCA fields continue to open the NCBI genome record', () {
      final uri = buildNcbiReferenceUri(
        'strain_gca_accession',
        'GCA_003774525.2',
      );

      expect(uri?.host, 'www.ncbi.nlm.nih.gov');
      expect(uri?.path, '/datasets/genome/GCA_003774525.2/');
    });

    test('explicit web links are preserved', () {
      final uri = buildNcbiReferenceUri(
        'strain_genbank_rbcl',
        'https://example.org/record',
      );

      expect(uri, Uri.parse('https://example.org/record'));
    });
  });
}

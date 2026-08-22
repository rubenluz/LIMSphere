import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/sops/sop_model.dart';

void main() {
  test('SOP contexts have user-facing subcategory labels', () {
    expect(
      FacilitySop.contextLabel('culture_collection'),
      'Culture Collection',
    );
    expect(FacilitySop.contextLabel('fish_facility'), 'Fish Facility');
    expect(FacilitySop.contextLabel('hplc'), 'HPLC');
    expect(FacilitySop.contextLabel('assays'), 'Assays');
    expect(
      FacilitySop.contextLabel('reagent_preparation'),
      'Reagent Preparation',
    );
    expect(FacilitySop.contextLabel('sampling'), 'Sampling');
    expect(
      FacilitySop.contextLabel('cleaning_maintenance'),
      'Cleaning & Maintenance',
    );
    expect(FacilitySop.contextLabel('molecular_biology'), 'Molecular Biology');
  });
}

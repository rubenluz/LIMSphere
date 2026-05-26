const fishFoodOtherOption = 'Other';

const fishFoodTypeBaseOptions = [
  'GEMMA 75',
  'GEMMA 150',
  'GEMMA 300',
  'SPAROS 400-600',
];

const fishFoodTypeOptions = [...fishFoodTypeBaseOptions, fishFoodOtherOption];

bool isKnownFishFoodType(String? value) =>
    value != null && fishFoodTypeBaseOptions.contains(value);

bool isFishFoodMixture(String? value) =>
    value != null && value.trim().contains('/');

String? fishFoodTypeSelection(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return isKnownFishFoodType(value) ? value : fishFoodOtherOption;
}

String fishFoodCustomText(String? value) {
  if (value == null || value.trim().isEmpty || isKnownFishFoodType(value)) {
    return '';
  }
  final trimmed = value.trim();
  return trimmed == fishFoodOtherOption ? '' : trimmed;
}

List<String?> fishFoodMixtureParts(String? value) {
  if (!isFishFoodMixture(value)) return [null, null];
  final parts = value!.split('/').map((s) => s.trim()).toList();
  final first = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : null;
  final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  return [first, second];
}

String? resolveFishFoodSelection(String? selected, String customText) {
  if (selected == fishFoodOtherOption) {
    final custom = customText.trim();
    return custom.isEmpty ? null : custom;
  }
  return selected;
}

String? normalizedFishFoodType({
  required bool isMixture,
  required String? selected,
  required String selectedCustom,
  required String? mixtureFirst,
  required String mixtureFirstCustom,
  required String? mixtureSecond,
  required String mixtureSecondCustom,
}) {
  if (isMixture) {
    final first = resolveFishFoodSelection(mixtureFirst, mixtureFirstCustom);
    final second = resolveFishFoodSelection(mixtureSecond, mixtureSecondCustom);
    if (first == null || second == null) return null;
    return '$first / $second';
  }
  return resolveFishFoodSelection(selected, selectedCustom);
}

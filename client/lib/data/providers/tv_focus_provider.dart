import 'package:flutter_riverpod/flutter_riverpod.dart';

/// يحفظ ID العنصر الذي تم التركيز عليه آخر مرة
/// يبقى محفوظاً حتى يتم اختيار عنصر آخر
final selectedItemProvider = StateProvider<String?>((ref) => null);

/// دوال مساعدة
void setSelectedItem(WidgetRef ref, String? id) {
  final current = ref.read(selectedItemProvider);
  if (current != id) {
    ref.read(selectedItemProvider.notifier).state = id;
  }
}

bool isItemSelected(WidgetRef ref, String id) {
  return ref.watch(selectedItemProvider) == id;
}

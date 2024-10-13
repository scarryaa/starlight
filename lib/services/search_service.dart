import 'package:flutter/foundation.dart';

class SearchService {
  final ValueNotifier<bool> isSearchVisibleNotifier = ValueNotifier<bool>(false);

  void toggleSearch() {
    isSearchVisibleNotifier.value = !isSearchVisibleNotifier.value;
  }

  void closeSearch() {
    isSearchVisibleNotifier.value = false;
  }

  void requestSearchFocus() {
    if (!isSearchVisibleNotifier.value) {
      isSearchVisibleNotifier.value = true;
    }
  }
}

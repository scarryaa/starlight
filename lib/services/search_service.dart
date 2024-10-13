import 'package:flutter/foundation.dart';

class SearchService {
  final ValueNotifier<bool> isSearchVisibleNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> isReplaceVisibleNotifier =
      ValueNotifier<bool>(false);

  void toggleSearch() {
    isSearchVisibleNotifier.value = !isSearchVisibleNotifier.value;
    if (!isSearchVisibleNotifier.value) {
      isReplaceVisibleNotifier.value = false;
    }
  }

  void closeSearch() {
    isSearchVisibleNotifier.value = false;
    isReplaceVisibleNotifier.value = false;
  }

  void toggleReplace() {
    if (!isSearchVisibleNotifier.value) {
      isSearchVisibleNotifier.value = true;
    }
    isReplaceVisibleNotifier.value = !isReplaceVisibleNotifier.value;
  }

  void toggleReplaceAndOpenSearch() {
    if (!isSearchVisibleNotifier.value) {
      isSearchVisibleNotifier.value = true;
    }
    isReplaceVisibleNotifier.value = true;
  }
}


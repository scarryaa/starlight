import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class HotkeyService {
  final Map<ShortcutActivator, VoidCallback> _hotkeys = {};

  void registerHotkey(ShortcutActivator activator, VoidCallback callback) {
    _hotkeys[activator] = callback;
  }

  void unregisterHotkey(ShortcutActivator activator) {
    _hotkeys.remove(activator);
  }

  KeyEventResult handleKeyEvent(KeyEvent event) {
    for (final entry in _hotkeys.entries) {
      if (entry.key.accepts(event, HardwareKeyboard.instance)) {
        entry.value();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}

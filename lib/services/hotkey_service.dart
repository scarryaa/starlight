import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class HotkeyService {
  final Map<ShortcutActivator, VoidCallback> _globalHotkeys = {};
  final Map<ShortcutActivator, VoidCallback> _localHotkeys = {};

  void registerGlobalHotkey(
      ShortcutActivator activator, VoidCallback callback) {
    _globalHotkeys[activator] = callback;
  }

  void registerLocalHotkey(ShortcutActivator activator, VoidCallback callback) {
    _localHotkeys[activator] = callback;
  }

  void unregisterGlobalHotkey(ShortcutActivator activator) {
    _globalHotkeys.remove(activator);
  }

  void unregisterLocalHotkey(ShortcutActivator activator) {
    _localHotkeys.remove(activator);
  }

  bool isGlobalHotkey(KeyEvent event) {
    return _globalHotkeys.keys.any(
        (activator) => activator.accepts(event, HardwareKeyboard.instance));
  }

  KeyEventResult handleKeyEvent(KeyEvent event) {
    // Check global hotkeys first
    for (final entry in _globalHotkeys.entries) {
      if (entry.key.accepts(event, HardwareKeyboard.instance)) {
        entry.value();
        return KeyEventResult.handled;
      }
    }

    // Then check local hotkeys
    for (final entry in _localHotkeys.entries) {
      if (entry.key.accepts(event, HardwareKeyboard.instance)) {
        entry.value();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}

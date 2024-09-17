import 'dart:async';
import 'package:flutter/material.dart';

class MessageToast {
  static const double _toastHeight = 50.0;
  static const double _toastWidth = 300.0;
  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const Duration _displayDuration = Duration(seconds: 3);

  final String message;
  final BuildContext context;
  late OverlayEntry _entry;
  Timer? _timer;

  MessageToast({required this.message, required this.context}) {
    _createOverlayEntry();
    _insertOverlay();
    _startTimer();
  }

  void _createOverlayEntry() {
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 50,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: _toastWidth,
            height: _toastHeight,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _insertOverlay() {
    Overlay.of(context).insert(_entry);
  }

  void _startTimer() {
    _timer = Timer(_displayDuration, remove);
  }

  void remove() {
    _timer?.cancel();
    _entry.remove();
  }
}

class MessageToastManager {
  static void showToast(BuildContext context, String message) {
    MessageToast(message: message, context: context);
  }
}

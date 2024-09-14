import 'dart:async';

import 'package:flutter/material.dart';

class ErrorToast {
  static const double _toastHeight = 120.0;
  static const double _toastWidth = 300.0;
  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const Duration _autoRemoveDuration = Duration(seconds: 6);
  final String filePath;
  final String errorMessage;

  late OverlayEntry _entry;
  Timer? _autoRemoveTimer;
  final VoidCallback _onRemove;
  final BuildContext _context;

  ErrorToast({
    required this.filePath,
    required this.errorMessage,
    required BuildContext context,
    required VoidCallback onRemove,
  })  : _context = context,
        _onRemove = onRemove {
    _createOverlayEntry();
    _insertOverlay();
    _startAutoRemoveTimer();
  }

  void remove() {
    _autoRemoveTimer?.cancel();
    _entry.remove();
    _onRemove();
  }

  Widget _buildToastWidget() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _toastWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red[700],
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Error',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: remove,
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Failed to open file:',
              style: TextStyle(color: Colors.white),
            ),
            Text(
              filePath,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Error: $errorMessage',
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _createOverlayEntry() {
    _entry = OverlayEntry(
      builder: (context) => _buildToastWidget(),
    );
  }

  void _insertOverlay() {
    Overlay.of(_context).insert(_entry);
  }

  void _startAutoRemoveTimer() {
    _autoRemoveTimer = Timer(_autoRemoveDuration, remove);
  }
}

class ErrorToastManager {
  static const double _bottomMargin = 50.0;
  static const double _toastSpacing = 10.0;
  final List<ErrorToast> _activeToasts = [];
  final BuildContext _context;

  ErrorToastManager(this._context);

  void showErrorToast(String filePath, String errorMessage) {
    ErrorToast? newToast;

    void removeToast() {
      if (newToast != null) {
        _removeToast(newToast);
      }
    }

    newToast = ErrorToast(
      filePath: filePath,
      errorMessage: errorMessage,
      context: _context,
      onRemove: removeToast,
    );

    _activeToasts.insert(
        0, newToast); // Add new toast at the beginning of the list
    _updateToastPositions();
  }

  void _removeToast(ErrorToast toast) {
    _activeToasts.remove(toast);
    _updateToastPositions();
  }

  void _updateToastPositions() {
    for (int i = 0; i < _activeToasts.length; i++) {
      final bottomOffset =
          _bottomMargin + (i * (ErrorToast._toastHeight + _toastSpacing));
      _activeToasts[i]._entry.remove(); // Remove the old entry
      _activeToasts[i]._entry = OverlayEntry(
        builder: (context) => AnimatedPositioned(
          duration: ErrorToast._animationDuration,
          curve: Curves.easeInOut,
          bottom: bottomOffset,
          right: 20,
          child: AnimatedOpacity(
            duration: ErrorToast._animationDuration,
            opacity: 1.0,
            child: _activeToasts[i]._buildToastWidget(),
          ),
        ),
      );
      Overlay.of(_context).insert(_activeToasts[i]._entry);
    }
  }
}

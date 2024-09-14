import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ErrorToast {
  static const double _collapsedToastHeight = 120.0;
  static const double _maxExpandedToastHeight = 200.0;
  static const double _toastWidth = 300.0;
  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const Duration _autoRemoveDuration = Duration(seconds: 6);
  static const Duration _copyFeedbackDuration = Duration(seconds: 1);
  final VoidCallback _onExpand;
  final String filePath;
  final String errorMessage;

  bool _isHovered = false;
  late OverlayEntry _entry;
  Timer? _autoRemoveTimer;
  Timer? _copyFeedbackTimer;
  final VoidCallback _onRemove;
  final BuildContext _context;
  bool _isExpanded = false;
  bool _showCopyFeedback = false;

  ErrorToast({
    required this.filePath,
    required this.errorMessage,
    required BuildContext context,
    required VoidCallback onRemove,
    required VoidCallback onExpand,
  })  : _context = context,
        _onRemove = onRemove,
        _onExpand = onExpand {
    _createOverlayEntry();
    _insertOverlay();
    _startAutoRemoveTimer();
  }

  void remove() {
    _autoRemoveTimer?.cancel();
    _copyFeedbackTimer?.cancel();
    _entry.remove();
    _onRemove();
  }

  Widget _buildToastWidget() {
    return Material(
      color: Colors.transparent,
      child: MouseRegion(
          onEnter: (_) => _onHover(true),
          onExit: (_) => _onHover(false),
          child: AnimatedContainer(
            duration: _animationDuration,
            curve: Curves.easeInOut,
            width: _toastWidth,
            height:
                _isExpanded ? _maxExpandedToastHeight : _collapsedToastHeight,
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
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Error',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _showCopyFeedback ? Icons.check : Icons.copy,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _copyToClipboard,
                          tooltip: 'Copy error to clipboard',
                        ),
                        IconButton(
                          icon: AnimatedSwitcher(
                            duration: _animationDuration,
                            child: Icon(
                              _isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.white,
                              size: 20,
                              key: ValueKey<bool>(_isExpanded),
                            ),
                          ),
                          onPressed: _toggleExpand,
                          tooltip: _isExpanded ? 'Collapse' : 'Expand',
                        ),
                        GestureDetector(
                          onTap: remove,
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Failed to open file: $filePath',
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: _animationDuration,
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: _isExpanded
                        ? SingleChildScrollView(
                            key: const ValueKey<bool>(true),
                            child: Text(
                              'Error: $errorMessage',
                              style: const TextStyle(color: Colors.white),
                            ),
                          )
                        : Text(
                            'Error: ${errorMessage.split('\n').first}',
                            key: const ValueKey<bool>(false),
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
              ],
            ),
          )),
    );
  }

  void _copyToClipboard() {
    final errorText = 'File: $filePath\nError: $errorMessage';
    Clipboard.setData(ClipboardData(text: errorText));
    _showCopyFeedback = true;
    _updateOverlay();
    _copyFeedbackTimer?.cancel();
    _copyFeedbackTimer = Timer(_copyFeedbackDuration, () {
      _showCopyFeedback = false;
      _updateOverlay();
    });
  }

  void _createOverlayEntry() {
    _entry = OverlayEntry(
      builder: (context) => _buildToastWidget(),
    );
  }

  void _insertOverlay() {
    Overlay.of(_context).insert(_entry);
  }

  void _onHover(bool isHovered) {
    _isHovered = isHovered;
    if (_isHovered) {
      _pauseAutoRemoveTimer();
    } else {
      _resumeAutoRemoveTimer();
    }
  }

  void _pauseAutoRemoveTimer() {
    _autoRemoveTimer?.cancel();
  }

  void _resumeAutoRemoveTimer() {
    _autoRemoveTimer?.cancel();
    _autoRemoveTimer = Timer(_autoRemoveDuration, remove);
  }

  void _startAutoRemoveTimer() {
    _autoRemoveTimer = Timer(_autoRemoveDuration, remove);
  }

  void _toggleExpand() {
    _isExpanded = !_isExpanded;
    _updateOverlay();
    _onExpand();
  }

  void _updateOverlay() {
    _entry.markNeedsBuild();
  }
}

class ErrorToastManager {
  static const double _bottomMargin = 30.0;
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
      onExpand: _updateToastPositions,
    );

    _activeToasts.insert(0, newToast);
    _updateToastPositions();
  }

  void _removeToast(ErrorToast toast) {
    _activeToasts.remove(toast);
    _updateToastPositions();
  }

  void _updateToastPositions() {
    double totalHeight = 0;
    for (int i = 0; i < _activeToasts.length; i++) {
      final toast = _activeToasts[i];
      final bottomOffset = _bottomMargin + totalHeight;
      toast._entry.remove();
      toast._entry = OverlayEntry(
        builder: (context) => AnimatedPositioned(
          duration: ErrorToast._animationDuration,
          curve: Curves.easeInOut,
          bottom: bottomOffset,
          right: 10,
          child: AnimatedOpacity(
            duration: ErrorToast._animationDuration,
            opacity: 1.0,
            child: toast._buildToastWidget(),
          ),
        ),
      );
      Overlay.of(_context).insert(toast._entry);
      totalHeight += (toast._isExpanded
              ? ErrorToast._maxExpandedToastHeight
              : ErrorToast._collapsedToastHeight) +
          _toastSpacing;
    }
  }
}

// Mocks generated by Mockito 5.4.4 from annotations
// in starlight/test/features/editor/editor_content_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i9;
import 'dart:io' as _i19;
import 'dart:ui' as _i12;

import 'package:flutter/animation.dart' as _i10;
import 'package:flutter/foundation.dart' as _i7;
import 'package:flutter/material.dart' as _i8;
import 'package:flutter/src/widgets/scroll_context.dart' as _i11;
import 'package:flutter/src/widgets/scroll_physics.dart' as _i3;
import 'package:flutter/src/widgets/scroll_position.dart' as _i2;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i17;
import 'package:starlight/features/editor/models/cursor_position.dart' as _i20;
import 'package:starlight/features/editor/models/rope.dart' as _i4;
import 'package:starlight/features/editor/models/selection_mode.dart' as _i15;
import 'package:starlight/features/editor/services/editor_scroll_manager.dart'
    as _i13;
import 'package:starlight/features/editor/services/editor_selection_manager.dart'
    as _i14;
import 'package:starlight/services/config_service.dart' as _i16;
import 'package:starlight/services/file_service.dart' as _i5;
import 'package:starlight/services/hotkey_service.dart' as _i18;
import 'package:starlight/services/tab_service.dart' as _i6;
import 'package:starlight/services/theme_manager.dart' as _i22;
import 'package:starlight/widgets/tab/tab.dart' as _i21;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeScrollPosition_0 extends _i1.SmartFake
    implements _i2.ScrollPosition {
  _FakeScrollPosition_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeScrollPhysics_1 extends _i1.SmartFake implements _i3.ScrollPhysics {
  _FakeScrollPhysics_1(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeRope_2 extends _i1.SmartFake implements _i4.Rope {
  _FakeRope_2(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeFileService_3 extends _i1.SmartFake implements _i5.FileService {
  _FakeFileService_3(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeTabService_4 extends _i1.SmartFake implements _i6.TabService {
  _FakeTabService_4(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeValueNotifier_5<T> extends _i1.SmartFake
    implements _i7.ValueNotifier<T> {
  _FakeValueNotifier_5(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeThemeData_6 extends _i1.SmartFake implements _i8.ThemeData {
  _FakeThemeData_6(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );

  @override
  String toString({_i7.DiagnosticLevel? minLevel = _i7.DiagnosticLevel.info}) =>
      super.toString();
}

/// A class which mocks [ScrollController].
///
/// See the documentation for Mockito's code generation for more information.
class MockScrollController extends _i1.Mock implements _i8.ScrollController {
  MockScrollController() {
    _i1.throwOnMissingStub(this);
  }

  @override
  bool get keepScrollOffset => (super.noSuchMethod(
        Invocation.getter(#keepScrollOffset),
        returnValue: false,
      ) as bool);

  @override
  double get initialScrollOffset => (super.noSuchMethod(
        Invocation.getter(#initialScrollOffset),
        returnValue: 0.0,
      ) as double);

  @override
  Iterable<_i2.ScrollPosition> get positions => (super.noSuchMethod(
        Invocation.getter(#positions),
        returnValue: <_i2.ScrollPosition>[],
      ) as Iterable<_i2.ScrollPosition>);

  @override
  bool get hasClients => (super.noSuchMethod(
        Invocation.getter(#hasClients),
        returnValue: false,
      ) as bool);

  @override
  _i2.ScrollPosition get position => (super.noSuchMethod(
        Invocation.getter(#position),
        returnValue: _FakeScrollPosition_0(
          this,
          Invocation.getter(#position),
        ),
      ) as _i2.ScrollPosition);

  @override
  double get offset => (super.noSuchMethod(
        Invocation.getter(#offset),
        returnValue: 0.0,
      ) as double);

  @override
  bool get hasListeners => (super.noSuchMethod(
        Invocation.getter(#hasListeners),
        returnValue: false,
      ) as bool);

  @override
  _i9.Future<void> animateTo(
    double? offset, {
    required Duration? duration,
    required _i10.Curve? curve,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #animateTo,
          [offset],
          {
            #duration: duration,
            #curve: curve,
          },
        ),
        returnValue: _i9.Future<void>.value(),
        returnValueForMissingStub: _i9.Future<void>.value(),
      ) as _i9.Future<void>);

  @override
  void jumpTo(double? value) => super.noSuchMethod(
        Invocation.method(
          #jumpTo,
          [value],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void attach(_i2.ScrollPosition? position) => super.noSuchMethod(
        Invocation.method(
          #attach,
          [position],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void detach(_i2.ScrollPosition? position) => super.noSuchMethod(
        Invocation.method(
          #detach,
          [position],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i2.ScrollPosition createScrollPosition(
    _i3.ScrollPhysics? physics,
    _i11.ScrollContext? context,
    _i2.ScrollPosition? oldPosition,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #createScrollPosition,
          [
            physics,
            context,
            oldPosition,
          ],
        ),
        returnValue: _FakeScrollPosition_0(
          this,
          Invocation.method(
            #createScrollPosition,
            [
              physics,
              context,
              oldPosition,
            ],
          ),
        ),
      ) as _i2.ScrollPosition);

  @override
  void debugFillDescription(List<String>? description) => super.noSuchMethod(
        Invocation.method(
          #debugFillDescription,
          [description],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void addListener(_i12.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(
          #addListener,
          [listener],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void removeListener(_i12.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(
          #removeListener,
          [listener],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void notifyListeners() => super.noSuchMethod(
        Invocation.method(
          #notifyListeners,
          [],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [EditorScrollManager].
///
/// See the documentation for Mockito's code generation for more information.
class MockEditorScrollManager extends _i1.Mock
    implements _i13.EditorScrollManager {
  MockEditorScrollManager() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.ScrollPhysics get clampingScrollPhysics => (super.noSuchMethod(
        Invocation.getter(#clampingScrollPhysics),
        returnValue: _FakeScrollPhysics_1(
          this,
          Invocation.getter(#clampingScrollPhysics),
        ),
      ) as _i3.ScrollPhysics);

  @override
  _i9.Future<void> ensureCursorVisible(
    _i8.ScrollController? horizontalController,
    _i8.ScrollController? verticalController,
    double? charWidth,
    int? caretPosition,
    double? lineHeight,
    int? caretLine,
    double? editorPadding,
    double? viewPadding,
    _i8.BuildContext? context,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #ensureCursorVisible,
          [
            horizontalController,
            verticalController,
            charWidth,
            caretPosition,
            lineHeight,
            caretLine,
            editorPadding,
            viewPadding,
            context,
          ],
        ),
        returnValue: _i9.Future<void>.value(),
        returnValueForMissingStub: _i9.Future<void>.value(),
      ) as _i9.Future<void>);

  @override
  void preventOverscroll(
    _i8.ScrollController? horizontalController,
    _i8.ScrollController? verticalController,
    double? editorPadding,
    double? viewPadding,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #preventOverscroll,
          [
            horizontalController,
            verticalController,
            editorPadding,
            viewPadding,
          ],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [EditorSelectionManager].
///
/// See the documentation for Mockito's code generation for more information.
class MockEditorSelectionManager extends _i1.Mock
    implements _i14.EditorSelectionManager {
  MockEditorSelectionManager() {
    _i1.throwOnMissingStub(this);
  }

  @override
  int get selectionStart => (super.noSuchMethod(
        Invocation.getter(#selectionStart),
        returnValue: 0,
      ) as int);

  @override
  set selectionStart(int? _selectionStart) => super.noSuchMethod(
        Invocation.setter(
          #selectionStart,
          _selectionStart,
        ),
        returnValueForMissingStub: null,
      );

  @override
  int get selectionEnd => (super.noSuchMethod(
        Invocation.getter(#selectionEnd),
        returnValue: 0,
      ) as int);

  @override
  set selectionEnd(int? _selectionEnd) => super.noSuchMethod(
        Invocation.setter(
          #selectionEnd,
          _selectionEnd,
        ),
        returnValueForMissingStub: null,
      );

  @override
  int get selectionAnchor => (super.noSuchMethod(
        Invocation.getter(#selectionAnchor),
        returnValue: 0,
      ) as int);

  @override
  set selectionAnchor(int? _selectionAnchor) => super.noSuchMethod(
        Invocation.setter(
          #selectionAnchor,
          _selectionAnchor,
        ),
        returnValueForMissingStub: null,
      );

  @override
  int get selectionFocus => (super.noSuchMethod(
        Invocation.getter(#selectionFocus),
        returnValue: 0,
      ) as int);

  @override
  set selectionFocus(int? _selectionFocus) => super.noSuchMethod(
        Invocation.setter(
          #selectionFocus,
          _selectionFocus,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i4.Rope get rope => (super.noSuchMethod(
        Invocation.getter(#rope),
        returnValue: _FakeRope_2(
          this,
          Invocation.getter(#rope),
        ),
      ) as _i4.Rope);

  @override
  set rope(_i4.Rope? _rope) => super.noSuchMethod(
        Invocation.setter(
          #rope,
          _rope,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i15.SelectionMode get selectionMode => (super.noSuchMethod(
        Invocation.getter(#selectionMode),
        returnValue: _i15.SelectionMode.normal,
      ) as _i15.SelectionMode);

  @override
  void setSelectionMode(_i15.SelectionMode? mode) => super.noSuchMethod(
        Invocation.method(
          #setSelectionMode,
          [mode],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void updateRope(_i4.Rope? r) => super.noSuchMethod(
        Invocation.method(
          #updateRope,
          [r],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void clearSelection() => super.noSuchMethod(
        Invocation.method(
          #clearSelection,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void updateSelection() => super.noSuchMethod(
        Invocation.method(
          #updateSelection,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  bool hasSelection() => (super.noSuchMethod(
        Invocation.method(
          #hasSelection,
          [],
        ),
        returnValue: false,
      ) as bool);

  @override
  void moveSelectionHorizontally(int? target) => super.noSuchMethod(
        Invocation.method(
          #moveSelectionHorizontally,
          [target],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void moveSelectionVertically(int? target) => super.noSuchMethod(
        Invocation.method(
          #moveSelectionVertically,
          [target],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void normalizeSelection() => super.noSuchMethod(
        Invocation.method(
          #normalizeSelection,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void selectWord(int? position) => super.noSuchMethod(
        Invocation.method(
          #selectWord,
          [position],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void selectLine(int? position) => super.noSuchMethod(
        Invocation.method(
          #selectLine,
          [position],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void updateWordSelection(int? position) => super.noSuchMethod(
        Invocation.method(
          #updateWordSelection,
          [position],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void updateLineSelection(int? position) => super.noSuchMethod(
        Invocation.method(
          #updateLineSelection,
          [position],
        ),
        returnValueForMissingStub: null,
      );

  @override
  int findWordBoundary(
    int? position,
    bool? isStart,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #findWordBoundary,
          [
            position,
            isStart,
          ],
        ),
        returnValue: 0,
      ) as int);

  @override
  void handleTapSelection(int? tapPosition) => super.noSuchMethod(
        Invocation.method(
          #handleTapSelection,
          [tapPosition],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void handleDragSelection(int? currentPosition) => super.noSuchMethod(
        Invocation.method(
          #handleDragSelection,
          [currentPosition],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [ConfigService].
///
/// See the documentation for Mockito's code generation for more information.
class MockConfigService extends _i1.Mock implements _i16.ConfigService {
  MockConfigService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i5.FileService get fileService => (super.noSuchMethod(
        Invocation.getter(#fileService),
        returnValue: _FakeFileService_3(
          this,
          Invocation.getter(#fileService),
        ),
      ) as _i5.FileService);

  @override
  set fileService(_i5.FileService? _fileService) => super.noSuchMethod(
        Invocation.setter(
          #fileService,
          _fileService,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i6.TabService get tabService => (super.noSuchMethod(
        Invocation.getter(#tabService),
        returnValue: _FakeTabService_4(
          this,
          Invocation.getter(#tabService),
        ),
      ) as _i6.TabService);

  @override
  set tabService(_i6.TabService? _tabService) => super.noSuchMethod(
        Invocation.setter(
          #tabService,
          _tabService,
        ),
        returnValueForMissingStub: null,
      );

  @override
  String get configPath => (super.noSuchMethod(
        Invocation.getter(#configPath),
        returnValue: _i17.dummyValue<String>(
          this,
          Invocation.getter(#configPath),
        ),
      ) as String);

  @override
  set configPath(String? _configPath) => super.noSuchMethod(
        Invocation.setter(
          #configPath,
          _configPath,
        ),
        returnValueForMissingStub: null,
      );

  @override
  Map<String, dynamic> get config => (super.noSuchMethod(
        Invocation.getter(#config),
        returnValue: <String, dynamic>{},
      ) as Map<String, dynamic>);

  @override
  set config(Map<String, dynamic>? _config) => super.noSuchMethod(
        Invocation.setter(
          #config,
          _config,
        ),
        returnValueForMissingStub: null,
      );

  @override
  void createDefaultConfig() => super.noSuchMethod(
        Invocation.method(
          #createDefaultConfig,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void loadConfig() => super.noSuchMethod(
        Invocation.method(
          #loadConfig,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void saveConfig() => super.noSuchMethod(
        Invocation.method(
          #saveConfig,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void openConfig() => super.noSuchMethod(
        Invocation.method(
          #openConfig,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void updateConfig(
    String? key,
    dynamic value,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #updateConfig,
          [
            key,
            value,
          ],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [HotkeyService].
///
/// See the documentation for Mockito's code generation for more information.
class MockHotkeyService extends _i1.Mock implements _i18.HotkeyService {
  MockHotkeyService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  void registerGlobalHotkey(
    _i8.ShortcutActivator? activator,
    _i12.VoidCallback? callback,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #registerGlobalHotkey,
          [
            activator,
            callback,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void registerLocalHotkey(
    _i8.ShortcutActivator? activator,
    _i12.VoidCallback? callback,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #registerLocalHotkey,
          [
            activator,
            callback,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void unregisterGlobalHotkey(_i8.ShortcutActivator? activator) =>
      super.noSuchMethod(
        Invocation.method(
          #unregisterGlobalHotkey,
          [activator],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void unregisterLocalHotkey(_i8.ShortcutActivator? activator) =>
      super.noSuchMethod(
        Invocation.method(
          #unregisterLocalHotkey,
          [activator],
        ),
        returnValueForMissingStub: null,
      );

  @override
  bool isGlobalHotkey(_i8.KeyEvent? event) => (super.noSuchMethod(
        Invocation.method(
          #isGlobalHotkey,
          [event],
        ),
        returnValue: false,
      ) as bool);

  @override
  _i8.KeyEventResult handleKeyEvent(_i8.KeyEvent? event) => (super.noSuchMethod(
        Invocation.method(
          #handleKeyEvent,
          [event],
        ),
        returnValue: _i8.KeyEventResult.handled,
      ) as _i8.KeyEventResult);
}

/// A class which mocks [FileService].
///
/// See the documentation for Mockito's code generation for more information.
class MockFileService extends _i1.Mock implements _i5.FileService {
  MockFileService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  List<_i19.File> get openFiles => (super.noSuchMethod(
        Invocation.getter(#openFiles),
        returnValue: <_i19.File>[],
      ) as List<_i19.File>);

  @override
  set openFiles(List<_i19.File>? _openFiles) => super.noSuchMethod(
        Invocation.setter(
          #openFiles,
          _openFiles,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set currentFile(_i19.File? file) => super.noSuchMethod(
        Invocation.setter(
          #currentFile,
          file,
        ),
        returnValueForMissingStub: null,
      );

  @override
  bool get hasListeners => (super.noSuchMethod(
        Invocation.getter(#hasListeners),
        returnValue: false,
      ) as bool);

  @override
  String readFile(String? path) => (super.noSuchMethod(
        Invocation.method(
          #readFile,
          [path],
        ),
        returnValue: _i17.dummyValue<String>(
          this,
          Invocation.method(
            #readFile,
            [path],
          ),
        ),
      ) as String);

  @override
  void writeFile(
    String? path,
    String? content,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #writeFile,
          [
            path,
            content,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  String getAbsolutePath(String? path) => (super.noSuchMethod(
        Invocation.method(
          #getAbsolutePath,
          [path],
        ),
        returnValue: _i17.dummyValue<String>(
          this,
          Invocation.method(
            #getAbsolutePath,
            [path],
          ),
        ),
      ) as String);

  @override
  void selectFile(String? path) => super.noSuchMethod(
        Invocation.method(
          #selectFile,
          [path],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void openFile(String? path) => super.noSuchMethod(
        Invocation.method(
          #openFile,
          [path],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void closeFile(String? path) => super.noSuchMethod(
        Invocation.method(
          #closeFile,
          [path],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void addListener(_i12.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(
          #addListener,
          [listener],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void removeListener(_i12.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(
          #removeListener,
          [listener],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void notifyListeners() => super.noSuchMethod(
        Invocation.method(
          #notifyListeners,
          [],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [TabService].
///
/// See the documentation for Mockito's code generation for more information.
class MockTabService extends _i1.Mock implements _i6.TabService {
  MockTabService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i5.FileService get fileService => (super.noSuchMethod(
        Invocation.getter(#fileService),
        returnValue: _FakeFileService_3(
          this,
          Invocation.getter(#fileService),
        ),
      ) as _i5.FileService);

  @override
  set fileService(_i5.FileService? _fileService) => super.noSuchMethod(
        Invocation.setter(
          #fileService,
          _fileService,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i7.ValueNotifier<int?> get currentTabIndexNotifier => (super.noSuchMethod(
        Invocation.getter(#currentTabIndexNotifier),
        returnValue: _FakeValueNotifier_5<int?>(
          this,
          Invocation.getter(#currentTabIndexNotifier),
        ),
      ) as _i7.ValueNotifier<int?>);

  @override
  _i7.ValueNotifier<_i20.CursorPosition> get cursorPositionNotifier =>
      (super.noSuchMethod(
        Invocation.getter(#cursorPositionNotifier),
        returnValue: _FakeValueNotifier_5<_i20.CursorPosition>(
          this,
          Invocation.getter(#cursorPositionNotifier),
        ),
      ) as _i7.ValueNotifier<_i20.CursorPosition>);

  @override
  List<_i21.Tab> get tabs => (super.noSuchMethod(
        Invocation.getter(#tabs),
        returnValue: <_i21.Tab>[],
      ) as List<_i21.Tab>);

  @override
  bool get hasListeners => (super.noSuchMethod(
        Invocation.getter(#hasListeners),
        returnValue: false,
      ) as bool);

  @override
  void setCurrentTab(int? index) => super.noSuchMethod(
        Invocation.method(
          #setCurrentTab,
          [index],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void addTab(
    String? fileName,
    String? path,
    String? fullAbsolutePath,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #addTab,
          [
            fileName,
            path,
            fullAbsolutePath,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void removeTab(String? path) => super.noSuchMethod(
        Invocation.method(
          #removeTab,
          [path],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void closeLeft(int? index) => super.noSuchMethod(
        Invocation.method(
          #closeLeft,
          [index],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void closeRight(int? index) => super.noSuchMethod(
        Invocation.method(
          #closeRight,
          [index],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void closeOtherTabs(int? index) => super.noSuchMethod(
        Invocation.method(
          #closeOtherTabs,
          [index],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void closeAllTabs() => super.noSuchMethod(
        Invocation.method(
          #closeAllTabs,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void pinTab(int? index) => super.noSuchMethod(
        Invocation.method(
          #pinTab,
          [index],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void unpinTab(int? index) => super.noSuchMethod(
        Invocation.method(
          #unpinTab,
          [index],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void copyRelativePath(int? index) => super.noSuchMethod(
        Invocation.method(
          #copyRelativePath,
          [index],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void copyPath(int? index) => super.noSuchMethod(
        Invocation.method(
          #copyPath,
          [index],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void updateTabContent(
    String? path,
    String? content, {
    required bool? isModified,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #updateTabContent,
          [
            path,
            content,
          ],
          {#isModified: isModified},
        ),
        returnValueForMissingStub: null,
      );

  @override
  void reorderTabs(
    int? oldIndex,
    int? newIndex,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #reorderTabs,
          [
            oldIndex,
            newIndex,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void setTabModified(
    String? path,
    bool? isModified,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #setTabModified,
          [
            path,
            isModified,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void updateCursorPosition(
    String? path,
    _i20.CursorPosition? position,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #updateCursorPosition,
          [
            path,
            position,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void addListener(_i12.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(
          #addListener,
          [listener],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void removeListener(_i12.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(
          #removeListener,
          [listener],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void notifyListeners() => super.noSuchMethod(
        Invocation.method(
          #notifyListeners,
          [],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [ThemeManager].
///
/// See the documentation for Mockito's code generation for more information.
class MockThemeManager extends _i1.Mock implements _i22.ThemeManager {
  MockThemeManager() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i8.ThemeMode get themeMode => (super.noSuchMethod(
        Invocation.getter(#themeMode),
        returnValue: _i8.ThemeMode.system,
      ) as _i8.ThemeMode);

  @override
  _i8.ThemeData get lightTheme => (super.noSuchMethod(
        Invocation.getter(#lightTheme),
        returnValue: _FakeThemeData_6(
          this,
          Invocation.getter(#lightTheme),
        ),
      ) as _i8.ThemeData);

  @override
  _i8.ThemeData get darkTheme => (super.noSuchMethod(
        Invocation.getter(#darkTheme),
        returnValue: _FakeThemeData_6(
          this,
          Invocation.getter(#darkTheme),
        ),
      ) as _i8.ThemeData);

  @override
  _i8.ThemeData get currentTheme => (super.noSuchMethod(
        Invocation.getter(#currentTheme),
        returnValue: _FakeThemeData_6(
          this,
          Invocation.getter(#currentTheme),
        ),
      ) as _i8.ThemeData);

  @override
  bool get hasListeners => (super.noSuchMethod(
        Invocation.getter(#hasListeners),
        returnValue: false,
      ) as bool);

  @override
  void setThemeMode(dynamic mode) => super.noSuchMethod(
        Invocation.method(
          #setThemeMode,
          [mode],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void setLightTheme(_i8.ThemeData? theme) => super.noSuchMethod(
        Invocation.method(
          #setLightTheme,
          [theme],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void setDarkTheme(_i8.ThemeData? theme) => super.noSuchMethod(
        Invocation.method(
          #setDarkTheme,
          [theme],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void toggleTheme() => super.noSuchMethod(
        Invocation.method(
          #toggleTheme,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void addListener(_i12.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(
          #addListener,
          [listener],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void removeListener(_i12.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(
          #removeListener,
          [listener],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void notifyListeners() => super.noSuchMethod(
        Invocation.method(
          #notifyListeners,
          [],
        ),
        returnValueForMissingStub: null,
      );
}

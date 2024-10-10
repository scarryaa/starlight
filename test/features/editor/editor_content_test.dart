import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/editor/editor_content.dart';
import 'package:starlight/features/editor/models/rope.dart';
import 'package:starlight/features/editor/services/editor_keyboard_handler.dart';
import 'package:starlight/features/editor/services/editor_scroll_manager.dart';
import 'package:starlight/features/editor/services/editor_selection_manager.dart';
import 'package:starlight/services/config_service.dart';
import 'package:starlight/services/file_service.dart';
import 'package:starlight/services/hotkey_service.dart';
import 'package:starlight/services/tab_service.dart';
import 'package:starlight/services/theme_manager.dart';
import 'package:starlight/widgets/tab/tab.dart' as CustomTab;

@GenerateMocks([
  ScrollController,
  EditorScrollManager,
  EditorSelectionManager,
  ConfigService,
  HotkeyService,
  FileService,
  TabService,
  ThemeManager
])
import 'editor_content_test.mocks.dart';

class MockScrollPosition extends Mock implements ScrollPosition {
  @override
  double get maxScrollExtent => 1000.0;

  @override
  double get viewportDimension => 600.0;

  @override
  double get pixels => 0.0;

  @override
  bool get hasContentDimensions => true;

  @override
  bool get hasViewportDimension => true;

  @override
  bool get haveDimensions => true;

  @override
  bool get hasPixels => true;

  @override
  double get minScrollExtent => 0.0;

  @override
  bool get outOfRange => false;

  @override
  double get devicePixelRatio => 1.0;
}

void main() {
  group('EditorContent Widget Tests', () {
    late MockScrollController verticalController;
    late MockScrollController horizontalController;
    late MockEditorScrollManager scrollManager;
    late MockEditorSelectionManager editorSelectionManager;
    late MockConfigService configService;
    late MockHotkeyService hotkeyService;
    late MockFileService fileService;
    late MockTabService tabService;
    late CustomTab.Tab tab;
    late MockThemeManager themeManager;
    late MockScrollPosition mockScrollPosition;

    setUp(() {
      verticalController = MockScrollController();
      horizontalController = MockScrollController();
      scrollManager = MockEditorScrollManager();
      editorSelectionManager = MockEditorSelectionManager();
      configService = MockConfigService();
      hotkeyService = MockHotkeyService();
      fileService = MockFileService();
      tabService = MockTabService();
      themeManager = MockThemeManager();
      mockScrollPosition = MockScrollPosition();
      tab = CustomTab.Tab(
        fullPath: '/path/to/test.dart',
        fullAbsolutePath: '/path/to/test.dart',
        isSelected: true,
        isModified: false,
        path: '/path/to/test.dart',
        content: 'Test content',
      );

      // Set up default behaviors for mocks
      when(editorSelectionManager.selectionStart).thenReturn(0);
      when(editorSelectionManager.selectionEnd).thenReturn(0);
      when(configService.config).thenReturn({});
      when(verticalController.offset).thenReturn(0.0);
      when(horizontalController.offset).thenReturn(0.0);
      when(themeManager.themeMode).thenReturn(ThemeMode.light);
      when(scrollManager.clampingScrollPhysics).thenReturn(const ClampingScrollPhysics());
      when(editorSelectionManager.updateRope(any)).thenReturn(null);

      // Set up ScrollController mocks
      when(verticalController.position).thenReturn(mockScrollPosition);
      when(horizontalController.position).thenReturn(mockScrollPosition);
      when(verticalController.positions).thenReturn([mockScrollPosition]);
      when(horizontalController.positions).thenReturn([mockScrollPosition]);

      // Mock createScrollPosition method
      when(verticalController.createScrollPosition(any, any, any)).thenReturn(mockScrollPosition);
      when(horizontalController.createScrollPosition(any, any, any)).thenReturn(mockScrollPosition);
    });

    testWidgets('EditorContent initializes correctly', (WidgetTester tester) async {
      // Set a consistent surface size for the test
      tester.binding.window.physicalSizeTestValue = const Size(1280, 720);
      tester.binding.window.devicePixelRatioTestValue = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ThemeManager>.value(
            value: themeManager,
            child: SizedBox(
              width: 800,
              height: 600,
              child: EditorContent(
                verticalController: verticalController,
                horizontalController: horizontalController,
                scrollManager: scrollManager,
                editorSelectionManager: editorSelectionManager,
                configService: configService,
                hotkeyService: hotkeyService,
                tab: tab,
                fileService: fileService,
                tabService: tabService,
                lineHeight: 20.0,
                fontFamily: 'Roboto Mono',
                fontSize: 14.0,
                tabSize: 4,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(EditorContent), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget); // Check for EditorPainter
    });
  });
}

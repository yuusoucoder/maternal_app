import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/assessment_model.dart';
import 'screens/danger_check_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/model_info_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AIOVY — Maternal Risk Assessment (research prototype)
//
// No backend, no database, no login, no real patient data.
// Assessments live only in memory (SessionManager) and vanish when the app
// is closed.
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // Needed before touching platform services (like the status bar)
  // ahead of runApp().
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(kLightStatusBar);
  runApp(const MaternAIApp());
}

// ═════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ═════════════════════════════════════════════════════════════════════════════

/// Color tokens. Every color in the app comes from here, so changing the
/// palette means editing only this class.
class C {
  C._();

  // Primary gradient (header backgrounds on all screens)
  static const g1 = Color(0xFF6B1A3A); // Deep rose (gradient start)
  static const g2 = Color(0xFFBF3A6E); // Rose pink (gradient end)

  // Page and card backgrounds
  static const bg = Color(0xFFFDF4F7); // Very light pink-white page bg
  static const card = Color(0xFFFFFFFF); // Pure white cards

  // Text
  static const t1 = Color(0xFF1A0A10); // Almost black
  static const t2 = Color(0xFF7A5060); // Muted rose-gray
  static const t3 = Color(0xFFBDA0AC); // Light muted (captions, hints)

  // Text on dark gradient backgrounds
  static const onDark = Color(0xFFFFFFFF);
  static const onDarkSub = Color(0xFFD4A0B5);

  // Risk level colors — clinically standard traffic-light colors
  static const low = Color(0xFF16A34A); // Green
  static const lowBg = Color(0xFFDCFCE7);
  static const lowBdr = Color(0xFF86EFAC);
  static const mid = Color(0xFFD97706); // Amber
  static const midBg = Color(0xFFFEF3C7);
  static const midBdr = Color(0xFFFCD34D);
  static const high = Color(0xFFDC2626); // Red
  static const highBg = Color(0xFFFEE2E2);
  static const highBdr = Color(0xFFFCA5A5);

  // Bottom nav
  static const navBg = Color(0xFF1A0A10); // Very dark rose-black
  static const navIcon = Color(0xFF7A5060); // Inactive icon color

  // Empty part of progress / SHAP bars (a soft rose-gray "track").
  static const track = Color(0xFFF3E8ED);
}

/// Soft two-layer shadow used instead of borders on every card
/// (Apple HIG style: depth instead of outlines).
final List<BoxShadow> kCardShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.07),
    blurRadius: 20,
    offset: const Offset(0, 4),
  ),
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.03),
    blurRadius: 6,
    offset: const Offset(0, 1),
  ),
];

/// Rose gradient with a rounded bottom edge — the "wave" header
/// at the top of every screen.
const BoxDecoration kHeaderGradient = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [C.g1, C.g2],
  ),
  borderRadius: BorderRadius.only(
    bottomLeft: Radius.circular(32),
    bottomRight: Radius.circular(32),
  ),
);

/// Transparent status bar with WHITE icons, because every screen starts
/// with a dark gradient header behind the clock/battery icons.
const SystemUiOverlayStyle kLightStatusBar = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light, // Android
  statusBarBrightness: Brightness.dark, // iOS (describes the background)
  systemNavigationBarColor: C.navBg,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// Risk colors and symbols live here (not in the model) because they are
/// a UI concern. Usage: `entry.result.riskLevel.color`.
extension RiskStyle on RiskLevel {
  Color get color => switch (this) {
        RiskLevel.low => C.low,
        RiskLevel.mid => C.mid,
        RiskLevel.high => C.high,
      };

  Color get bg => switch (this) {
        RiskLevel.low => C.lowBg,
        RiskLevel.mid => C.midBg,
        RiskLevel.high => C.highBg,
      };

  Color get border => switch (this) {
        RiskLevel.low => C.lowBdr,
        RiskLevel.mid => C.midBdr,
        RiskLevel.high => C.highBdr,
      };

  /// Symbol shown inside risk circles (shape + color, so it still reads
  /// for color-blind users).
  String get emoji => switch (this) {
        RiskLevel.low => '✓',
        RiskLevel.mid => '●',
        RiskLevel.high => '⚠',
      };

  /// Short label for pills and badges.
  String get short => switch (this) {
        RiskLevel.low => 'LOW',
        RiskLevel.mid => 'MID',
        RiskLevel.high => 'HIGH',
      };
}

// ═════════════════════════════════════════════════════════════════════════════
// SESSION STORAGE (memory only)
// ═════════════════════════════════════════════════════════════════════════════

/// Holds this session's assessments in a plain static list.
///
/// Nothing is written to disk, so all data disappears when the app closes.
/// That is deliberate: the prototype must never persist patient data.
class SessionManager {
  SessionManager._();

  static final List<SessionEntry> _sessions = [];

  /// Bumped every time the list changes. Screens that sit in the bottom-nav
  /// IndexedStack (Home, History) stay alive in the background and would
  /// otherwise show stale data; they listen to this to know when to rebuild.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void add(SessionEntry e) {
    _sessions.add(e);
    changes.value++;
  }

  static List<SessionEntry> get all => List.unmodifiable(_sessions);
  static int get count => _sessions.length;

  static void clear() {
    _sessions.clear();
    changes.value++;
  }
}

/// One saved assessment: the inputs, the result, and when it happened.
class SessionEntry {
  final String caseLabel;
  final AssessmentResult result;
  final DateTime time;
  final double age, systolic, diastolic, bloodSugar, temp, heartRate;

  const SessionEntry({
    required this.caseLabel,
    required this.result,
    required this.time,
    required this.age,
    required this.systolic,
    required this.diastolic,
    required this.bloodSugar,
    required this.temp,
    required this.heartRate,
  });

  /// 12-hour clock label, e.g. "3:07 PM".
  String get timeLabel {
    final h = time.hour > 12
        ? time.hour - 12
        : time.hour == 0
            ? 12
            : time.hour;
    final m = time.minute.toString().padLeft(2, '0');
    final a = time.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $a';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RESPONSIVE LAYOUT
//
// One codebase, three layouts:
//   • Mobile  (< 600px)   → the original phone design, bottom nav bar.
//   • Tablet  (600–899px) → same bottom nav, wider gutters, 2-column grids.
//   • Desktop (≥ 900px)   → dark side navigation, centered content,
//                           2–3 column grids.
// Colors, cards and headers are identical everywhere — only the
// arrangement changes.
// ═════════════════════════════════════════════════════════════════════════════

/// Wrap every Scaffold in this.
///
/// It applies the light status-bar style (white icons over the rose
/// header) and holds the breakpoints + helpers that every screen uses to
/// decide how to lay itself out.
class Rsp extends StatelessWidget {
  final Widget child;
  const Rsp({super.key, required this.child});

  /// Window widths where the layout changes.
  static const double tablet = 600;
  static const double desktop = 1024;

  /// From this window width the bottom bar becomes a side navigation.
  static const double sideNav = 900;

  /// Content never grows wider than this, so lines of text and cards stay
  /// readable on big monitors.
  static const double maxContent = 1180;

  /// Space between the content and the screen edge.
  static double gutterFor(double width) => width >= desktop
      ? 40
      : width >= tablet
          ? 32
          : 20;

  /// How many grid columns fit in [width] if every item needs at least
  /// [minItem] pixels. Always between 1 and [max].
  static int columnsFor(double width, {double minItem = 340, int max = 3}) =>
      (width / minItem).floor().clamp(1, max);

  /// True on phones (narrow windows).
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tablet;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kLightStatusBar,
      child: child,
    );
  }
}

/// Centers page content, caps it at [maxWidth], and adds side gutters.
///
/// The [builder] receives the final content width so a screen can pick
/// 1, 2 or 3 columns. LayoutBuilder is used (not the window size) because
/// on desktop the side navigation takes part of the window.
class RspContent extends StatelessWidget {
  final double maxWidth;
  final Widget Function(BuildContext context, double width) builder;

  const RspContent({
    super.key,
    this.maxWidth = Rsp.maxContent,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = Rsp.gutterFor(constraints.maxWidth);
        final width = math.min(constraints.maxWidth - gutter * 2, maxWidth);
        return Center(
          child: SizedBox(width: width, child: builder(context, width)),
        );
      },
    );
  }
}

/// Lays [children] out in rows of [columns].
///
/// With one column it is a plain Column (the mobile look). With more,
/// IntrinsicHeight makes every card in a row the same height so the grid
/// lines up neatly. Vertical spacing comes from each card's own bottom
/// margin, so cards look the same in both modes.
class RspGrid extends StatelessWidget {
  final int columns;
  final List<Widget> children;
  final double gap;

  const RspGrid({
    super.key,
    required this.columns,
    required this.children,
    this.gap = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return Column(
      children: [
        for (var start = 0; start < children.length; start += columns)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(
                    // Empty slot keeps the last row's cards the same width.
                    child: start + i < children.length
                        ? children[start + i]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// APP
// ═════════════════════════════════════════════════════════════════════════════

/// Root widget: theme + the home route ('/').
class MaternAIApp extends StatelessWidget {
  const MaternAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return MaterialApp(
      title: 'Aiovy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: C.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: C.g2,
          primary: C.g2,
          surface: C.card,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: C.t1,
            letterSpacing: -1.0,
            height: 1.1,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: C.t1,
            letterSpacing: -0.4,
          ),
          titleLarge: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: C.t1,
          ),
          bodyMedium: TextStyle(fontSize: 14, color: C.t2, height: 1.5),
          labelSmall: TextStyle(fontSize: 12, color: C.t3),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: C.g2,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: buttonShape,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: C.g2,
            side: const BorderSide(color: C.g2, width: 1.5),
            shape: buttonShape,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: C.t1,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      // `home` is the '/' route, so ResultScreen's
      // pushNamedAndRemoveUntil('/') lands back here.
      home: const MainShell(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN SHELL — bottom navigation
// ═════════════════════════════════════════════════════════════════════════════

/// Holds the three tabs and the dark bottom bar.
///
/// IndexedStack keeps all three tabs alive, so switching tabs keeps
/// each tab's scroll position.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  void _selectTab(int index) {
    if (index == _tab) return;
    HapticFeedback.lightImpact();
    setState(() => _tab = index);
  }

  /// The "+" button opens the assessment flow ON TOP of the shell
  /// instead of switching tabs.
  void _startAssessment() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DangerCheckScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final tabs = IndexedStack(
      index: _tab,
      children: const [
        HomeScreen(),
        HistoryScreen(),
        ModelInfoScreen(),
      ],
    );

    // ── Desktop / large tablet: side navigation on the left ──
    if (width >= Rsp.sideNav) {
      return Rsp(
        child: Scaffold(
          body: Row(
            children: [
              _SideNav(
                current: _tab,
                onSelect: _selectTab,
                onAdd: _startAssessment,
                // Labels next to icons only when there is room for them.
                expanded: width >= 1180,
              ),
              Expanded(child: tabs),
            ],
          ),
        ),
      );
    }

    // ── Phone / small tablet: bottom bar with the raised "+" ──
    return Rsp(
      child: Scaffold(
        // Let tab content scroll *behind* the rounded nav bar. Flutter
        // then reports the bar's height as bottom padding to each tab,
        // which they use to keep their last item visible.
        extendBody: true,
        body: tabs,
        bottomNavigationBar: _BottomNav(
          current: _tab,
          onSelect: _selectTab,
          onAdd: _startAssessment,
        ),
      ),
    );
  }
}

/// Desktop navigation: the bottom bar's dark style turned sideways.
///
/// [expanded] shows text labels (wide windows); otherwise it is a slim
/// icon-only rail with tooltips.
class _SideNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final bool expanded;

  const _SideNav({
    required this.current,
    required this.onSelect,
    required this.onAdd,
    required this.expanded,
  });

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.format_list_bulleted, 'History'),
    (Icons.info_outline_rounded, 'About Model'),
  ];

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: expanded ? 248 : 92,
      padding: EdgeInsets.fromLTRB(16, top + 28, 16, 24),
      decoration: const BoxDecoration(
        color: C.navBg,
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment:
            expanded ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
        children: [
          // ── Logo ──
          Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [C.g1, C.g2],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '+',
                  style: TextStyle(
                    color: C.onDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              if (expanded) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aiovy',
                        style: TextStyle(
                          color: C.onDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Maternal Risk Assessment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: C.navIcon, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),

          // ── "New Assessment" (the bottom bar's "+" button) ──
          ClickArea(
            onTap: onAdd,
            tooltip: expanded ? null : 'New Assessment',
            child: Container(
              width: expanded ? null : 52,
              height: expanded ? 48 : 52,
              decoration: BoxDecoration(
                color: C.g2,
                borderRadius: BorderRadius.circular(expanded ? 14 : 26),
                boxShadow: [
                  BoxShadow(
                    color: C.g2.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 24),
                  if (expanded) ...[
                    const SizedBox(width: 8),
                    // Flexible + ellipsis: never overflows, even while the
                    // nav is animating between its slim and wide widths.
                    const Flexible(
                      child: Text(
                        'New Assessment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Tabs ──
          for (var i = 0; i < _items.length; i++)
            _SideNavItem(
              icon: _items[i].$1,
              label: _items[i].$2,
              active: i == current,
              expanded: expanded,
              onTap: () => onSelect(i),
            ),

          const Spacer(),

          // ── Privacy reminder ──
          if (expanded)
            const Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: C.navIcon),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Session only · no data stored',
                    style: TextStyle(fontSize: 11, color: C.navIcon),
                  ),
                ),
              ],
            )
          else
            const Tooltip(
              message: 'Session only · no data stored',
              child: Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: C.navIcon,
              ),
            ),
        ],
      ),
    );
  }
}

/// One side-navigation entry. The active tab gets a soft white pill.
class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? C.onDark : C.navIcon;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClickArea(
        onTap: onTap,
        tooltip: expanded ? null : label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: expanded ? null : 56,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              if (expanded) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tap target that also shows the hand cursor on web/desktop and an
/// optional hover tooltip.
class ClickArea extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? tooltip;

  const ClickArea({
    super.key,
    required this.child,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget result = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
    if (tooltip != null) {
      result = Tooltip(message: tooltip!, child: result);
    }
    return result;
  }
}

/// Dark, icon-only bottom bar with a raised "+" button above its center.
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  const _BottomNav({
    required this.current,
    required this.onSelect,
    required this.onAdd,
  });

  static const double _fabSize = 52;

  // How far the "+" button rises above the top edge of the bar.
  static const double _fabLift = 40;

  static const _icons = [
    Icons.home_rounded,
    Icons.format_list_bulleted,
    Icons.info_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // The widget is taller than the visible bar: the extra transparent
    // strip on top holds the "+" button. Keeping the button INSIDE this
    // widget's bounds matters — Flutter ignores taps on anything drawn
    // outside its parent.
    return SizedBox(
      height: _fabLift + 12 + 44 + 12 + safeBottom,
      child: Stack(
        children: [
          // The dark bar itself.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + safeBottom),
              decoration: const BoxDecoration(
                color: C.navBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < _icons.length; i++)
                    _NavIcon(
                      icon: _icons[i],
                      active: i == current,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
          ),

          // Floating "+" button, centered above the bar.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                button: true,
                label: 'New assessment',
                child: ClickArea(
                  onTap: onAdd,
                  child: Container(
                    width: _fabSize,
                    height: _fabSize,
                    decoration: BoxDecoration(
                      color: C.g2,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: C.g2.withValues(alpha: 0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One bottom-bar icon with a small dot under it when active.
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ClickArea uses an "opaque" hit test, so the whole 56x44 box is
    // tappable, not just the glyph.
    return ClickArea(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: active ? C.onDark : C.navIcon),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 4 : 0,
              height: 4,
              decoration: const BoxDecoration(
                color: C.onDark,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED UI PIECES (used by several screens)
// ═════════════════════════════════════════════════════════════════════════════

/// The rose gradient header used at the top of every screen.
///
/// It handles the status-bar inset for you (the top padding includes
/// MediaQuery.padding.top) and draws a faint ECG line behind the content.
class GradientHeader extends StatelessWidget {
  final Widget child;
  final double topPadding;
  final double bottomPadding;

  /// Should match the page's RspContent maxWidth so the header text
  /// lines up with the cards below it on wide screens.
  final double maxWidth;

  const GradientHeader({
    super.key,
    required this.child,
    this.topPadding = 20,
    this.bottomPadding = 28,
    this.maxWidth = Rsp.maxContent,
  });

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      // Clip so the decorative drawing respects the rounded bottom corners.
      clipBehavior: Clip.antiAlias,
      decoration: kHeaderGradient,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _EcgPainter())),
          LayoutBuilder(
            builder: (context, constraints) {
              // Phones keep the original 24px header padding; wider
              // screens use the same gutter as the page content.
              final w = constraints.maxWidth;
              final side = w < Rsp.tablet ? 24.0 : Rsp.gutterFor(w);
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  side,
                  statusBar + topPadding,
                  side,
                  bottomPadding,
                ),
                // Center the header content and cap its width, the same
                // way RspContent does for the page body.
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: SizedBox(width: double.infinity, child: child),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Purely decorative: a heartbeat (ECG) line plus two soft circles,
/// drawn in white at very low opacity behind the header text.
class _EcgPainter extends CustomPainter {
  const _EcgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..color = Colors.white.withValues(alpha: 0.05);
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.05),
      size.width * 0.34,
      glow,
    );
    canvas.drawCircle(
      Offset(size.width * 0.02, size.height * 1.05),
      size.width * 0.22,
      glow,
    );

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // One heartbeat is ~140px wide; repeat it across the header.
    // The offsets trace a P wave, the tall QRS spike and a T wave.
    final y = size.height * 0.62;
    const beat = 140.0;
    final path = Path()..moveTo(0, y);
    for (double x = 0; x < size.width; x += beat) {
      path
        ..lineTo(x + 40, y)
        ..lineTo(x + 48, y - 7) // P
        ..lineTo(x + 56, y)
        ..lineTo(x + 66, y)
        ..lineTo(x + 71, y + 9) // Q
        ..lineTo(x + 79, y - 36) // R
        ..lineTo(x + 87, y + 16) // S
        ..lineTo(x + 94, y)
        ..lineTo(x + 108, y - 10) // T
        ..lineTo(x + 120, y)
        ..lineTo(x + beat, y);
    }
    canvas.drawPath(path, line);
  }

  // The drawing never changes, so never repaint it.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// White "‹ Label" back link used inside gradient headers.
class HeaderBackButton extends StatelessWidget {
  final String label;

  /// Optional custom action; defaults to popping the current screen.
  final VoidCallback? onTap;

  const HeaderBackButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back to $label',
      child: ClickArea(
        onTap: () {
          HapticFeedback.lightImpact();
          if (onTap != null) {
            onTap!();
          } else {
            Navigator.of(context).maybePop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4, right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chevron_left_rounded,
                color: C.onDark,
                size: 26,
              ),
              Text(
                label,
                style: const TextStyle(
                  color: C.onDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted pill used on gradient headers (stats, tags, share button).
class HeaderChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? leading;

  const HeaderChip({super.key, required this.label, this.icon, this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          if (icon != null) ...[
            Icon(icon, size: 14, color: C.onDark),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              color: C.onDark,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small colored "LOW / MID / HIGH" badge.
class RiskPill extends StatelessWidget {
  final RiskLevel level;
  const RiskPill({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: level.bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        level.short,
        style: TextStyle(
          color: level.color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Filled circle with the risk symbol (✓ / ● / ⚠) inside.
class RiskAvatar extends StatelessWidget {
  final RiskLevel level;
  final double size;
  final double fontSize;
  final bool showBorder;

  const RiskAvatar({
    super.key,
    required this.level,
    this.size = 44,
    this.fontSize = 20,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: level.bg,
        shape: BoxShape.circle,
        border: showBorder ? Border.all(color: level.border, width: 3) : null,
      ),
      child: Text(
        level.emoji,
        style: TextStyle(
          color: level.color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// A white, shadowed card that shows a ripple when tapped.
///
/// The shadow sits on an outer DecoratedBox, while the ripple needs a
/// Material + InkWell inside — that layering is what makes the ripple
/// respect the rounded corners.
class TapCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const TapCard({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 20,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: shape, boxShadow: kCardShadow),
        child: Material(
          color: C.card,
          borderRadius: shape,
          child: InkWell(
            borderRadius: shape,
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Plain white content card (no tap) — used for info sections.
class SectionCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.child,
    this.radius = 18,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: kCardShadow,
      ),
      child: child,
    );
  }
}

/// Friendly placeholder shown when there are no assessments yet.
class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const EmptyState({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: C.g2.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: C.g2,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: C.t2),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import 'danger_check_screen.dart';
import 'result_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 1: HOME / DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

/// The first tab: greeting header, quick stats, a "New Assessment" shortcut
/// and the five most recent assessments.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _startAssessment(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DangerCheckScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Includes the bottom nav bar's height (see MainShell.extendBody),
    // so the last tile never hides behind the bar.
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Rsp(
      child: Scaffold(
        backgroundColor: C.bg,
        // Rebuild whenever an assessment is added. This tab stays alive in
        // the background, so it would otherwise keep showing old numbers.
        body: ValueListenableBuilder<int>(
          valueListenable: SessionManager.changes,
          builder: (context, version, child) {
            final sessions = SessionManager.all;
            final recent = sessions.reversed.take(5).toList();
            final last = sessions.isEmpty ? null : sessions.last;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _HomeHeader(count: sessions.length)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 20, bottom: bottomInset + 24),
                    // RspContent centers the page and tells us how wide it
                    // is, so we can choose the phone or wide arrangement.
                    child: RspContent(
                      builder: (context, width) {
                        final statOne = _StatCard(
                          title: 'Assessed Today',
                          value: '${sessions.length}',
                          unit: 'cases',
                          icon: Icons.person_outline,
                          color: C.g2,
                        );
                        final statTwo = _StatCard(
                          title: 'Last Result',
                          value: last?.result.riskLevel.short ?? '—',
                          unit: 'risk',
                          icon: Icons.monitor_heart,
                          color: last?.result.riskLevel.color ?? C.t3,
                        );
                        final startCard = _StartAssessmentCard(
                          onTap: () => _startAssessment(context),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (width >= 760)
                              // Wide: both stat cards and the start card in
                              // one row, all the same height.
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: statOne),
                                    const SizedBox(width: 14),
                                    Expanded(child: statTwo),
                                    const SizedBox(width: 14),
                                    Expanded(flex: 2, child: startCard),
                                  ],
                                ),
                              )
                            else ...[
                              // Phone: two stat cards, start card below.
                              Row(
                                children: [
                                  Expanded(child: statOne),
                                  const SizedBox(width: 12),
                                  Expanded(child: statTwo),
                                ],
                              ),
                              const SizedBox(height: 14),
                              startCard,
                            ],
                            const SizedBox(height: 28),

                            // ── "Recent" heading ──
                            Row(
                              children: [
                                const Text(
                                  'Recent',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: C.t1,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${sessions.length} today',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: C.g2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (recent.isEmpty)
                              const EmptyState(
                                title: 'No assessments yet',
                                subtitle: 'Tap + to start',
                              )
                            else
                              // 1 column on phones, up to 3 on desktop.
                              RspGrid(
                                columns: Rsp.columnsFor(width),
                                children: [
                                  for (final e in recent) SessionTile(entry: e),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Gradient header: logo row, headline, and stat chips.
class _HomeHeader extends StatelessWidget {
  final int count;
  const _HomeHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return GradientHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo + app name + bell ──
          Row(
            children: [
              const _HeaderCircle(
                child: Text(
                  '+',
                  style: TextStyle(
                    color: C.onDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Expanded (instead of a Spacer) lets the subtitle shrink
              // with "…" on very narrow screens rather than overflow.
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
                      style: TextStyle(color: C.onDarkSub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const _HeaderCircle(
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: C.onDark,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Headline ──
          Text(
            'Maternal risk,\ndetected early.',
            style: TextStyle(
              color: C.onDark,
              // A little larger on desktop, where there is more room.
              fontSize:
                  MediaQuery.sizeOf(context).width >= Rsp.desktop ? 38 : 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Explainable AI for OB-GYNs and Midwives.',
            style: TextStyle(color: C.onDarkSub, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // ── Stat chips (scroll sideways on narrow phones) ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                HeaderChip(
                  icon: Icons.people_alt_outlined,
                  label: '$count assessed today',
                ),
                const SizedBox(width: 8),
                const HeaderChip(
                  icon: Icons.memory_rounded,
                  label: 'XGBoost model',
                ),
                const SizedBox(width: 8),
                const HeaderChip(
                  icon: Icons.insights_rounded,
                  label: 'SHAP enabled',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 38x38 frosted circle used for the logo and bell.
class _HeaderCircle extends StatelessWidget {
  final Widget child;
  const _HeaderCircle({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

/// Small dashboard card: icon, title, and a big number with a unit.
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: C.t2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          // One rich text keeps the small unit on the same baseline as the
          // big number; FittedBox shrinks both on very narrow phones
          // instead of overflowing.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -0.8,
                    ),
                  ),
                  TextSpan(
                    text: '  $unit',
                    style: const TextStyle(fontSize: 13, color: C.t3),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Big tappable "New Assessment" call-to-action.
class _StartAssessmentCard extends StatelessWidget {
  final VoidCallback onTap;
  const _StartAssessmentCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapCard(
      onTap: onTap,
      radius: 20,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: C.g2.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_circle_outline, color: C.g2),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              // min: keeps the text vertically centered when the card is
              // stretched to match the stat cards on wide screens.
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Assessment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Assess a patient's maternal risk level.",
                  style: TextStyle(fontSize: 13, color: C.t2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: C.g2,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in the "Recent" list. Tapping re-opens that result.
class SessionTile extends StatelessWidget {
  final SessionEntry entry;
  const SessionTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final level = entry.result.riskLevel;
    return TapCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => openSessionResult(context, entry),
      child: Row(
        children: [
          RiskAvatar(level: level, size: 44, fontSize: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.caseLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Age ${entry.age.round()} · '
                  'BP ${entry.systolic.round()}/${entry.diastolic.round()}',
                  style: const TextStyle(fontSize: 12, color: C.t2),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.timeLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: C.t2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              RiskPill(level: level),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens a saved result (from Home or History). Shared so both lists
/// behave the same way.
void openSessionResult(BuildContext context, SessionEntry entry) {
  HapticFeedback.lightImpact();
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ResultScreen(
        result: entry.result,
        entry: entry,
        fromHistory: true,
      ),
    ),
  );
}


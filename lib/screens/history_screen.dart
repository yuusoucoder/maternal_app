import 'package:flutter/material.dart';

import '../main.dart';
import '../models/assessment_model.dart';
import 'home_screen.dart' show openSessionResult;

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 5: HISTORY
//
// Every assessment from this session, newest first. Data lives only in
// memory (SessionManager) and is gone when the app closes.
// ─────────────────────────────────────────────────────────────────────────────

/// Second tab: full session history with LOW / MID / HIGH counts.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Rsp(
      child: Scaffold(
        backgroundColor: C.bg,
        // Rebuild when a new assessment is saved (this tab stays alive in
        // the background inside MainShell's IndexedStack).
        body: ValueListenableBuilder<int>(
          valueListenable: SessionManager.changes,
          builder: (context, version, child) {
            final sessions = SessionManager.all.reversed.toList();

            // How many of each class, for the header chips.
            int countOf(RiskLevel l) =>
                sessions.where((e) => e.result.riskLevel == l).length;

            return Column(
              children: [
                GradientHeader(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Session History',
                        style: TextStyle(
                          color: C.onDark,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sessions.isEmpty
                            ? 'No assessments yet'
                            : '${sessions.length} '
                                '${sessions.length == 1 ? 'assessment' : 'assessments'} '
                                'today',
                        style: const TextStyle(
                          color: C.onDarkSub,
                          fontSize: 14,
                        ),
                      ),
                      if (sessions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final l in RiskLevel.values)
                              HeaderChip(
                                // Small colored dot so the chips are
                                // distinguishable at a glance.
                                leading: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: l.border,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                label: '${countOf(l)} ${l.short}',
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: sessions.isEmpty
                      ? _EmptyHistory(bottomInset: bottomInset)
                      : ListView(
                          padding: EdgeInsets.only(
                            top: 20,
                            bottom: bottomInset + 24,
                          ),
                          children: [
                            // 1 column on phones, 2–3 on wider screens.
                            RspContent(
                              builder: (context, width) => RspGrid(
                                columns: Rsp.columnsFor(width),
                                children: [
                                  for (final e in sessions)
                                    HistoryCard(entry: e),
                                ],
                              ),
                            ),
                          ],
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

/// Centered placeholder when nothing has been assessed yet.
class _EmptyHistory extends StatelessWidget {
  final double bottomInset;
  const _EmptyHistory({required this.bottomInset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, bottomInset),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: C.g2.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 34,
                color: C.g2,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No assessments yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: C.t1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap + above to start your first assessment',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: C.t2),
            ),
          ],
        ),
      ),
    );
  }
}

/// One past assessment. Tap to reopen its full result.
class HistoryCard extends StatelessWidget {
  final SessionEntry entry;
  const HistoryCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final level = entry.result.riskLevel;
    return TapCard(
      radius: 18,
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => openSessionResult(context, entry),
      child: Row(
        children: [
          RiskAvatar(level: level, size: 48, fontSize: 21),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.caseLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'BP ${entry.systolic.round()}/${entry.diastolic.round()} · '
                  'BS ${entry.bloodSugar.toStringAsFixed(1)} · '
                  '${entry.age.round()}yr',
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

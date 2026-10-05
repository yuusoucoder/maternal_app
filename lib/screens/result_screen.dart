import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/assessment_model.dart';
import 'danger_check_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 4: RESULT
//
// Shows the predicted class, how confident the model is, WHY it decided
// that (SHAP-style bars), and what to do next.
// ─────────────────────────────────────────────────────────────────────────────

/// Full result for one assessment.
class ResultScreen extends StatelessWidget {
  /// Value this screen pops with when "Assess Another Patient" is tapped,
  /// so the vitals screen knows to reset its sliders.
  static const String assessAnother = 'assess_another';

  final AssessmentResult result;
  final SessionEntry entry;

  /// True when opened from Home/History (there is no vitals form
  /// underneath to go back and edit).
  final bool fromHistory;

  const ResultScreen({
    super.key,
    required this.result,
    required this.entry,
    this.fromHistory = false,
  });

  static String _signed(double v) =>
      '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}';

  /// Plain-text summary for pasting into notes or a referral message.
  String _buildSummary() {
    final drivers = result.features
        .take(3)
        .map((f) =>
            '${f.featureName} (${f.displayValue}, ${_signed(f.contribution)})')
        .join(', ');

    return 'Aiovy Assessment Summary\n'
        '${entry.caseLabel}\n'
        '${entry.timeLabel}\n'
        'RISK: ${result.riskLabel}\n'
        'Vitals: Age ${entry.age.round()} yrs · '
        'BP ${entry.systolic.round()}/${entry.diastolic.round()} mmHg · '
        'Blood sugar ${entry.bloodSugar.toStringAsFixed(1)} mmol/L · '
        'Temp ${entry.temp.toStringAsFixed(1)} °F · '
        'HR ${entry.heartRate.round()} bpm\n'
        'Key drivers: $drivers\n'
        'Recommendation: ${result.recommendation}\n'
        '---\n'
        'Aiovy · LPU Cavite CS Thesis\n'
        'This tool supports — not replaces — clinical judgment.';
  }

  Future<void> _copySummary(BuildContext context) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: _buildSummary()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Summary copied to clipboard'),
          // Don't stretch the toast across a desktop monitor.
          width: Rsp.isMobile(context) ? null : 420,
        ),
      );
  }

  void _assessAnother(BuildContext context) {
    HapticFeedback.lightImpact();
    final nav = Navigator.of(context);
    if (fromHistory) {
      // Opened from a list: go back to the shell, then start a fresh
      // flow (danger check first, as for every new patient).
      nav.popUntil((route) => route.isFirst);
      nav.push(MaterialPageRoute(builder: (_) => const DangerCheckScreen()));
    } else {
      nav.pop(assessAnother);
    }
  }

  void _backHome(BuildContext context) {
    HapticFeedback.lightImpact();
    // Clears every screen and rebuilds the shell at '/'.
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  /// Content width cap for this screen (two comfortable columns).
  static const double _maxWidth = 1080;

  /// Phone: one column, in reading order.
  /// Wide (≥ 820px): confidence, recommendation and actions on the left;
  /// the contributing-factors chart on the right, side by side.
  Widget _buildContent(BuildContext context, double width) {
    final wide = width >= 820;

    final assessAnotherButton = SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => _assessAnother(context),
        icon: const Icon(Icons.refresh_rounded, size: 20),
        label: const Text(
          'Assess Another Patient',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
    final homeButton = SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () => _backHome(context),
        icon: const Icon(Icons.home_rounded, size: 20),
        label: const Text(
          'Back to Home',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProbabilityCard(result: result),
          const SizedBox(height: 14),
          _ShapCard(result: result),
          const SizedBox(height: 14),
          _RecommendationCard(result: result),
          const SizedBox(height: 14),
          const _Disclaimer(),
          const SizedBox(height: 20),
          assessAnotherButton,
          const SizedBox(height: 10),
          homeButton,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProbabilityCard(result: result),
              const SizedBox(height: 14),
              _RecommendationCard(result: result),
              const SizedBox(height: 14),
              const _Disclaimer(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: assessAnotherButton),
                  const SizedBox(width: 12),
                  Expanded(child: homeButton),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(child: _ShapCard(result: result)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = result.riskLevel;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Rsp(
      child: Scaffold(
        backgroundColor: C.bg,
        body: Column(
          children: [
            // ── Header ──
            GradientHeader(
              topPadding: 8,
              bottomPadding: 24,
              maxWidth: _maxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeaderBackButton(label: fromHistory ? 'Back' : 'Edit'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      RiskAvatar(
                        level: level,
                        size: 64,
                        fontSize: 26,
                        showBorder: true,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.riskLabel,
                              style: TextStyle(
                                // Light version of the risk color reads
                                // better on the dark gradient.
                                color: level.bg,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${entry.caseLabel} · ${entry.timeLabel}',
                              style: const TextStyle(
                                color: C.onDarkSub,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    button: true,
                    child: ClickArea(
                      onTap: () => _copySummary(context),
                      child: const HeaderChip(
                        icon: Icons.copy_outlined,
                        label: 'Copy Summary',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(top: 20, bottom: bottomInset + 24),
                children: [
                  RspContent(
                    maxWidth: _maxWidth,
                    builder: (context, width) => _buildContent(context, width),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card title + subtitle used by every card on this screen.
class _CardTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _CardTitle(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: C.t1,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: C.t3)),
        ],
      ],
    );
  }
}

/// "Model Confidence": one bar per class (LOW / MID / HIGH).
class _ProbabilityCard extends StatelessWidget {
  final AssessmentResult result;
  const _ProbabilityCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final probs = result.probabilities;
    final selected = result.riskLevel;
    final selectedPct = (probs[selected.short]! * 100).round();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            'Model Confidence',
            'Probability across all risk classes.',
          ),
          const SizedBox(height: 16),
          for (final level in RiskLevel.values)
            _ProbabilityBar(
              level: level,
              value: probs[level.short]!,
              selected: level == selected,
            ),
          const SizedBox(height: 2),
          Text(
            'Selected: ${result.riskLabel} ($selectedPct% confidence)',
            style: const TextStyle(
              fontSize: 11,
              color: C.t3,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label · bar · percentage for one class.
class _ProbabilityBar extends StatelessWidget {
  final RiskLevel level;
  final double value; // 0.0 – 1.0
  final bool selected;

  const _ProbabilityBar({
    required this.level,
    required this.value,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      color: selected ? level.color : C.t2,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(level.short, style: textStyle)),
          Expanded(child: _Bar(fraction: value, color: level.color, height: 10)),
          SizedBox(
            width: 38,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded horizontal bar: a gray track with a colored fill.
/// [fraction] is how much of the width to fill (0.0 – 1.0).
class _Bar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;

  const _Bar({
    required this.fraction,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      // width: infinity makes the track always span the full row, so the
      // fill grows from the left edge instead of being centered.
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: C.track)),
            // FractionallySizedBox sizes the fill as a share of the track.
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Contributing Factors": SHAP-style ranking of the six vitals.
class _ShapCard extends StatelessWidget {
  final AssessmentResult result;
  const _ShapCard({required this.result});

  /// Color scale for a contribution: the stronger the push toward HIGH,
  /// the "hotter" the color. Negative values (protective) are green.
  static Color _shapColor(double c) {
    if (c > 0.5) return C.high;
    if (c > 0.2) return C.mid;
    if (c > 0) return C.g2;
    return C.low;
  }

  @override
  Widget build(BuildContext context) {
    // Bars are scaled relative to the biggest contribution, so the top
    // factor always fills the full width.
    final maxAbs = result.features
        .map((f) => f.contribution.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            'Contributing Factors',
            'Vital signs ranked by influence. Red = pushes toward HIGH.',
          ),
          const SizedBox(height: 16),
          for (final f in result.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.featureName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: C.t1,
                          ),
                        ),
                      ),
                      Text(
                        f.displayValue,
                        style: const TextStyle(fontSize: 11, color: C.t2),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _shapColor(f.contribution)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          ResultScreen._signed(f.contribution),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _shapColor(f.contribution),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _Bar(
                    fraction: maxAbs == 0 ? 0 : f.contribution.abs() / maxAbs,
                    color: _shapColor(f.contribution),
                    height: 6,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Recommended Action" box tinted in the risk color.
class _RecommendationCard extends StatelessWidget {
  final AssessmentResult result;
  const _RecommendationCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final level = result.riskLevel;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Recommended Action', ''),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: level.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: level.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(result.riskIcon, size: 18, color: level.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.recommendation,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: C.t1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Required clinical disclaimer.
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      radius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: C.t2),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This tool supports — not replaces — clinical judgment. '
              'Source: DOH Maternal Care Protocol 2020 & WHO ANC '
              'Guidelines 2016.',
              style: TextStyle(
                fontSize: 12,
                color: C.t2,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 6: MODEL INFO
//
// Transparency page for evaluators: what data the model learned from,
// how it compares to alternatives, how to read SHAP, and its limits.
// ─────────────────────────────────────────────────────────────────────────────

/// Third tab: "About This Model".
class ModelInfoScreen extends StatelessWidget {
  const ModelInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Rsp(
      child: Scaffold(
        backgroundColor: C.bg,
        body: Column(
          children: [
            const GradientHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About This Model',
                    style: TextStyle(
                      color: C.onDark,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Dataset, models, and explainability.',
                    style: TextStyle(color: C.onDarkSub, fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(top: 20, bottom: bottomInset + 24),
                children: [
                  RspContent(
                    builder: (context, width) {
                      // Phone: one column in the original order.
                      if (width < 820) {
                        return const Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DatasetCard(),
                            SizedBox(height: 14),
                            _FeaturesCard(),
                            SizedBox(height: 14),
                            _ComparisonCard(),
                            SizedBox(height: 14),
                            _ShapGuideCard(),
                            SizedBox(height: 14),
                            _LimitationsCard(),
                          ],
                        );
                      }
                      // Wide: two independent columns (data on the left,
                      // models and explainability on the right), so
                      // cards of different heights don't leave gaps.
                      return const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _DatasetCard(),
                                SizedBox(height: 14),
                                _FeaturesCard(),
                                SizedBox(height: 14),
                                _LimitationsCard(),
                              ],
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _ComparisonCard(),
                                SizedBox(height: 14),
                                _ShapGuideCard(),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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

// ── Building blocks ─────────────────────────────────────────────────────────

/// White card with an icon + title row, then any content below.
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: C.g2.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: C.g2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// "Key   value" row with a fixed-width key column so values line up.
class _KeyValue extends StatelessWidget {
  final String k;
  final String v;
  const _KeyValue(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 13,
                color: C.t3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 13,
                color: C.t1,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small italic gray note.
class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: C.t3,
        fontStyle: FontStyle.italic,
        height: 1.5,
      ),
    );
  }
}

// ── Cards ───────────────────────────────────────────────────────────────────

class _DatasetCard extends StatelessWidget {
  const _DatasetCard();

  @override
  Widget build(BuildContext context) {
    return const _InfoCard(
      icon: Icons.dataset_outlined,
      title: 'Training Dataset',
      children: [
        _KeyValue('Name', 'UCI Maternal Health Risk Dataset'),
        _KeyValue('Records', '1,014 records'),
        _KeyValue('Origin', 'Rural clinics, Bangladesh (Ahmed, 2020)'),
        _KeyValue('License', 'CC BY 4.0'),
        _KeyValue('Privacy', 'No real Philippine patient data collected'),
        SizedBox(height: 4),
        _Note(
          'Dataset from a low-resource setting comparable to underserved '
          'Philippine communities. Limitation acknowledged — local data '
          'collection recommended as future work.',
        ),
      ],
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();

  static const _features = [
    'Age (years)',
    'Systolic BP (mmHg)',
    'Diastolic BP (mmHg)',
    'Blood Sugar (mmol/L)',
    'Body Temperature (°F)',
    'Heart Rate (bpm)',
  ];

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.tune_rounded,
      title: 'Input Features',
      children: [
        // Wrap flows the chips onto new lines as needed.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _features)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: C.g2.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  f,
                  style: const TextStyle(
                    fontSize: 12,
                    color: C.g2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard();

  @override
  Widget build(BuildContext context) {
    return const _InfoCard(
      icon: Icons.compare_arrows_rounded,
      title: 'Model Comparison',
      children: [
        _Note('(Replace values with actual Python training results)'),
        SizedBox(height: 12),
        _TableRow(
          cells: ['Model', 'Accuracy', 'Recall (High)', 'F1'],
          isHeader: true,
        ),
        _TableRow(cells: ['Logistic Regression', '72.4%', '65.3%', '69.8%']),
        _TableRow(cells: ['Random Forest', '84.6%', '79.2%', '83.1%']),
        _TableRow(
          cells: ['XGBoost ✓', '87.3%', '83.7%', '86.1%'],
          highlight: true,
        ),
        SizedBox(height: 12),
        Text(
          'XGBoost selected — highest F1 and high-risk Recall. SMOTE '
          'applied. Repeated k-fold CV used. McNemar\'s test confirmed '
          'statistical significance.',
          style: TextStyle(fontSize: 12, color: C.t2, height: 1.5),
        ),
        SizedBox(height: 6),
        _Note('* Replace with actual results from Python training.'),
      ],
    );
  }
}

/// One row of the comparison table. The first column is wider (model
/// names are long); the three metric columns share the rest equally.
class _TableRow extends StatelessWidget {
  final List<String> cells;
  final bool isHeader;
  final bool highlight;

  const _TableRow({
    required this.cells,
    this.isHeader = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: isHeader ? 11 : 12,
      fontWeight: isHeader || highlight ? FontWeight.w700 : FontWeight.w500,
      color: highlight
          ? C.g2
          : isHeader
              ? C.t3
              : C.t1,
      height: 1.3,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: highlight
          ? BoxDecoration(
              color: C.g2.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.g2.withValues(alpha: 0.35)),
            )
          : null,
      child: Row(
        children: [
          Expanded(flex: 13, child: Text(cells[0], style: style)),
          for (final c in cells.skip(1))
            Expanded(
              flex: 8,
              child: Text(c, textAlign: TextAlign.right, style: style),
            ),
        ],
      ),
    );
  }
}

class _ShapGuideCard extends StatelessWidget {
  const _ShapGuideCard();

  @override
  Widget build(BuildContext context) {
    return const _InfoCard(
      icon: Icons.insights_rounded,
      title: 'Explainable AI (SHAP)',
      children: [
        _KeyValue('Method', 'SHAP (SHapley Additive exPlanations)'),
        _KeyValue('Library', 'shap (Python) — TreeExplainer for XGBoost'),
        _KeyValue(
          'Purpose',
          'Shows how much each vital sign pushed this prediction up or '
              'down',
        ),
        _KeyValue(
          'Consistency',
          'Same input always gives the same explanation; values add up to '
              'the model output',
        ),
        SizedBox(height: 6),
        Text(
          'How to read SHAP values:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: C.t1,
          ),
        ),
        SizedBox(height: 10),
        _ShapExample('+0.88', 'Strongly pushes toward HIGH RISK', C.high),
        _ShapExample('+0.42', 'Moderately pushes toward HIGH RISK', C.mid),
        _ShapExample('+0.10', 'Slightly pushes toward HIGH RISK', C.g2),
        _ShapExample('-0.08', 'Pushes toward LOW RISK (good)', C.low),
        SizedBox(height: 4),
        _Note('Source: Lundberg & Lee (2017), NeurIPS.'),
      ],
    );
  }
}

/// Example SHAP badge + its meaning.
class _ShapExample extends StatelessWidget {
  final String value;
  final String meaning;
  final Color color;

  const _ShapExample(this.value, this.meaning, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              meaning,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitationsCard extends StatelessWidget {
  const _LimitationsCard();

  static const _points = [
    'Dataset from Bangladesh — not Philippines. Limited generalizability.',
    '6 features only — obstetric history, hemoglobin absent.',
    'Prototype only — not clinically validated. Performance has been '
        'evaluated, not validated.',
    'Small usability sample (3–5 respondents).',
    'Decision support only — always apply professional clinical judgment.',
  ];

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.warning_amber_outlined,
      title: 'Limitations',
      children: [
        for (final p in _points)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dot nudged down so it lines up with the first text line.
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: C.g2,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p,
                    style: const TextStyle(
                      fontSize: 13,
                      color: C.t2,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

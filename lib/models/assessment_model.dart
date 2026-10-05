import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ASSESSMENT MODEL
//
// Everything in this file is "pure data + logic" — no screens, no colors.
// Keeping it separate means the hardcoded scoring below can later be swapped
// for a real API call without touching any UI code.
// ─────────────────────────────────────────────────────────────────────────────

/// The three classes the model can predict.
/// These match the labels in the UCI Maternal Health Risk dataset
/// ("low risk", "mid risk", "high risk").
enum RiskLevel { low, mid, high }

/// How much ONE vital sign pushed the prediction toward HIGH risk.
///
/// This mimics a SHAP value: a positive [contribution] pushes the patient
/// toward HIGH risk, a negative one pulls them toward LOW risk.
class FeatureContribution {
  /// Human-readable name, e.g. "Systolic BP".
  final String featureName;

  /// The patient's value formatted for display, e.g. "140 mmHg".
  final String displayValue;

  /// Simulated SHAP value (positive = riskier, negative = safer).
  final double contribution;

  const FeatureContribution({
    required this.featureName,
    required this.displayValue,
    required this.contribution,
  });
}

/// The full output of one assessment: the predicted class plus the
/// per-feature explanation that the Result screen draws as a chart.
class AssessmentResult {
  final RiskLevel riskLevel;

  /// Sorted by absolute contribution, biggest influence first.
  final List<FeatureContribution> features;

  /// Sum of all contributions. Not shown in the UI, but handy when
  /// debugging why a case landed in a certain class.
  final double totalScore;

  const AssessmentResult({
    required this.riskLevel,
    required this.features,
    this.totalScore = 0,
  });

  /// Big label shown on the Result screen.
  String get riskLabel => riskLevel == RiskLevel.low
      ? 'LOW RISK'
      : riskLevel == RiskLevel.mid
          ? 'MID RISK'
          : 'HIGH RISK';

  /// What the clinician should do next for this risk class.
  String get recommendation {
    switch (riskLevel) {
      case RiskLevel.low:
        return 'Continue the routine ANC schedule. Remind the patient of '
            'the next visit. Provide health education on nutrition and '
            'pregnancy danger signs.\n'
            'Source: DOH Maternal Care Protocol 2020.';
      case RiskLevel.mid:
        return 'Schedule a follow-up within 1–2 weeks. Monitor BP and blood '
            'sugar at every visit. Counsel on warning signs: severe '
            'headache, blurred vision, swelling.\n'
            'Source: DOH Maternal Care Protocol 2020.';
      case RiskLevel.high:
        return 'Refer to a specialist immediately. Monitor BP closely. '
            'Prepare the referral slip. Advise the patient to avoid '
            'strenuous activity.\n'
            'Source: DOH Maternal Care Protocol 2020.';
    }
  }

  IconData get riskIcon => riskLevel == RiskLevel.low
      ? Icons.check_circle_outline
      : riskLevel == RiskLevel.mid
          ? Icons.radio_button_on
          : Icons.warning_amber_rounded;

  /// Simulated probability scores for the 3 classes.
  ///
  /// A real XGBoost model returns these from `predict_proba()`. Until the
  /// API exists we return fixed, plausible numbers per class so the
  /// "Model Confidence" card has something realistic to draw.
  Map<String, double> get probabilities {
    if (riskLevel == RiskLevel.high) {
      return {'LOW': 0.06, 'MID': 0.09, 'HIGH': 0.85};
    }
    if (riskLevel == RiskLevel.mid) {
      return {'LOW': 0.20, 'MID': 0.62, 'HIGH': 0.18};
    }
    return {'LOW': 0.78, 'MID': 0.16, 'HIGH': 0.06};
  }
}

// HARDCODED SCORING — simulates XGBoost output
// Will be replaced by Flask API call in Week 3
// API will return: {'risk': 0|1|2, 'shap': [...], 'proba': [...]}
class Assessment {
  // Private constructor: this class only holds static helpers,
  // so nobody should ever write `Assessment()`.
  Assessment._();

  /// Scores the six vital signs and returns a risk class plus
  /// a SHAP-style explanation.
  ///
  /// Each vital gets a points value from a simple threshold ladder. The
  /// points act as fake SHAP values: they are added up to decide the
  /// class, and shown individually to explain the decision.
  static AssessmentResult assess({
    required double age,
    required double systolicBP,
    required double diastolicBP,
    required double bloodSugar,
    required double temperature,
    required double heartRate,
  }) {
    final features = <FeatureContribution>[
      FeatureContribution(
        featureName: 'Systolic BP',
        displayValue: '${systolicBP.round()} mmHg',
        contribution: _systolicScore(systolicBP),
      ),
      FeatureContribution(
        featureName: 'Blood Sugar',
        displayValue: '${bloodSugar.toStringAsFixed(1)} mmol/L',
        contribution: _bloodSugarScore(bloodSugar),
      ),
      FeatureContribution(
        featureName: 'Diastolic BP',
        displayValue: '${diastolicBP.round()} mmHg',
        contribution: _diastolicScore(diastolicBP),
      ),
      FeatureContribution(
        featureName: 'Age',
        displayValue: '${age.round()} yrs',
        contribution: _ageScore(age),
      ),
      FeatureContribution(
        featureName: 'Heart Rate',
        displayValue: '${heartRate.round()} bpm',
        contribution: _heartRateScore(heartRate),
      ),
      FeatureContribution(
        featureName: 'Body Temperature',
        displayValue: '${temperature.toStringAsFixed(1)} °F',
        contribution: _temperatureScore(temperature),
      ),
    ];

    // Add up every contribution to get one overall score.
    final total = features.fold<double>(0, (sum, f) => sum + f.contribution);

    // Cut-offs that turn the score into a class.
    final RiskLevel level;
    if (total >= 1.0) {
      level = RiskLevel.high;
    } else if (total >= 0.35) {
      level = RiskLevel.mid;
    } else {
      level = RiskLevel.low;
    }

    // Biggest influence first — that's how SHAP bar charts are read.
    features.sort(
      (a, b) => b.contribution.abs().compareTo(a.contribution.abs()),
    );

    return AssessmentResult(
      riskLevel: level,
      features: features,
      totalScore: total,
    );
  }

  // ── Threshold ladders ────────────────────────────────────────────────────
  // Each one checks the highest band first and falls through to the
  // "normal" value at the end. Negative numbers mean "this vital is
  // reassuring" and pull the total toward LOW.

  static double _systolicScore(double v) => v >= 160
      ? 1.10
      : v >= 140
          ? 0.88
          : v >= 130
              ? 0.52
              : v >= 120
                  ? 0.20
                  : -0.10;

  static double _bloodSugarScore(double v) => v >= 13
      ? 0.90
      : v >= 11
          ? 0.75
          : v >= 7.5
              ? 0.42
              : v >= 6
                  ? 0.10
                  : -0.15;

  static double _diastolicScore(double v) => v >= 100
      ? 0.75
      : v >= 90
          ? 0.65
          : v >= 80
              ? 0.28
              : -0.08;

  // Age is U-shaped: both older (35+) and adolescent (≤17)
  // pregnancies carry extra risk.
  static double _ageScore(double v) => v >= 40
      ? 0.38
      : v >= 35
          ? 0.28
          : v <= 17
              ? 0.22
              : 0.05;

  static double _heartRateScore(double v) => v >= 110
      ? 0.28
      : v >= 100
          ? 0.20
          : v >= 90
              ? 0.08
              : -0.05;

  static double _temperatureScore(double v) => v >= 101
      ? 0.22
      : v >= 100
          ? 0.18
          : v >= 99
              ? 0.05
              : -0.08;
}

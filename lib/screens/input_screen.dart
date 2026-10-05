import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/assessment_model.dart';
import 'result_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 3: INPUT VITALS
//
// Six sliders, one per vital sign. The risk badge in the header is
// recalculated on EVERY slider movement, so the clinician sees how each
// vital changes the prediction before confirming.
// ─────────────────────────────────────────────────────────────────────────────

/// Visual state of one vital: normal (rose), warn (amber), danger (red).
enum VitalState { normal, warn, danger }

/// A vital's state plus the short reason shown under its slider
/// (e.g. "Hypertension"). [label] is null when the value is normal.
class VitalStatus {
  final VitalState state;
  final String? label;
  const VitalStatus(this.state, [this.label]);
}

/// Text for the clinical info bottom sheet.
class VitalInfo {
  final String name;
  final String normal;
  final String elevated;
  final String high;
  final String source;

  const VitalInfo({
    required this.name,
    required this.normal,
    required this.elevated,
    required this.high,
    required this.source,
  });
}

/// Everything needed to draw one slider card: range, unit, how to
/// classify a value, and the info sheet text. Describing all six vitals
/// as data (instead of six hand-built widgets) keeps them consistent.
class VitalSpec {
  final String label;
  final IconData icon;
  final String unit;
  final double min, max;
  final int divisions;

  /// 0 for whole numbers (age, BP, heart rate), 1 for one decimal place.
  final int decimals;
  final VitalStatus Function(double value) status;
  final VitalInfo info;

  const VitalSpec({
    required this.label,
    required this.icon,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.decimals,
    required this.status,
    required this.info,
  });

  String format(double v) => v.toStringAsFixed(decimals);

  /// Sliders produce values like 98.60000000001. Rounding to the display
  /// precision means threshold checks (e.g. ≥ 100.4) behave exactly as
  /// the number on screen suggests.
  double snap(double v) => double.parse(v.toStringAsFixed(decimals));
}

// ── Threshold rules (what makes a card turn amber or red) ──────────────────

VitalStatus _ageStatus(double v) {
  if (v >= 35) return const VitalStatus(VitalState.danger, 'Advanced maternal age');
  if (v <= 17) return const VitalStatus(VitalState.warn, 'Adolescent pregnancy');
  return const VitalStatus(VitalState.normal);
}

VitalStatus _systolicStatus(double v) {
  if (v >= 140) return const VitalStatus(VitalState.danger, 'Hypertension');
  if (v >= 130) return const VitalStatus(VitalState.warn, 'Elevated');
  return const VitalStatus(VitalState.normal);
}

VitalStatus _diastolicStatus(double v) {
  if (v >= 90) return const VitalStatus(VitalState.danger, 'High diastolic');
  if (v >= 80) return const VitalStatus(VitalState.warn, 'Slightly elevated');
  return const VitalStatus(VitalState.normal);
}

VitalStatus _bloodSugarStatus(double v) {
  if (v >= 11.0) return const VitalStatus(VitalState.danger, 'High glucose');
  if (v >= 7.5) return const VitalStatus(VitalState.warn, 'GDM risk');
  return const VitalStatus(VitalState.normal);
}

VitalStatus _temperatureStatus(double v) {
  if (v >= 100.4) return const VitalStatus(VitalState.danger, 'Fever');
  if (v >= 99.0) return const VitalStatus(VitalState.warn, 'Mild fever');
  return const VitalStatus(VitalState.normal);
}

VitalStatus _heartRateStatus(double v) {
  if (v >= 100) return const VitalStatus(VitalState.danger, 'Tachycardia');
  if (v >= 90) return const VitalStatus(VitalState.warn, 'Elevated');
  return const VitalStatus(VitalState.normal);
}

// ── The six vitals ──────────────────────────────────────────────────────────
// Clinical reference text is hardcoded for the prototype, based on the
// WHO ANC Guidelines 2016 (plus WHO 2013 criteria for glucose).

const _sourceNote = 'Source: WHO recommendations on antenatal care for a '
    'positive pregnancy experience (2016). Prototype reference values — '
    'verify against your local protocol.';

const VitalSpec kAgeSpec = VitalSpec(
  label: 'Age',
  icon: Icons.cake_outlined,
  unit: 'yrs',
  min: 13,
  max: 55,
  divisions: 42,
  decimals: 0,
  status: _ageStatus,
  info: VitalInfo(
    name: 'Maternal Age',
    normal: '18–34 years. Lowest obstetric risk group.',
    elevated: '≤ 17 years. Adolescent pregnancy — higher risk of '
        'pre-eclampsia, anaemia and preterm birth.',
    high: '≥ 35 years. Advanced maternal age — higher risk of '
        'hypertension, gestational diabetes and chromosomal anomalies.',
    source: _sourceNote,
  ),
);

const VitalSpec kSystolicSpec = VitalSpec(
  label: 'Systolic BP',
  icon: Icons.favorite_border_rounded,
  unit: 'mmHg',
  min: 70,
  max: 180,
  divisions: 110,
  decimals: 0,
  status: _systolicStatus,
  info: VitalInfo(
    name: 'Systolic Blood Pressure',
    normal: '< 130 mmHg. Expected range in pregnancy.',
    elevated: '130–139 mmHg. Recheck BP and watch for rising trend.',
    high: '≥ 140 mmHg. Hypertension in pregnancy — screen for '
        'pre-eclampsia (proteinuria, headache, visual changes). '
        '≥ 160 mmHg is severe.',
    source: _sourceNote,
  ),
);

const VitalSpec kDiastolicSpec = VitalSpec(
  label: 'Diastolic BP',
  icon: Icons.favorite_outline,
  unit: 'mmHg',
  min: 40,
  max: 120,
  divisions: 80,
  decimals: 0,
  status: _diastolicStatus,
  info: VitalInfo(
    name: 'Diastolic Blood Pressure',
    normal: '< 80 mmHg. Expected range in pregnancy.',
    elevated: '80–89 mmHg. Slightly elevated — monitor at each visit.',
    high: '≥ 90 mmHg. Hypertension in pregnancy — assess for '
        'pre-eclampsia. ≥ 110 mmHg is severe.',
    source: _sourceNote,
  ),
);

const VitalSpec kBloodSugarSpec = VitalSpec(
  label: 'Blood Sugar',
  icon: Icons.bloodtype_outlined,
  unit: 'mmol/L',
  min: 3.0,
  max: 20.0,
  divisions: 170,
  decimals: 1,
  status: _bloodSugarStatus,
  info: VitalInfo(
    name: 'Blood Sugar',
    normal: '< 7.5 mmol/L. Within the expected range.',
    elevated: '7.5–10.9 mmol/L. Possible gestational diabetes (GDM) — '
        'arrange a confirmatory oral glucose tolerance test.',
    high: '≥ 11.0 mmol/L. Consistent with diabetes in pregnancy '
        '(WHO 2013: random glucose ≥ 11.1 mmol/L).',
    source: _sourceNote,
  ),
);

const VitalSpec kTemperatureSpec = VitalSpec(
  label: 'Body Temperature',
  icon: Icons.thermostat_rounded,
  unit: '°F',
  min: 96.0,
  max: 104.0,
  divisions: 80,
  decimals: 1,
  status: _temperatureStatus,
  info: VitalInfo(
    name: 'Body Temperature',
    normal: '97.0–98.9 °F. Normal body temperature.',
    elevated: '99.0–100.3 °F. Low-grade / mild fever — recheck and look '
        'for a source.',
    high: '≥ 100.4 °F (38 °C). Fever — evaluate for infection such as '
        'UTI or chorioamnionitis.',
    source: _sourceNote,
  ),
);

const VitalSpec kHeartRateSpec = VitalSpec(
  label: 'Heart Rate',
  icon: Icons.monitor_heart_outlined,
  unit: 'bpm',
  min: 50,
  max: 140,
  divisions: 90,
  decimals: 0,
  status: _heartRateStatus,
  info: VitalInfo(
    name: 'Maternal Heart Rate',
    normal: '60–89 bpm. Normal resting rate (slightly higher in late '
        'pregnancy is expected).',
    elevated: '90–99 bpm. Elevated — recheck at rest.',
    high: '≥ 100 bpm. Tachycardia — assess for infection, bleeding, '
        'anaemia or dehydration.',
    source: _sourceNote,
  ),
);

// ─────────────────────────────────────────────────────────────────────────────

/// The vitals form with live risk preview.
class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  // Default values = a typical healthy patient.
  static const double _defAge = 28,
      _defSystolic = 120,
      _defDiastolic = 80,
      _defBloodSugar = 6.5,
      _defTemperature = 98.6,
      _defHeartRate = 76;

  double age = _defAge;
  double systolic = _defSystolic;
  double diastolic = _defDiastolic;
  double bloodSugar = _defBloodSugar;
  double temperature = _defTemperature;
  double heartRate = _defHeartRate;
  bool isLoading = false;

  /// Next case number. Computed (not stored) so it stays correct after
  /// coming back from the Result screen.
  String get _caseLabel => 'Case ${SessionManager.count + 1}';

  void _resetVitals() {
    age = _defAge;
    systolic = _defSystolic;
    diastolic = _defDiastolic;
    bloodSugar = _defBloodSugar;
    temperature = _defTemperature;
    heartRate = _defHeartRate;
  }

  /// Runs the (temporary) scoring logic on the current slider values.
  AssessmentResult _runAssessment() => Assessment.assess(
        age: age,
        systolicBP: systolic,
        diastolicBP: diastolic,
        bloodSugar: bloodSugar,
        temperature: temperature,
        heartRate: heartRate,
      );

  Future<void> _confirm() async {
    if (isLoading) return; // ignore double taps
    HapticFeedback.mediumImpact();
    setState(() => isLoading = true);

    // 🔄 WEEK 3: Replace Assessment.assess() with http.post()
    // to Flask API at /predict. API returns:
    // {'risk': int, 'shap': List<double>, 'proba': List<double>}
    //
    // The 800ms delay below only simulates that network round-trip so the
    // loading state can be seen and tested now.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final result = _runAssessment();

    final entry = SessionEntry(
      caseLabel: _caseLabel,
      result: result,
      time: DateTime.now(),
      age: age,
      systolic: systolic,
      diastolic: diastolic,
      bloodSugar: bloodSugar,
      temp: temperature,
      heartRate: heartRate,
    );
    SessionManager.add(entry);

    // The user may have left the screen during the delay; touching
    // `context` after that would crash, so check `mounted` first.
    if (!mounted) return;
    setState(() => isLoading = false);

    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ResultScreen(result: result, entry: entry),
      ),
    );

    if (!mounted) return;
    // "Assess Another Patient" → start from clean defaults.
    // "‹ Edit" (plain back) → keep the values so they can be adjusted.
    setState(() {
      if (action == ResultScreen.assessAnother) _resetVitals();
    });
  }

  /// Builds one slider card. [onChanged] stores the new value; this
  /// helper adds the haptic tick and setState around it.
  Widget _vital(VitalSpec spec, double value, ValueChanged<double> onChanged) {
    return VitalCard(
      spec: spec,
      value: value,
      onChanged: (raw) {
        final v = spec.snap(raw);
        if (v == value) return;
        HapticFeedback.selectionClick();
        setState(() => onChanged(v));
      },
    );
  }

  /// Widest the form gets: three 340px vital cards side by side.
  static const double _maxWidth = 1080;

  /// The scrollable form. [width] is the content width from RspContent:
  /// one column of vitals on phones, two on tablets, three on desktop.
  Widget _buildForm(double width) {
    final wide = width >= 640;

    final confirmButton = SizedBox(
      width: wide ? 380 : double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : _confirm,
        style: ElevatedButton.styleFrom(
          // While loading the button is "disabled"; these keep
          // it dark rose instead of Material's default gray.
          disabledBackgroundColor: C.g1,
          disabledForegroundColor: Colors.white,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Confirm & View Full Results →',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );

    const privacyNote = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline_rounded, size: 13, color: C.t3),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'No patient data stored. Session only.',
            style: TextStyle(fontSize: 12, color: C.t3),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Case chip + hint ──
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: C.g2.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                _caseLabel,
                style: const TextStyle(
                  color: C.g2,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                '· tap any label for clinical info',
                style: TextStyle(fontSize: 12, color: C.t3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── The six sliders ──
        RspGrid(
          columns: Rsp.columnsFor(width, minItem: 300),
          children: [
            _vital(kAgeSpec, age, (v) => age = v),
            _vital(kSystolicSpec, systolic, (v) => systolic = v),
            _vital(kDiastolicSpec, diastolic, (v) => diastolic = v),
            _vital(kBloodSugarSpec, bloodSugar, (v) => bloodSugar = v),
            _vital(kTemperatureSpec, temperature, (v) => temperature = v),
            _vital(kHeartRateSpec, heartRate, (v) => heartRate = v),
          ],
        ),
        const SizedBox(height: 10),

        // ── Confirm ──
        // Phone: full-width button with the privacy note under it.
        // Wide: privacy note on the left, button on the right.
        if (wide)
          Row(
            children: [
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: privacyNote,
                ),
              ),
              const SizedBox(width: 16),
              confirmButton,
            ],
          )
        else ...[
          confirmButton,
          const SizedBox(height: 14),
          const Center(child: privacyNote),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-scored on every rebuild, i.e. on every slider movement.
    final live = _runAssessment();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Rsp(
      child: Scaffold(
        backgroundColor: C.bg,
        body: Column(
          children: [
            // Header stays fixed while the sliders scroll, so the live
            // badge is always visible.
            GradientHeader(
              topPadding: 8,
              bottomPadding: 24,
              maxWidth: _maxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HeaderBackButton(label: 'Check'),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Patient Vitals',
                              style: TextStyle(
                                color: C.onDark,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Adjust sliders · Risk updates live',
                              style: TextStyle(
                                color: C.onDarkSub,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _LiveRiskBadge(level: live.riskLevel),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.only(top: 16, bottom: bottomInset + 24),
                children: [
                  RspContent(
                    maxWidth: _maxWidth,
                    builder: (context, width) => _buildForm(width),
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

/// The badge in the header that follows the sliders.
/// AnimatedContainer fades its colors; AnimatedSwitcher cross-fades the
/// text when the class changes.
class _LiveRiskBadge extends StatelessWidget {
  final RiskLevel level;
  const _LiveRiskBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Live risk preview: ${level.short}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: level.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: level.color.withValues(alpha: 0.4)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Row(
            key: ValueKey(level),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                level.emoji,
                style: TextStyle(
                  color: level.color,
                  fontSize: 20,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                level.short,
                style: TextStyle(
                  color: level.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One vital sign: label row, value badge, slider, and range labels.
///
/// The accent color (rose → amber → red) comes from the value's status,
/// so an abnormal vital is noticeable at a glance.
class VitalCard extends StatelessWidget {
  final VitalSpec spec;
  final double value;
  final ValueChanged<double> onChanged;

  const VitalCard({
    super.key,
    required this.spec,
    required this.value,
    required this.onChanged,
  });

  static Color _accent(VitalState s) => switch (s) {
        VitalState.normal => C.g2,
        VitalState.warn => C.mid,
        VitalState.danger => C.high,
      };

  static Color _accentBg(VitalState s) => switch (s) {
        VitalState.normal => C.g2.withValues(alpha: 0.10),
        VitalState.warn => C.midBg,
        VitalState.danger => C.highBg,
      };

  @override
  Widget build(BuildContext context) {
    final status = spec.status(value);
    final accent = _accent(status.state);
    final elevated = status.state != VitalState.normal;
    final valueText = '${spec.format(value)} ${spec.unit}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: kCardShadow,
          // A faint outline appears only when the value is abnormal.
          border: Border.all(
            color: elevated
                ? accent.withValues(alpha: 0.25)
                : Colors.transparent,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                children: [
                  // ── Top row: icon, tappable label, value badge ──
                  Row(
                    children: [
                      Icon(spec.icon, size: 17, color: accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ClickArea(
                            onTap: () => showVitalInfo(context, spec.info),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      spec.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: elevated ? accent : C.t1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.info_outline,
                                    size: 13,
                                    color: C.t3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _accentBg(status.state),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          valueText,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Slider ──
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accent,
                      thumbColor: accent,
                      inactiveTrackColor: accent.withValues(alpha: 0.12),
                      overlayColor: accent.withValues(alpha: 0.12),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      // Hide the tick marks the divisions would draw.
                      activeTickMarkColor: Colors.transparent,
                      inactiveTickMarkColor: Colors.transparent,
                      showValueIndicator: ShowValueIndicator.never,
                    ),
                    child: Slider(
                      value: value.clamp(spec.min, spec.max),
                      min: spec.min,
                      max: spec.max,
                      divisions: spec.divisions,
                      semanticFormatterCallback: (v) =>
                          '${spec.format(v)} ${spec.unit}',
                      onChanged: onChanged,
                    ),
                  ),

                  // ── Bottom row: min · status · max ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        spec.format(spec.min),
                        style: const TextStyle(fontSize: 10, color: C.t3),
                      ),
                      if (status.label != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              status.label!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      Text(
                        spec.format(spec.max),
                        style: const TextStyle(fontSize: 10, color: C.t3),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3px left strip in the accent color when warn/danger.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: elevated ? 3 : 0,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with Normal / Elevated / High reference ranges.
/// Clinical info for one vital, with Normal / Elevated / High ranges.
///
/// Phones get a bottom sheet (easy to reach and swipe away with a thumb);
/// tablets and desktops get a centered dialog, which suits a mouse better.
void showVitalInfo(BuildContext context, VitalInfo info) {
  HapticFeedback.lightImpact();

  if (!Rsp.isMobile(context)) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: C.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
            child: _VitalInfoBody(info: info, showClose: true),
          ),
        ),
      ),
    );
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      final bottomInset = MediaQuery.of(context).padding.bottom;
      return Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
        decoration: const BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar — signals the sheet can be swiped down.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: C.t3.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _VitalInfoBody(info: info),
          ],
        ),
      );
    },
  );
}

/// The content shared by the bottom sheet and the dialog.
class _VitalInfoBody extends StatelessWidget {
  final VitalInfo info;
  final bool showClose;

  const _VitalInfoBody({required this.info, this.showClose = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                info.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: C.t1,
                ),
              ),
            ),
            if (showClose)
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: C.t2),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoRow(label: 'Normal', color: C.low, bg: C.lowBg, text: info.normal),
        _InfoRow(
          label: 'Elevated',
          color: C.mid,
          bg: C.midBg,
          text: info.elevated,
        ),
        _InfoRow(label: 'High', color: C.high, bg: C.highBg, text: info.high),
        const SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.only(right: showClose ? 8 : 0),
          child: Text(
            info.source,
            style: const TextStyle(
              fontSize: 11,
              color: C.t3,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

/// One colored row inside the info sheet.
class _InfoRow extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final String text;

  const _InfoRow({
    required this.label,
    required this.color,
    required this.bg,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: C.t2, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

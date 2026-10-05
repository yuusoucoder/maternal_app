import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import 'input_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 2: DANGER CHECK
//
// Some situations are emergencies no matter what a model says. This screen
// asks about them FIRST: if any sign is present, the clinician is told to
// refer immediately and the ML assessment is skipped entirely.
// ─────────────────────────────────────────────────────────────────────────────

/// Pre-assessment emergency checklist.
class DangerCheckScreen extends StatefulWidget {
  const DangerCheckScreen({super.key});

  @override
  State<DangerCheckScreen> createState() => _DangerCheckScreenState();
}

class _DangerCheckScreenState extends State<DangerCheckScreen> {
  // A checklist doesn't need the full desktop width; 960px keeps two
  // comfortable columns.
  static const double _maxWidth = 960;

  static const List<(IconData, String)> _signs = [
    (Icons.psychology_alt_outlined, "Severe headache that won't go away"),
    (Icons.visibility_off_outlined, 'Sudden blurred or double vision'),
    (Icons.back_hand_outlined, 'Severe swelling of face, hands, or feet'),
    (Icons.child_friendly_outlined, 'Decreased or absent fetal movement'),
    (Icons.water_drop_outlined, 'Vaginal bleeding or fluid leakage'),
    (Icons.air_rounded, 'Chest pain or difficulty breathing'),
  ];

  // One true/false per sign, in the same order as [_signs].
  final List<bool> _checked = List.filled(_signs.length, false);

  bool get _anyChecked => _checked.contains(true);

  void _toggle(int i) {
    HapticFeedback.selectionClick();
    setState(() => _checked[i] = !_checked[i]);
  }

  /// No danger signs → continue to the vitals form. pushReplacement (not
  /// push) so pressing back on the vitals screen returns Home instead of
  /// re-showing this checklist.
  void _proceed() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const InputScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Rsp(
      child: Scaffold(
        backgroundColor: C.bg,
        body: Column(
          children: [
            const GradientHeader(
              topPadding: 8,
              maxWidth: _maxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeaderBackButton(label: 'Home'),
                  SizedBox(height: 14),
                  Text(
                    'Before Assessment',
                    style: TextStyle(
                      color: C.onDark,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Check if the patient has any emergency signs right now.',
                    style: TextStyle(
                      color: C.onDarkSub,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable checklist ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 20, bottom: 12),
                children: [
                  RspContent(
                    maxWidth: _maxWidth,
                    builder: (context, width) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _WarningBanner(),
                        const SizedBox(height: 16),
                        // Two columns of signs on tablets and desktops.
                        RspGrid(
                          columns: width >= 640 ? 2 : 1,
                          children: [
                            for (var i = 0; i < _signs.length; i++)
                              _DangerSignCard(
                                icon: _signs[i].$1,
                                label: _signs[i].$2,
                                checked: _checked[i],
                                onTap: () => _toggle(i),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Pinned bottom area: emergency card OR proceed button ──
            Padding(
              padding: EdgeInsets.only(top: 8, bottom: 16 + bottomInset),
              child: RspContent(
                maxWidth: _maxWidth,
                builder: (context, width) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _anyChecked
                      ? const _EmergencyAction(key: ValueKey('emergency'))
                      // Full-width button on phones; a right-aligned
                      // button on wide screens (a 900px button looks odd).
                      : Align(
                          key: const ValueKey('proceed'),
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: width >= 640 ? 380 : double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _proceed,
                              child: const Text(
                                'No emergency signs — proceed →',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Red notice explaining what this screen is for.
class _WarningBanner extends StatelessWidget {
  const _WarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.highBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.highBdr),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: C.high, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'If any signs are present, refer immediately — skip the ML '
              'assessment.',
              style: TextStyle(
                color: C.high,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable danger sign. The WHOLE card toggles (not just the box),
/// which is easier to hit with a thumb during a busy clinic.
class _DangerSignCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _DangerSignCard({
    required this.icon,
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        checked: checked,
        label: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // antiAlias clipping keeps the red left strip inside the
          // rounded corners.
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: checked ? C.highBg : C.card,
            borderRadius: radius,
            boxShadow: kCardShadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        _CheckBox(checked: checked),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: checked ? C.high : C.t1,
                              fontWeight: checked
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          icon,
                          size: 20,
                          color: checked ? C.high : C.t3,
                        ),
                      ],
                    ),
                  ),
                  // 3px red strip on the left when checked. Drawn as its own
                  // widget because Flutter can't combine a one-sided border
                  // with rounded corners.
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: checked ? 3 : 0,
                      color: C.high,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 22x22 rounded checkbox that fills red when checked.
class _CheckBox extends StatelessWidget {
  final bool checked;
  const _CheckBox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? C.high : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: checked ? C.high : C.t3, width: 1.6),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

/// Shown instead of the "proceed" button as soon as any sign is ticked.
/// There is deliberately no way to continue to the ML form from here.
class _EmergencyAction extends StatelessWidget {
  const _EmergencyAction({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: C.highBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.highBdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: C.high,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_hospital,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Immediate Referral Required',
                  style: TextStyle(
                    color: C.high,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Do not proceed with the ML assessment. Stabilize the patient '
            'and refer to the nearest hospital with emergency obstetric '
            'care. Prepare the referral slip and arrange transport.',
            style: TextStyle(color: C.t1, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 6),
          const Text(
            'Source: DOH Maternal Care Protocol 2020.',
            style: TextStyle(
              color: C.t2,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: C.high),
              child: const Text(
                'Return to Home',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

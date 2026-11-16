import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/device/phone_tilt.dart';
import '../theme/app_theme.dart';

/// Enabled only when the build explicitly includes --dart-define=UAT_PHONE_ANGLE=true.
const bool uatPhoneAngleEnabled = bool.fromEnvironment('UAT_PHONE_ANGLE');

/// An on-screen phone angle for UAT setup; absent from ordinary builds.
class UatPhoneAngle extends StatelessWidget {
  const UatPhoneAngle({
    super.key,
    this.monitor,
    this.alignment = Alignment.bottomLeft,
  });

  /// Test injection; production shares the existing gravity monitor.
  final PhoneTiltMonitor? monitor;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => uatPhoneAngleEnabled
      ? _ActivePhoneAngle(monitor: monitor, alignment: alignment)
      : const SizedBox.shrink();
}

class _ActivePhoneAngle extends StatefulWidget {
  const _ActivePhoneAngle({this.monitor, required this.alignment});
  final PhoneTiltMonitor? monitor;
  final Alignment alignment;

  @override
  State<_ActivePhoneAngle> createState() => _ActivePhoneAngleState();
}

class _ActivePhoneAngleState extends State<_ActivePhoneAngle>
    with WidgetsBindingObserver {
  static const _interval = Duration(milliseconds: 250);
  static const _staleTicks = 4;
  late final PhoneTiltMonitor _monitor;
  Timer? _timer;
  GravitySample? _lastSample;
  double? _angle;
  int _unchangedTicks = 0;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _monitor = widget.monitor ?? PhoneTiltMonitor.platform();
    // A previous screen may have left an old sample in the shared monitor.
    _lastSample = _monitor.lastSample;
    _monitor.retain();
    _timer = Timer.periodic(_interval, (_) => _refresh());
  }

  void _refresh() {
    if (!_active) return;
    final sample = _monitor.lastSample;
    if (sample != null && !identical(sample, _lastSample)) {
      _lastSample = sample;
      _unchangedTicks = 0;
      final magnitude = math.sqrt(
        sample.x * sample.x + sample.y * sample.y + sample.z * sample.z,
      );
      final angle = magnitude.isFinite && magnitude >= 1
          ? tiltFromFlatDegrees(sample)
          : null;
      if (_angle != angle) setState(() => _angle = angle);
    } else if (++_unchangedTicks >= _staleTicks && _angle != null) {
      setState(() => _angle = null);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _active = true;
      _lastSample = _monitor.lastSample;
      _unchangedTicks = 0;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _active = false;
      if (_angle != null) setState(() => _angle = null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _monitor.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: widget.alignment,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(AppRadius.bar),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
              vertical: AppSpacing.s4,
            ),
            child: Text(
              _angle == null
                  ? '폰 각도: 측정 중'
                  : '폰 각도: ${_angle!.toStringAsFixed(1)}°',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.onInk),
            ),
          ),
        ),
      ),
    ),
  );
}

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/avatar_model.dart';
import '../models/pose_frame.dart';
import 'pose_avatar_view.dart';
import 'pose_camera_view.dart';
import '../services/pose/rep_judge.dart';
import 'chest_height_overlay.dart';

/// Changes presentation only. Never starts/stops the camera or the detector.
class PoseAvatarToggleView extends StatefulWidget {
  const PoseAvatarToggleView({
    super.key,
    required this.controller,
    this.frame,
    this.mirror = false,
    this.showLandmarks = false,
    this.isVisible,
    this.cameraOverlay,
    this.avatarBuilder,
    this.initialModel = AvatarModel.astronaut,
    this.allowAvatarSelection = true,
    this.chestSnapshot,
  });

  final CameraController? controller;
  final PoseFrame? frame;
  final bool mirror;
  final bool showLandmarks;
  final bool Function(Keypoint keypoint, PoseFrame frame)? isVisible;
  final Widget? cameraOverlay;
  final AvatarModel initialModel;
  final bool allowAvatarSelection;
  final JudgeSnapshot? chestSnapshot;

  /// Allows widget tests to exercise the toggle without a platform WebView.
  final Widget Function(PoseFrame? frame, bool mirror, AvatarModel model)?
  avatarBuilder;

  @override
  State<PoseAvatarToggleView> createState() => _PoseAvatarToggleViewState();
}

class _PoseAvatarToggleViewState extends State<PoseAvatarToggleView> {
  bool _avatar = false;
  late AvatarModel _model;

  @override
  void initState() {
    super.initState();
    _model = widget.initialModel;
  }

  Future<void> _chooseAvatar() async {
    final result = await showModalBottomSheet<AvatarModel>(
      context: context,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: ListView(
            children: [
              for (final model in AvatarModel.values)
                ListTile(
                  title: Text(model.label),
                  subtitle: Text(model.category),
                  leading: Image.asset(
                    model.thumbnailPath,
                    width: 44,
                    height: 44,
                    errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
                  ),
                  trailing: model == _model ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, model),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _model = result;
      _avatar = true;
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (_avatar)
        widget.avatarBuilder?.call(widget.frame, widget.mirror, _model) ??
            PoseAvatarView(
              frame: widget.frame,
              mirror: widget.mirror,
              model: _model,
            )
      else ...[
        PoseCameraView(
          controller: widget.controller,
          frame: widget.frame,
          mirror: widget.mirror,
          showLandmarks: widget.showLandmarks,
          isVisible: widget.isVisible,
        ),
        ?widget.cameraOverlay,
      ],
      if (widget.chestSnapshot case final snapshot?)
        ChestHeightOverlay(
          frame: widget.frame,
          snapshot: snapshot,
          mirror: widget.mirror,
          drawGuide: !_avatar,
        ),
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Tooltip(
            message: widget.allowAvatarSelection
                ? '누르면 화면 전환 · 길게 누르면 아바타 선택'
                : '누르면 화면 전환 · 이번 경기의 아바타는 고정',
            child: TextButton.icon(
              key: const Key('avatarCameraToggle'),
              onPressed: () => setState(() => _avatar = !_avatar),
              onLongPress: widget.allowAvatarSelection ? _chooseAvatar : null,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: .7),
                foregroundColor: Colors.white,
              ),
              icon: Icon(_avatar ? Icons.videocam : Icons.accessibility_new),
              label: Text(_avatar ? '카메라 보기' : '아바타 보기'),
            ),
          ),
        ),
      ),
    ],
  );
}

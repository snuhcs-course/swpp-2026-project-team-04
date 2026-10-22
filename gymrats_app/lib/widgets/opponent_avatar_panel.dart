import 'package:flutter/material.dart';

import '../models/avatar_model.dart';
import '../models/pose_frame.dart';
import 'pose_avatar_view.dart';

/// Remote coordinates render a bundled avatar. No camera/URL/video widget.
class OpponentAvatarPanel extends StatefulWidget {
  const OpponentAvatarPanel({
    super.key,
    required this.name,
    required this.model,
    this.frame,
    this.connected = true,
    this.avatarBuilder,
  });
  final String name;
  final AvatarModel model;
  final PoseFrame? frame;
  final bool connected;
  final Widget Function(PoseFrame? frame, AvatarModel model)? avatarBuilder;
  @override
  State<OpponentAvatarPanel> createState() => _OpponentAvatarPanelState();
}

class _OpponentAvatarPanelState extends State<OpponentAvatarPanel> {
  double _aspect = 3 / 4;
  @override
  Widget build(BuildContext context) {
    final frame = widget.frame;
    if (frame != null && frame.imageHeight > 0) {
      _aspect = (frame.imageWidth / frame.imageHeight).clamp(.1, 10);
    }
    return ColoredBox(
      color: const Color(0xff182131),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _aspect,
              child:
                  widget.avatarBuilder?.call(frame, widget.model) ??
                  PoseAvatarView(
                    frame: frame,
                    mirror: false,
                    model: widget.model,
                  ),
            ),
          ),
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '상대 · ${widget.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  widget.connected
                      ? (frame?.hasPerson == true ? 'LIVE' : '자세 대기')
                      : '재연결 대기',
                  style: TextStyle(
                    color: widget.connected ? Colors.greenAccent : Colors.amber,
                    fontSize: 12,
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

import 'package:flutter/material.dart';

import '../models/arcade_catalog.dart';
import '../models/arcade_stage.dart';
import '../models/character_rig.dart';
import '../screens/hold_stage_screen.dart';
import '../services/arcade/arcade_progress_store.dart';
import '../theme/app_theme.dart';
import '../widgets/gym_background_art.dart';

/// Opens a hold stage by its number on the phone, before the arcade (P16)
/// links to it (arcade hold spec 7):
/// `flutter run -t lib/demo/hold_stage_demo.dart`.
///
/// The stars go to an in-memory store for a demo account and show beside
/// each stage; the chair pose's stages wait for A5.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // As the app will at start-up (A3): every drawing's paths at once.
  GymArt.warmUp();
  runApp(
    MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const HoldStageDemo(),
    ),
  );
}

class HoldStageDemo extends StatefulWidget {
  const HoldStageDemo({super.key});

  @override
  State<HoldStageDemo> createState() => _HoldStageDemoState();
}

class _HoldStageDemoState extends State<HoldStageDemo> {
  static const _account = 1;
  final _store = MemoryArcadeProgressStore();
  final Map<int, int> _stars = {};
  HoldStageExit? _lastExit;
  String _character = CharacterRig.defaultId;

  Future<void> _open(int stage) async {
    final exit = await Navigator.push<HoldStageExit>(
      context,
      MaterialPageRoute(
        builder: (_) => HoldStageScreen(
          stage: stage,
          myCharacter: _character,
          progressStore: _store,
          accountId: _account,
        ),
      ),
    );
    final progress = await _store.read(_account);
    if (!mounted) return;
    setState(() {
      _lastExit = exit;
      _stars[stage] = progress.bestOf(stage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final holds = ArcadeCatalog.stages.whereType<ArcadeHoldStage>();
    return Scaffold(
      appBar: AppBar(title: const Text('Hold stage demo')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Character'),
            trailing: DropdownButton<String>(
              value: _character,
              items: [
                for (final art in CharacterRig.standard.selectable)
                  DropdownMenuItem(value: art.id, child: Text(art.name)),
              ],
              onChanged: (id) => setState(() => _character = id ?? _character),
            ),
          ),
          for (final stage in holds)
            ListTile(
              title: Text(
                'STAGE ${stage.number} · ${stage.floor}F · ${stage.pose.label}',
              ),
              subtitle: Text(
                '${stage.starSeconds.join(' / ')} s · best '
                '${_stars[stage.number] ?? 0} stars',
              ),
              enabled: stage.pose == HoldPose.plank,
              onTap: () => _open(stage.number),
            ),
          if (_lastExit != null)
            ListTile(title: Text('Last exit: ${_lastExit!.name}')),
        ],
      ),
    );
  }
}

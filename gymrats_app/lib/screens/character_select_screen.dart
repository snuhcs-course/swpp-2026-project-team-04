import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character_rig.dart';
import '../theme/app_theme.dart';
import '../viewmodels/character_select_viewmodel.dart';
import '../viewmodels/character_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/character_figure.dart';
import '../widgets/grid_background.dart';

/// 캐릭터 선택 (W3 spec 7, ChSelectB): the picked character idling large
/// over a floor, its name on a slanted band, the five characters as cells,
/// and "이 캐릭터로 하기", which saves the pick and goes back. Back goes back
/// without saving. Opened from 게임 시작's 캐릭터 row and 환경설정.
class CharacterSelectScreen extends StatefulWidget {
  const CharacterSelectScreen({super.key, this.createViewModel});

  /// Defaults to one on the app's [CharacterViewModel].
  final CharacterSelectViewModel Function()? createViewModel;

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  late final CharacterSelectViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        CharacterSelectViewModel(account: context.read<CharacterViewModel>());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// Saves the pick and goes back, once: a second tap while saving does
  /// nothing, and a page that was left meanwhile (system back) is not
  /// left twice.
  Future<void> _confirm() async {
    if (_viewModel.saving) return;
    await _viewModel.confirm();
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final picked = _viewModel.selectedArt;
            return Column(
              children: [
                const _Header(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _Preview(
                          art: picked,
                          caption: _viewModel.captionOf(picked),
                        ),
                        _Cells(
                          options: _viewModel.options,
                          selected: _viewModel.selected,
                          onSelect: _viewModel.select,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    0,
                    AppSpacing.s16,
                    AppSpacing.s20,
                  ),
                  child: AccentButton(title: '이 캐릭터로 하기', onPressed: _confirm),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The back button and "캐릭터 선택".
class _Header extends StatelessWidget {
  const _Header();

  static const _buttonSize = 44.0;
  static const _buttonEdge = 1.5;
  static const _arrowSize = 22.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back_rounded, size: _arrowSize),
            style: IconButton.styleFrom(
              fixedSize: const Size.square(_buttonSize),
              minimumSize: const Size.square(_buttonSize),
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.ink,
              shape: const CircleBorder(
                side: BorderSide(color: AppColors.ink, width: _buttonEdge),
              ),
            ),
          ),
          // With the button's 2 px around its circle, the design's 10.
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                '캐릭터 선택',
                style: Theme.of(context).textTheme.characterTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The picked character in my color at 1.5 times, idling with its feet on
/// a lime floor, over the stage's grid; its name and line at the top left.
class _Preview extends StatelessWidget {
  const _Preview({required this.art, required this.caption});

  final CharacterArt art;
  final String caption;

  static const _height = 300.0;
  static const _edge = 3.0;
  static const _scale = 1.5;

  /// The feet's height in the preview, inside its top edge.
  static const _feetY = 246.0;
  static const _floorSize = Size(192, 18);
  static const _floorTop = 244.0;
  static const _bandTop = 14.0;

  @override
  Widget build(BuildContext context) {
    final rig = CharacterRig.standard;
    return Container(
      height: _height,
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.ink, width: _edge),
        ),
      ),
      child: GridBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final middle = constraints.maxWidth / 2;
            return Stack(
              children: [
                Positioned(
                  left: AppSpacing.s16,
                  top: _bandTop,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NameBand(name: art.name),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        caption,
                        style: Theme.of(context).textTheme.characterCaption,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: middle - _floorSize.width / 2,
                  top: _floorTop,
                  width: _floorSize.width,
                  height: _floorSize.height,
                  child: const DecoratedBox(
                    decoration: ShapeDecoration(
                      color: AppColors.accent,
                      shape: StadiumBorder(
                        side: BorderSide(color: AppColors.ink, width: _edge),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: middle - rig.anchorX * _scale,
                  top: _feetY - rig.anchorY * _scale,
                  child: ExcludeSemantics(
                    child: CharacterIdleFigure(
                      key: ValueKey(art.id),
                      characterId: art.id,
                      scale: _scale,
                    ),
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

/// The name on a white band slanted like the stage's, with an ink edge.
class _NameBand extends StatelessWidget {
  const _NameBand({required this.name});

  final String name;

  static const _edge = 3.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Transform(
            transform: AppHighlight.battleSlant,
            alignment: Alignment.center,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.ink, width: _edge),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Text(
            name,
            maxLines: 1,
            style: Theme.of(context).textTheme.characterName,
          ),
        ),
      ],
    );
  }
}

/// The five characters, three to a row; the picked one lime with a
/// thicker edge.
class _Cells extends StatelessWidget {
  const _Cells({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<CharacterArt> options;
  final String selected;
  final ValueChanged<String> onSelect;

  static const _height = 124.0;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.s16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.s8,
        crossAxisSpacing: AppSpacing.s8,
        mainAxisExtent: _height,
      ),
      children: [
        for (final art in options)
          _Cell(
            art: art,
            picked: art.id == selected,
            onTap: () => onSelect(art.id),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.art, required this.picked, required this.onTap});

  final CharacterArt art;
  final bool picked;
  final VoidCallback onTap;

  static const _pickedEdge = 3.0;
  static const _edge = 1.5;

  static const _scale = 0.56;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: picked,
      label: '${art.name}, ${art.species}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: picked ? AppColors.accent : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
          side: BorderSide(
            color: AppColors.ink,
            width: picked ? _pickedEdge : _edge,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // The edge is drawn over the cell, so the picture stays put
            // when it thickens.
            padding: const EdgeInsets.only(top: AppSpacing.s12),
            child: Column(
              children: [
                CharacterFigure(characterId: art.id, scale: _scale),
                const SizedBox(height: AppSpacing.s4),
                // The rest of the cell: a large text size shrinks the name
                // into it instead of overflowing.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s4,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: Text(
                        art.name,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.characterCellName,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

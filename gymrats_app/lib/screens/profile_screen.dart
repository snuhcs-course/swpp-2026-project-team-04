import 'package:flutter/material.dart';

import '../models/avatar_model.dart';
import '../services/auth/auth_repository.dart';
import '../services/user/avatar_store.dart';
import '../theme/app_theme.dart';
import '../widgets/grid_background.dart';
import '../widgets/pose_avatar_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.auth,
    required this.avatars,
    this.previewBuilder,
  });
  final AuthRepository auth;
  final AvatarStore avatars;
  final Widget Function(AvatarModel)? previewBuilder;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AvatarModel _selected = AvatarModel.astronaut;
  bool _loading = true, _saving = false;
  bool _loadFailed = false;
  String? _error;
  String _category = '전체', _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.auth.session?.account;
    if (account == null) {
      setState(() {
        _loading = false;
        _error = '로그인이 필요해요.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _loadFailed = false;
    });
    try {
      final avatar = await widget.avatars.read(account.id);
      if (!mounted || widget.auth.session?.account.id != account.id) return;
      setState(() {
        _selected = avatar;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _error = '아바타 설정을 불러오지 못했어요.';
        });
      }
    }
  }

  Future<void> _select(AvatarModel? avatar) async {
    final account = widget.auth.session?.account;
    if (avatar == null || account == null || _loading || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.avatars.write(account.id, avatar);
      if (!mounted || widget.auth.session?.account.id != account.id) return;
      setState(() {
        _selected = avatar;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('저장했어요. 다음 온라인 대결에 적용됩니다.')),
        );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('저장하지 못했어요. 다시 선택해주세요.')),
          );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.auth.session?.account;
    final categories = [
      '전체',
      ...AvatarModel.values.map((a) => a.category).toSet(),
    ];
    final matches = AvatarModel.values
        .where(
          (a) =>
              (_category == '전체' || a.category == _category) &&
              '${a.label} ${a.assetName} ${a.category}'.toLowerCase().contains(
                _query.trim().toLowerCase(),
              ),
        )
        .toList();
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('프로필')),
        body: GridBackground(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      account?.nickname ?? '로그인이 필요해요.',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (account != null)
                      Text(
                        account.loginId,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      '내 아바타',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '온라인 대결에서 상대에게 보일 모습이에요.\n선택하면 이 기기의 현재 계정에 저장돼요.',
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 220,
                        child:
                            widget.previewBuilder?.call(_selected) ??
                            PoseAvatarView(
                              key: ValueKey(_selected),
                              mirror: false,
                              model: _selected,
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '총 ${AvatarModel.values.length}종 · 선택: ${_selected.label}',
                      style: const TextStyle(color: AppColors.accent),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '아바타 검색',
                        prefixIcon: Icon(Icons.search),
                        hintText: '이름 · 스타일로 찾아보세요',
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final category in categories)
                          ChoiceChip(
                            label: Text(category),
                            selected: _category == category,
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (matches.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('검색 결과가 없어요. 다른 이름이나 분류를 선택해주세요.'),
                      ),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.warning),
                      ),
                      TextButton(
                        onPressed: _saving ? null : _load,
                        child: const Text('다시 불러오기'),
                      ),
                    ],
                    RadioGroup<AvatarModel>(
                      groupValue: _selected,
                      onChanged: _select,
                      child: Column(
                        children: [
                          for (final avatar in matches)
                            Card(
                              child: RadioListTile<AvatarModel>(
                                value: avatar,
                                title: Text(avatar.label),
                                subtitle: Text(
                                  '${avatar.category} · ${avatar.credit}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                enabled:
                                    account != null && !_saving && !_loadFailed,
                                secondary: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    avatar.thumbnailPath,
                                    width: 56,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    cacheWidth: 128,
                                    semanticLabel: '${avatar.label} 미리보기',
                                    errorBuilder: (_, _, _) => const SizedBox(
                                      width: 56,
                                      height: 64,
                                      child: Icon(Icons.person_outline),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_saving) const LinearProgressIndicator(),
                  ],
                ),
        ),
      ),
    );
  }
}

enum AvatarModel {
  astronaut('avatar_01', 'astronaut', 'Astronaut'),
  robot('avatar_02', 'robot', 'Corebreaker Robot'),
  mannequiny('avatar_03', 'mannequiny', 'GDQuest Mannequiny'),
  humanoid('avatar_04', 'xcvg', 'XCVG Humanoid'),
  streetCrew('avatar_05', 'kenney_criminalmalea', '스트리트 크루', '스트리트'),
  cyborg('avatar_06', 'kenney_cyborgfemalea', '사이보그', '스트리트'),
  skaterFemale('avatar_07', 'kenney_skaterfemalea', '스케이터 F', '스트리트'),
  skaterMale('avatar_08', 'kenney_skatermalea', '스케이터 M', '스트리트'),
  retroFemale('avatar_09', 'kenney_humanfemalea', '레트로 러너 F', '레트로'),
  retroMale('avatar_10', 'kenney_humanmalea', '레트로 러너 M', '레트로'),
  retroZombieFemale('avatar_11', 'kenney_zombiefemalea', '레트로 좀비 F', '레트로'),
  retroZombieMale('avatar_12', 'kenney_zombiemalea', '레트로 좀비 M', '레트로'),
  survivorFemale('avatar_13', 'kenney_survivorfemalea', '서바이버 F', '서바이벌'),
  survivorMale('avatar_14', 'kenney_survivormaleb', '서바이버 M', '서바이벌'),
  zombieA('avatar_15', 'kenney_zombiea', '좀비 워커', '서바이벌'),
  zombieC('avatar_16', 'kenney_zombiec', '좀비 러너', '서바이벌'),
  knight('avatar_17', 'kaykit_knight', '나이트', '판타지'),
  barbarian('avatar_18', 'kaykit_barbarian', '바바리안', '판타지'),
  mage('avatar_19', 'kaykit_mage', '메이지', '판타지'),
  rogue('avatar_20', 'kaykit_rogue', '로그', '판타지'),
  hoodedRogue('avatar_21', 'kaykit_rogue_hooded', '후드 로그', '판타지'),
  skeletonMage('avatar_22', 'kaykit_skeleton_mage', '스켈레톤 메이지', '스켈레톤'),
  skeletonMinion('avatar_23', 'kaykit_skeleton_minion', '스켈레톤 미니언', '스켈레톤'),
  skeletonRogue('avatar_24', 'kaykit_skeleton_rogue', '스켈레톤 로그', '스켈레톤'),
  skeletonWarrior('avatar_25', 'kaykit_skeleton_warrior', '스켈레톤 워리어', '스켈레톤');

  const AvatarModel(
    this.protocolId,
    this.assetName,
    this.label, [
    this.category = '오리지널',
  ]);
  final String protocolId;
  final String assetName;
  final String label;
  final String category;
  String get assetPath => 'assets/avatar/models/$assetName.glb';
  String get thumbnailPath => 'assets/avatar/thumbnails/$assetName.png';
  String get credit => assetName.startsWith('kenney_')
      ? 'Kenney · CC0'
      : assetName.startsWith('kaykit_')
      ? 'Kay Lousberg · CC0'
      : this == AvatarModel.mannequiny
      ? 'GDQuest · CC BY 4.0'
      : 'CC0';
}

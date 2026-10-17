enum AvatarModel {
  astronaut('avatar_01', 'astronaut', 'Astronaut'),
  robot('avatar_02', 'robot', 'Corebreaker Robot'),
  mannequiny('avatar_03', 'mannequiny', 'GDQuest Mannequiny'),
  humanoid('avatar_04', 'xcvg', 'XCVG Humanoid');

  const AvatarModel(this.protocolId, this.assetName, this.label);
  final String protocolId;
  final String assetName;
  final String label;
  String get assetPath => 'assets/avatar/models/$assetName.glb';
}

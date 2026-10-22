import 'match_record.dart';

/// One page of the user's battles, newest first.
class MatchPage {
  const MatchPage({required this.items, this.nextCursor});

  final List<MatchRecord> items;

  /// Pass to the next fetch for the older battles; null on the last page.
  final String? nextCursor;
}

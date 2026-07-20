/// What kind of room this is.
enum RoomKind {
  normal,

  /// Exactly one Riftborn plus limited support, under a crimson arena border
  /// and a musical stinger. From chapter 3.
  elite,

  /// A **sink**, not a source (docs/14 §14.6). The push-or-bank decision.
  shrine,

  /// Stage 20 only.
  boss,
}

/// One room's place in a stage.
class RoomSlot {
  const RoomSlot({required this.index, required this.kind});

  /// Zero-based position within the stage.
  final int index;

  final RoomKind kind;

  /// Gold share of the stage's payout (docs/14 §14.6).
  ///
  /// A Shrine pays nothing because it *is* the payment — it is where a player
  /// spends, and giving it a share would make the decision free.
  double get goldShare => switch (kind) {
        RoomKind.normal => 0.10,
        RoomKind.elite => 0.22,
        RoomKind.boss => 0.30,
        RoomKind.shrine => 0.0,
      };

  double get materialMultiplier => switch (kind) {
        RoomKind.normal => 1.0,
        RoomKind.elite => 2.5,
        RoomKind.boss => 4.0,
        RoomKind.shrine => 0.0,
      };
}

/// The shape of one stage, before any room is generated.
///
/// docs/14 §14.2:
/// ```
/// rooms  = 6 + floor(c / 3)          // 6 at ch.1, 10 at ch.12
/// elite  = at room ceil(rooms * 0.6) // from chapter 3
/// shrine = after room 4              // from chapter 2
/// boss   = stage 20 only
/// seed   = hash(playerId, chapter, stage, attemptSalt)
/// ```
///
/// **The `attemptSalt` is the important part.** It changes per attempt, so a
/// retry is a *different* run rather than the same one again. Replaying an
/// identical failed room is demoralising; replaying a fresh version of the same
/// challenge is a second chance.
class StageBlueprint {
  StageBlueprint({
    required this.chapter,
    required this.stage,
    required this.seed,
    required this.rooms,
  });

  /// Builds a stage's layout.
  factory StageBlueprint.forStage({
    required int chapter,
    required int stage,
    required int seed,
  }) {
    final int count = roomCount(chapter);
    final int eliteAt = eliteIndex(chapter, count);
    final int shrineAt = shrineIndex(chapter);
    final bool isBossStage = stage % stagesPerChapter == 0;

    final List<RoomSlot> rooms = <RoomSlot>[];
    for (int i = 0; i < count; i++) {
      RoomKind kind = RoomKind.normal;
      if (i == eliteAt) {
        kind = RoomKind.elite;
      } else if (i == shrineAt) {
        kind = RoomKind.shrine;
      }
      rooms.add(RoomSlot(index: i, kind: kind));
    }

    // The boss replaces the final room rather than being appended: a stage that
    // grew by one room on boss stages would make the Vigor cost and the gold
    // share of every other room inconsistent.
    if (isBossStage) {
      rooms[rooms.length - 1] =
          RoomSlot(index: rooms.length - 1, kind: RoomKind.boss);
    }

    return StageBlueprint(
      chapter: chapter,
      stage: stage,
      seed: seed,
      rooms: List<RoomSlot>.unmodifiable(rooms),
    );
  }

  static const int stagesPerChapter = 20;

  /// Elites appear from chapter 3, Shrines from chapter 2 (docs/14 §14.2).
  static const int firstEliteChapter = 3;
  static const int firstShrineChapter = 2;

  final int chapter;
  final int stage;

  /// `hash(playerId, chapter, stage, attemptSalt)`. Two players on the same
  /// stage get different rooms; the same player retrying gets different rooms
  /// again.
  final int seed;

  final List<RoomSlot> rooms;

  int get roomTotal => rooms.length;

  bool get hasBoss => rooms.any((RoomSlot r) => r.kind == RoomKind.boss);

  /// Global stage index, 1-based — the input to every balance curve.
  int get globalStage => (chapter - 1) * stagesPerChapter + stage;

  static int roomCount(int chapter) => 6 + chapter ~/ 3;

  static int eliteIndex(int chapter, int count) {
    if (chapter < firstEliteChapter) return -1;
    // ceil(rooms * 0.6), zero-based.
    return ((count * 0.6).ceil() - 1).clamp(0, count - 1);
  }

  static int shrineIndex(int chapter) => chapter < firstShrineChapter ? -1 : 4;

  /// Combines the run's identity into a seed.
  ///
  /// FNV-1a rather than `Object.hash`: Dart's hash is explicitly not stable
  /// across runs or versions, and a stage that regenerated differently after an
  /// app update would break both replays and the "retry is a fresh room, but
  /// the *same* retry is the same room" promise.
  static int seedFor({
    required String playerId,
    required int chapter,
    required int stage,
    required int attemptSalt,
  }) {
    int hash = 0x811C9DC5;
    void mix(int value) {
      for (int shift = 0; shift < 32; shift += 8) {
        hash ^= (value >> shift) & 0xFF;
        hash = (hash * 0x01000193) & 0x7FFFFFFF;
      }
    }

    for (int i = 0; i < playerId.length; i++) {
      hash ^= playerId.codeUnitAt(i) & 0xFF;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    mix(chapter);
    mix(stage);
    mix(attemptSalt);

    return hash == 0 ? 0x1F2E3D4C : hash;
  }
}

/// Data-driven mascot registry. Swapping the active mascot swaps the entire
/// asset set (idle loop + poses) with zero code changes — everything is
/// resolved from the mascot ID and the standard folder layout:
///
///   assets/mascots/[id]/master.png
///   assets/mascots/[id]/pose_[pose].png
///   assets/mascots/[id]/idle/frame_NN.png   (optional sprite loop)
library;

import 'dart:io';

import 'package:flutter/services.dart';

import '../theme/tokens.dart';

enum MascotPose { idle, proud, thoughtful, concerned, delighted, sleepy }

class MascotDef {
  const MascotDef({
    required this.id,
    required this.defaultName,
    required this.tagline,
    this.idleFrameCount = 0,
  });

  final String id;
  final String defaultName;
  final String tagline;

  /// Number of extracted idle-loop sprite frames; 0 means no sprite loop and
  /// the app falls back to a gentle code-driven breathing animation.
  final int idleFrameCount;

  String get masterAsset => 'assets/mascots/$id/master.png';
  String get dayMasterAsset => 'assets/mascots/$id/day/master.png';
  String poseAsset(MascotPose pose) =>
      pose == MascotPose.idle ? masterAsset : 'assets/mascots/$id/pose_${pose.name}.png';
  String dayPoseAsset(MascotPose pose) =>
      pose == MascotPose.idle ? dayMasterAsset : 'assets/mascots/$id/day/pose_${pose.name}.png';
  String idleFrameAsset(int index) =>
      'assets/mascots/$id/idle/frame_${index.toString().padLeft(2, '0')}.png';
  String dayIdleFrameAsset(int index) =>
      'assets/mascots/$id/day/idle/frame_${index.toString().padLeft(2, '0')}.png';
}

abstract final class MascotCatalog {
  static const granny = MascotDef(
    id: 'granny',
    defaultName: 'Livy',
    tagline: 'Raised a dozen babies. Remembers every one.',
    idleFrameCount: 16,
  );
  static const grandpa = MascotDef(
    id: 'grandpa',
    defaultName: 'Gus',
    tagline: 'Slow rocking chair, quick with a bottle.',
  );
  static const owl = MascotDef(
    id: 'owl',
    defaultName: 'Nox',
    tagline: 'Wide awake at 3am, so you don\'t have to be alone.',
  );
  static const robot = MascotDef(
    id: 'robot',
    defaultName: 'Beep',
    tagline: 'A gentle nanny unit with impeccable timing.',
  );

  static const List<MascotDef> all = [granny, grandpa, owl, robot];

  static MascotDef byId(String id) => all.firstWhere((m) => m.id == id, orElse: () => granny);
}

/// Checks which pose/frame assets actually shipped in the bundle so the UI can
/// gracefully fall back (pose → master, sprite loop → breathing animation)
/// if a specific generation was skipped or failed.
class MascotAssetResolver {
  MascotAssetResolver._();
  static final MascotAssetResolver instance = MascotAssetResolver._();

  Set<String>? _bundled;

  Future<void> warmUp() async {
    if (_bundled != null) return;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _bundled = manifest.listAssets().toSet();
    } catch (_) {
      _bundled = {};
    }
  }

  bool has(String asset) => _bundled?.contains(asset) ?? false;

  /// Day phase prefers the daylight art set, falling back gracefully to the
  /// night set (dusk + night both use the indigo originals).
  String resolvePose(MascotDef mascot, MascotPose pose) {
    if (LivyColors.phase == ThemePhase.day) {
      final day = mascot.dayPoseAsset(pose);
      if (has(day)) return day;
      if (has(mascot.dayMasterAsset)) return mascot.dayMasterAsset;
    }
    final wanted = mascot.poseAsset(pose);
    if (has(wanted)) return wanted;
    if (has(mascot.masterAsset)) return mascot.masterAsset;
    // Last-ditch fallback to the default mascot's master.
    return MascotCatalog.granny.masterAsset;
  }

  int availableIdleFrames(MascotDef mascot) {
    final day = LivyColors.phase == ThemePhase.day;
    var count = 0;
    while (has(day ? mascot.dayIdleFrameAsset(count) : mascot.idleFrameAsset(count))) {
      count++;
      if (count > 64) break;
    }
    return count;
  }

  /// Resolves an idle frame path for the current phase.
  String idleFrame(MascotDef mascot, int index) =>
      LivyColors.phase == ThemePhase.day && has(mascot.dayIdleFrameAsset(index))
          ? mascot.dayIdleFrameAsset(index)
          : mascot.idleFrameAsset(index);

  /// For icons/illustrations: inserts a 'day/' folder segment when the day
  /// palette is active and that variant shipped, e.g.
  /// assets/icons/icon_bottle.png → assets/icons/day/icon_bottle.png.
  String adaptive(String path) {
    if (LivyColors.phase != ThemePhase.day) return path;
    final i = path.lastIndexOf('/');
    final candidate = '${path.substring(0, i)}/day${path.substring(i)}';
    return has(candidate) ? candidate : path;
  }
}

/// True when running in an environment where haptics exist (iOS/Android).
bool get supportsHaptics => Platform.isIOS || Platform.isAndroid;

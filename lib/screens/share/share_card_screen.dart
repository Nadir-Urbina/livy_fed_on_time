import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_state.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot_view.dart';

/// Opt-in share card: Livy + a stat, rendered over the generated night-sky
/// art and exported as a PNG sized for social. Never automatic.
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key});

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _cardKey = GlobalKey();
  int _statIndex = 0;
  bool _sharing = false;

  List<({String big, String small})> _stats(AppState app) {
    final b = app.bundle!;
    return [
      (big: '${b.feeds.length}', small: 'feeds logged together'),
      (big: '${b.streaks.onTimeStreakDays}', small: 'days fed right on time'),
      (big: '${b.streaks.tagTeamStreakDays}', small: 'days of tag-team care'),
      (big: '${b.badges.length}', small: 'badges earned so far'),
    ];
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/livy_share_card.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'Fed on time, together 🍼 — tracked with Livy',
      ));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.bundle == null) return const SizedBox.shrink();
    final stats = _stats(app);
    final stat = stats[_statIndex % stats.length];

    return Scaffold(
      appBar: AppBar(title: const Text('Share a moment')),
      body: ListView(
        padding: const EdgeInsets.all(LivySpace.lg),
        children: [
          RepaintBoundary(
            key: _cardKey,
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(LivyRadius.lg),
                  color: LivyColors.night,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/art/share_bg.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [LivyColors.night, LivyColors.surfaceRaised],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(LivySpace.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          MascotView(mascot: app.mascot, size: 150),
                          const SizedBox(height: LivySpace.md),
                          Text(stat.big,
                              style: LivyType.display(
                                  size: 64, color: LivyColors.amber)),
                          Text(stat.small,
                              textAlign: TextAlign.center,
                              style: LivyType.body(size: 18, weight: FontWeight.w700)),
                          const SizedBox(height: LivySpace.sm),
                          Text(app.bundle!.household.baby.name,
                              style: LivyType.body(
                                  size: 14, color: LivyColors.mist)),
                          const SizedBox(height: LivySpace.lg),
                          Text('LIVY — FED ON TIME',
                              style: LivyType.label(
                                  size: 10, color: LivyColors.butter)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: LivySpace.md),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _statIndex++),
              icon: const Icon(Icons.cached_rounded, size: 18),
              label: const Text('Try another stat'),
            ),
          ),
          const SizedBox(height: LivySpace.sm),
          VoxelButton(
            label: _sharing ? 'Preparing…' : 'Share card',
            icon: Icons.ios_share_rounded,
            onPressed: _sharing ? null : _share,
          ),
          const SizedBox(height: LivySpace.sm),
          Text(
            'Sharing is always opt-in — nothing ever posts automatically.',
            textAlign: TextAlign.center,
            style: LivyType.body(size: 12, color: LivyColors.faint),
          ),
        ],
      ),
    );
  }
}

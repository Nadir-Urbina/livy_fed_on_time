import 'package:flutter/material.dart';

import '../data/health_sources.dart';
import '../legal_links.dart';
import '../screens/guide/sources_screen.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

/// Compact, tappable attributions shown directly beneath a piece of general
/// health information — "Sources: CDC · AAP · CDC ↗". Each chip opens the
/// primary document in the browser.
///
/// Anywhere Livy states general guidance rather than the household's own
/// logged data, one of these belongs immediately under it.
class InlineCitations extends StatelessWidget {
  const InlineCitations(
    this.citations, {
    super.key,
    this.label = 'Sources',
    this.compact = false,
  });

  final List<HealthCitation> citations;
  final String label;

  /// Drops the type down a size for dialogs and dense footers.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 11.0 : 12.0;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: LivySpace.xs,
      runSpacing: LivySpace.xs,
      children: [
        Text('$label:', style: LivyType.body(size: size, color: LivyColors.faint)),
        for (final c in citations) _CitationChip(citation: c, size: size),
      ],
    );
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip({required this.citation, required this.size});

  final HealthCitation citation;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(LivyRadius.pill),
      onTap: () => LegalLinks.open(citation.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              citation.publisher,
              style: LivyType.body(
                size: size,
                color: LivyColors.periwinkle,
                weight: FontWeight.w600,
              ).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: LivyColors.periwinkle.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.open_in_new_rounded,
                size: size, color: LivyColors.periwinkle),
          ],
        ),
      ),
    );
  }
}

/// One full citation, as listed on the sources screen: publisher, document
/// title, what it's cited for, and the link.
class CitationCard extends StatelessWidget {
  const CitationCard({super.key, required this.citation});

  final HealthCitation citation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LivySpace.sm),
      child: Semantics(
        link: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(LivyRadius.md),
          onTap: () => LegalLinks.open(citation.url),
          child: Container(
            padding: const EdgeInsets.all(LivySpace.md),
            decoration: BoxDecoration(
              color: LivyColors.surface,
              borderRadius: BorderRadius.circular(LivyRadius.md),
              border: Border.all(color: LivyColors.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(citation.publisher,
                          style: LivyType.label(size: 10, color: LivyColors.amber)),
                      const SizedBox(height: 2),
                      Text(citation.title,
                          style: LivyType.body(size: 15, weight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(citation.covers,
                          style: LivyType.body(size: 13, color: LivyColors.mist)),
                      const SizedBox(height: LivySpace.sm),
                      Text(
                        citation.url,
                        style: LivyType.body(size: 11, color: LivyColors.periwinkle)
                            .copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor:
                              LivyColors.periwinkle.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: LivySpace.sm),
                Icon(Icons.open_in_new_rounded,
                    size: 18, color: LivyColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Where this comes from" — the standing route into the full source list.
class SourcesLink extends StatelessWidget {
  const SourcesLink({super.key, this.label = 'Where this comes from'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(LivyRadius.sm),
      onTap: () => SourcesScreen.open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 14, color: LivyColors.periwinkle),
            const SizedBox(width: 4),
            Text(
              label,
              style: LivyType.body(
                size: 12,
                color: LivyColors.periwinkle,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

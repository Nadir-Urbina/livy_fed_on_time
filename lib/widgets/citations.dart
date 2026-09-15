import 'package:flutter/material.dart';

import '../data/health_sources.dart';
import '../legal_links.dart';
import '../screens/guide/sources_screen.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

/// Opens the document behind a citation.
///
/// A citation that silently fails to open reads, to anyone checking, like no
/// citation at all — so when every launch mode is refused the URL is put on
/// screen instead, where it can still be read and typed out.
Future<void> openCitation(BuildContext context, HealthCitation citation) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final opened = await LegalLinks.open(citation.url);
  if (opened || messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 10),
      content: Text(
        'Couldn\'t open the browser. The source is '
        '${citation.publisher} — ${citation.title}: ${citation.url}',
      ),
    ),
  );
}

/// Compact, tappable attributions shown directly beneath a piece of general
/// health information — "Sources: CDC · AAP · CDC ↗". Each chip opens the
/// primary document in the browser.
///
/// Use this as a supplement, not as a screen's only citation: an abbreviation
/// in small type is easy to overlook. Where a screen states general guidance,
/// [SourcesPanel] carries the references in full.
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
      onTap: () => openCitation(context, citation),
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

/// One reference, written out the way a reference should be: who published it,
/// what the document is called, and the link itself in plain sight.
///
/// The URL is rendered as text rather than hidden behind a word, so the
/// citation is legible as a citation before anyone taps anything.
class CitationReference extends StatelessWidget {
  const CitationReference({super.key, required this.citation});

  final HealthCitation citation;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: '${citation.publisher}. ${citation.title}. Opens ${citation.url}',
      child: InkWell(
        borderRadius: BorderRadius.circular(LivyRadius.sm),
        onTap: () => openCitation(context, citation),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.link_rounded,
                    size: 14, color: LivyColors.periwinkle),
              ),
              const SizedBox(width: LivySpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${citation.publisher} — ${citation.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LivyType.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: LivyColors.periwinkle,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      citation.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LivyType.body(size: 11, color: LivyColors.faint)
                          .copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor:
                            LivyColors.faint.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LivySpace.xs),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.open_in_new_rounded,
                    size: 14, color: LivyColors.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The citations for one claim, carried in full and impossible to mistake for
/// decoration: a heading with the word "Sources", the references written out
/// with their links, and the route into the complete list.
///
/// App Store guideline 1.4.1 asks that citations be easy for the user to find.
/// That means this panel sits *above* a screen's primary action, next to the
/// guidance it backs — never tucked in below the button, where nobody scrolls.
class SourcesPanel extends StatelessWidget {
  const SourcesPanel({
    super.key,
    required this.citations,
    this.title = 'Sources for this information',
    this.blurb,
    this.showAllSourcesLink = true,
  });

  final List<HealthCitation> citations;
  final String title;

  /// Optional line naming what these sources are cited for.
  final String? blurb;

  final bool showAllSourcesLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LivySpace.md),
      decoration: BoxDecoration(
        color: LivyColors.surfaceSunken,
        borderRadius: BorderRadius.circular(LivyRadius.md),
        border: Border.all(color: LivyColors.periwinkle.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded,
                  size: 16, color: LivyColors.periwinkle),
              const SizedBox(width: LivySpace.sm),
              Expanded(
                child: Text(
                  title,
                  style: LivyType.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: LivyColors.periwinkle,
                  ),
                ),
              ),
            ],
          ),
          if (blurb != null) ...[
            const SizedBox(height: LivySpace.xs),
            Text(blurb!, style: LivyType.body(size: 12, color: LivyColors.mist)),
          ],
          const SizedBox(height: LivySpace.xs),
          for (final c in citations) CitationReference(citation: c),
          if (showAllSourcesLink) ...[
            const SizedBox(height: LivySpace.xs),
            const SourcesLink(label: 'All sources & references'),
          ],
        ],
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
          onTap: () => openCitation(context, citation),
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
            // Narrow phones ran this label off the edge of the sources panel.
            Flexible(
              child: Text(
                label,
                style: LivyType.body(
                  size: 12,
                  color: LivyColors.periwinkle,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

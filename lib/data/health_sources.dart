/// Citations for every piece of general health information Livy shows.
///
/// App Store guideline 1.4.1 requires that health or medical information carry
/// visible citations to its sources. Livy never diagnoses or prescribes, but
/// she does repeat general public-health guidance (when solids typically
/// start, how bottle amounts and intervals usually change, formula recalls) —
/// so every one of those statements points here, and every entry here is a
/// tappable link to the primary source.
///
/// Keep this the single place the URLs live. If a statement in the UI can't be
/// traced to an entry below, either cite it or don't make it.
class HealthCitation {
  const HealthCitation({
    required this.publisher,
    required this.title,
    required this.url,
    required this.covers,
  });

  /// Short attribution shown inline next to the claim, e.g. "CDC".
  final String publisher;

  /// The document's own title, as published.
  final String title;

  final String url;

  /// One line on what this source is being cited for — shown on the sources
  /// screen so a reader can tell why it's listed.
  final String covers;

  /// Host shown under the link, e.g. "cdc.gov".
  String get host => Uri.parse(url).host.replaceFirst('www.', '');
}

/// A titled set of citations — one topic Livy speaks about.
class HealthSourceGroup {
  const HealthSourceGroup({
    required this.topic,
    required this.blurb,
    required this.citations,
  });

  final String topic;
  final String blurb;
  final List<HealthCitation> citations;
}

abstract final class HealthSources {
  // ── Starting solids ───────────────────────────────────────────────────────
  static const cdcSolids = HealthCitation(
    publisher: 'CDC',
    title: 'When, What, and How to Introduce Solid Foods',
    url: 'https://www.cdc.gov/infant-toddler-nutrition/foods-and-drinks/'
        'when-what-and-how-to-introduce-solid-foods.html',
    covers: 'Solids starting at about 6 months, the readiness signs to look '
        'for, and introducing one single-ingredient food at a time.',
  );

  static const aapSolids = HealthCitation(
    publisher: 'AAP',
    title: 'Starting Solid Foods',
    url: 'https://www.healthychildren.org/English/ages-stages/baby/'
        'feeding-nutrition/Pages/Starting-Solid-Foods.aspx',
    covers: 'American Academy of Pediatrics guidance on when and how to begin '
        'solid foods, published on HealthyChildren.org.',
  );

  static const cdcChoking = HealthCitation(
    publisher: 'CDC',
    title: 'Choking Hazards',
    url: 'https://www.cdc.gov/infant-toddler-nutrition/foods-and-drinks/'
        'choking-hazards.html',
    covers: 'Foods and food shapes to avoid, and how to prepare first foods '
        'so they are safe to eat.',
  );

  // ── Bottles: amounts and intervals ────────────────────────────────────────
  static const cdcFormulaAmounts = HealthCitation(
    publisher: 'CDC',
    title: 'How Much and How Often to Feed Infant Formula',
    url: 'https://www.cdc.gov/infant-toddler-nutrition/formula-feeding/'
        'how-much-and-how-often.html',
    covers: 'How feed amounts rise and intervals stretch as a baby grows, and '
        'how formula and solids overlap from 6 to 12 months.',
  );

  static const aapFormulaSchedule = HealthCitation(
    publisher: 'AAP',
    title: 'Amount and Schedule of Baby Formula Feedings',
    url: 'https://www.healthychildren.org/English/ages-stages/baby/'
        'formula-feeding/Pages/Amount-and-Schedule-of-Formula-Feedings.aspx',
    covers: 'American Academy of Pediatrics guidance on typical formula '
        'amounts and feeding schedules by age.',
  );

  static const whoInfantFeeding = HealthCitation(
    publisher: 'WHO',
    title: 'Infant and young child feeding (fact sheet)',
    url: 'https://www.who.int/news-room/fact-sheets/detail/'
        'infant-and-young-child-feeding',
    covers: 'World Health Organization guidance on feeding through the first '
        'two years, for households outside the US.',
  );

  // ── Formula safety and recalls ────────────────────────────────────────────
  static const fdaRecalls = HealthCitation(
    publisher: 'FDA',
    title: 'Recalls, Market Withdrawals, & Safety Alerts',
    url: 'https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts',
    covers: 'The official US recall notices. Livy mirrors these; this page is '
        'the authority if the two ever disagree.',
  );

  static const openFdaApi = HealthCitation(
    publisher: 'openFDA',
    title: 'Food Enforcement Reports API',
    url: 'https://open.fda.gov/apis/food/enforcement/',
    covers: 'The exact feed Livy queries for the recall notices she shows.',
  );

  static const cdcFormulaPrep = HealthCitation(
    publisher: 'CDC',
    title: 'Infant Formula Preparation and Storage',
    url: 'https://www.cdc.gov/infant-toddler-nutrition/formula-feeding/'
        'preparation-and-storage.html',
    covers: 'Safe mixing, warming, and storage of prepared formula.',
  );

  // ── Grouped for display ───────────────────────────────────────────────────
  static const startingSolids = <HealthCitation>[
    cdcSolids,
    aapSolids,
    cdcChoking,
  ];

  static const bottleFeeding = <HealthCitation>[
    cdcFormulaAmounts,
    aapFormulaSchedule,
    whoInfantFeeding,
  ];

  static const formulaSafety = <HealthCitation>[
    fdaRecalls,
    openFdaApi,
    cdcFormulaPrep,
  ];

  static const groups = <HealthSourceGroup>[
    HealthSourceGroup(
      topic: 'Starting solid foods',
      blurb: 'Cited when Livy mentions the usual age for first foods, or asks '
          'whether meals have started.',
      citations: startingSolids,
    ),
    HealthSourceGroup(
      topic: 'Bottle amounts & intervals',
      blurb: 'Cited when Livy notes that feeds have stretched or amounts have '
          'shifted, and on the feeding schedule screen.',
      citations: bottleFeeding,
    ),
    HealthSourceGroup(
      topic: 'Formula safety & recalls',
      blurb: 'Where the recall notices come from, and how to prepare and '
          'store formula safely.',
      citations: formulaSafety,
    ),
  ];
}

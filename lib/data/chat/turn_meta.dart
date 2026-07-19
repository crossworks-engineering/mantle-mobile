/// Shared shapes for a turn's "thought" record — used both LIVE (the trail
/// accumulating in `ActiveTurn` from `status` events) and PERSISTED (the
/// `thoughts` / `toolStats` an outbound history row carries once the turn
/// lands, when the brain has trail-persistence on). Mirrors the web's
/// `ThoughtEvent` (`use-turn-stream.ts`) and `ToolOutcomeStatsRow`
/// (`apps/web/lib/assistant.ts`).
library;

/// One step in a turn's thought trail. Live steps carry a [stepId] so a later
/// narrated `status` event for the same step replaces the grounded line in
/// place; persisted rows drop the id (`{kind, label, elapsedMs}` only).
class ThoughtStep {
  const ThoughtStep({
    required this.kind,
    required this.label,
    this.elapsedMs,
    this.stepId,
  });

  /// Stable step id (live trail only) — the upsert key for grounded→narrated
  /// upgrades. Null on persisted rows.
  final String? stepId;

  /// Coarse bucket for the icon (web | compute | file | person | …). The
  /// producer's set is open-ended, so renderers map a few and default the rest.
  final String kind;

  /// The user-facing line ("Searching your brain…").
  final String label;

  /// Elapsed ms into the turn when this step started. Client-stamped on the
  /// live trail; preserved across an in-place upgrade (the step's start time
  /// doesn't change).
  final int? elapsedMs;

  /// Upgrade in place (a narrated line replacing the grounded one) — keeps
  /// [stepId] and the original [elapsedMs].
  ThoughtStep upgraded({required String label, required String kind}) =>
      ThoughtStep(stepId: stepId, kind: kind, label: label, elapsedMs: elapsedMs);

  /// Parse one persisted step; null when the minimal `label` is missing.
  static ThoughtStep? tryParse(Map<String, dynamic> j) {
    final label = j['label'];
    if (label is! String || label.isEmpty) return null;
    return ThoughtStep(
      kind: (j['kind'] as String?) ?? 'tool',
      label: label,
      elapsedMs: (j['elapsedMs'] as num?)?.toInt(),
    );
  }

  /// Parse a row's persisted `thoughts` list, defensively (absent → const []).
  static List<ThoughtStep> listFrom(Object? raw) {
    if (raw is! List || raw.isEmpty) return const [];
    final out = <ThoughtStep>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final step = tryParse(e.cast<String, dynamic>());
      if (step != null) out.add(step);
    }
    return out;
  }
}

/// One failed tool call inside [ToolStats.failures].
class ToolFailure {
  const ToolFailure({required this.slug, required this.error});
  final String slug;
  final String error;
}

/// The turn's deterministic tool-outcome tally — the runtime's own ledger,
/// persisted at finalize. Drives the "N tool calls · M failed" footer so the
/// record is independent of the reply's claims.
class ToolStats {
  const ToolStats({
    required this.calls,
    this.succeeded = 0,
    this.failed = 0,
    this.skipped = 0,
    this.queued = 0,
    this.failures = const [],
  });

  final int calls;
  final int succeeded;
  final int failed;
  final int skipped;

  /// Confirm-gated calls parked behind operator approval — not yet run.
  final int queued;
  final List<ToolFailure> failures;

  /// Parse a row's persisted `toolStats`, defensively. Null when absent or when
  /// `calls <= 0` (mirrors the web: a no-tool turn carries no tally).
  static ToolStats? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final calls = (j['calls'] as num?)?.toInt() ?? 0;
    if (calls <= 0) return null;
    final failures = <ToolFailure>[];
    final rawFailures = j['failures'];
    if (rawFailures is List) {
      for (final f in rawFailures) {
        if (f is! Map) continue;
        final slug = f['slug'];
        if (slug is! String || slug.isEmpty) continue;
        failures.add(ToolFailure(slug: slug, error: '${f['error'] ?? ''}'));
      }
    }
    return ToolStats(
      calls: calls,
      succeeded: (j['succeeded'] as num?)?.toInt() ?? 0,
      failed: (j['failed'] as num?)?.toInt() ?? 0,
      skipped: (j['skipped'] as num?)?.toInt() ?? 0,
      queued: (j['queued'] as num?)?.toInt() ?? 0,
      failures: failures,
    );
  }
}

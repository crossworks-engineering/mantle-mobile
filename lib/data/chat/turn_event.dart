import 'dart:convert';

/// The highest `TurnEvent` schema version this client understands. The server
/// bumps `v` (`TURN_EVENT_SCHEMA_VERSION` in `@mantle/client-types`) ONLY on a
/// breaking change to an existing event's shape — additive fields and new
/// types don't bump it — so an event with a higher `v` cannot be trusted to
/// parse correctly and the stream should end (see `ChatApi.streamTurn`).
const int kTurnEventSchemaVersion = 1;

/// One live event for a streaming turn, delivered over
/// `GET /api/assistant/turn/:id/stream` (Server-Sent Events). Mirrors
/// `TurnEvent` in `@mantle/client-types` — the same shape the web client
/// consumes. Every event is `{ v, turnId, seq, round, type, data }`; the `data`
/// payload varies by [type] (see the typed getters below).
///
/// The SSE frame is `id: <seq>\ndata: <event JSON>\n\n`. The `id:` line equals
/// [seq], which is also the `Last-Event-ID` resume cursor — so we read the
/// cursor straight off the parsed event and don't need the `id:` line.
class TurnEvent {
  const TurnEvent({
    required this.v,
    required this.turnId,
    required this.seq,
    required this.round,
    required this.type,
    required this.data,
  });

  /// Schema version (`TURN_EVENT_SCHEMA_VERSION` at emit time). Additive fields
  /// don't bump it; only a breaking change to an existing event's shape does.
  final int v;

  /// Durable turn id (the outbound `assistant_messages` id). Stable for the turn
  /// and equal to the client-minted idempotency-key.
  final String turnId;

  /// Monotonic per-turn sequence — the SSE `id:` and the resume cursor.
  final int seq;

  /// Tool-loop round this event belongs to (0 = before the first round). A new
  /// round resets the visible-reply buffer so only the final answer types out.
  final int round;

  /// Discriminator: `turn-start` | `status` | `reasoning-delta` | `text-delta`
  /// | `done` | `error` | `tool-start` | `tool-end`.
  final String type;

  /// The type-specific payload (see the getters below for the fields we read).
  final Map<String, dynamic> data;

  // ── Typed accessors for the fields this client consumes ───────────────────

  /// `text-delta` / `reasoning-delta`: a chunk of reply / reasoning text.
  String? get text => data['text'] as String?;

  /// `status`: the coarse "what it's doing now" line for the typing indicator.
  String? get label => data['label'] as String?;

  /// `status`: stable id for the step this status describes — two events
  /// sharing a stepId are the same step (grounded → narrated), so the trail
  /// upserts by it instead of appending a duplicate line.
  String? get stepId => data['stepId'] as String?;

  /// `status`: coarse bucket for the icon/theme (web | compute | file | …).
  String? get kind => data['kind'] as String?;

  /// `tool-start` / `tool-end`: the tool's name.
  String? get toolName => data['name'] as String?;

  /// `tool-start`: optional one-line, secret-free preview of the call.
  String? get toolSummary => data['summary'] as String?;

  /// `tool-end`: whether the call succeeded (`false` = it errored — the turn
  /// may still recover). Null on other event types.
  bool? get toolOk => data['ok'] as bool?;

  /// `done`: real output-token total for the whole turn, when the provider
  /// reported usage. The client swaps its streamed estimate for this.
  int? get tokensOut => (data['tokensOut'] as num?)?.toInt();

  /// `turn-start`: durable `assistant_messages` id of the reply row — the
  /// reconciliation handle for the finished turn.
  String? get outboundId => data['outboundId'] as String?;

  /// `turn-start`: durable id of the user (inbound) row.
  String? get inboundId => data['inboundId'] as String?;

  /// `turn-start`: resolved model id, when known at turn start.
  String? get model => data['model'] as String?;

  /// `error`: the failure reason.
  String? get message => data['message'] as String?;

  bool get isTextDelta => type == kTurnTextDelta;
  bool get isStatus => type == kTurnStatus;
  bool get isTurnStart => type == kTurnStart;
  bool get isDone => type == kTurnDone;
  bool get isError => type == kTurnError;

  /// Terminal events end the stream — the client reconciles to the durable row.
  bool get isTerminal => type == kTurnDone || type == kTurnError;

  /// True when the server emits a newer, breaking schema than this client
  /// speaks ([kTurnEventSchemaVersion]) — the event's payloads can't be
  /// trusted, so the consumer must stop streaming and fall back to the
  /// history reconcile (the same path as when streaming is dark).
  bool get isUnsupportedSchema => v > kTurnEventSchemaVersion;

  /// Build from the decoded `data:` JSON. Returns null when the minimal frame
  /// (a string `type` + `turnId` + a numeric `seq`) is missing or malformed.
  static TurnEvent? tryParse(Map<String, dynamic> json) {
    final type = json['type'];
    final turnId = json['turnId'];
    final seq = json['seq'];
    if (type is! String || type.isEmpty) return null;
    if (turnId is! String || turnId.isEmpty) return null;
    if (seq is! num) return null;
    final data = json['data'];
    return TurnEvent(
      v: (json['v'] as num?)?.toInt() ?? 1,
      turnId: turnId,
      seq: seq.toInt(),
      round: (json['round'] as num?)?.toInt() ?? 0,
      type: type,
      data: data is Map<String, dynamic>
          ? data
          : data is Map
              ? data.cast<String, dynamic>()
              : const {},
    );
  }
}

// Event `type` discriminators (mirrors `TurnEventType`).
const String kTurnStart = 'turn-start';
const String kTurnStatus = 'status';
const String kTurnToolStart = 'tool-start';
const String kTurnToolEnd = 'tool-end';
const String kTurnReasoningDelta = 'reasoning-delta';
const String kTurnTextDelta = 'text-delta';
const String kTurnDone = 'done';
const String kTurnError = 'error';

/// Parse one SSE line into a [TurnEvent]. Returns null for comments
/// (`: connected` / `: ping` heartbeats), `id:`/`event:` lines, blanks, and
/// malformed payloads. Pure (no I/O) so it's unit-testable; the cursor is read
/// off [TurnEvent.seq], so the `id:` line is intentionally ignored here.
TurnEvent? parseTurnSseLine(String line) {
  if (!line.startsWith('data:')) return null;
  final body = line.substring(5).trim();
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return TurnEvent.tryParse(decoded);
  } catch (_) {
    /* malformed payload — ignore this line */
  }
  return null;
}

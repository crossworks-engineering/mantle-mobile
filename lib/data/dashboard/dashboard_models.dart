/// Headline metrics from `GET /api/dashboard/summary` (mirrors Mantle's web
/// dashboard KPIs).
class DashboardSummary {
  const DashboardSummary({
    required this.spendLast7MicroUsd,
    required this.spendPrior7MicroUsd,
    required this.brainNodes,
    required this.entities,
    required this.edges,
    required this.facts,
    required this.vectorsTotal,
    required this.pendingCount,
  });

  final int spendLast7MicroUsd;
  final int spendPrior7MicroUsd;
  final int brainNodes;
  final int entities;
  final int edges;
  final int facts;
  final int vectorsTotal;
  final int pendingCount;

  /// 7-day spend in USD (cost is stored as micro-USD: 1e6 per dollar).
  double get spendLast7Usd => spendLast7MicroUsd / 1e6;

  /// Percent change vs the prior 7 days; `null` when there's no baseline.
  double? get spendTrendPct {
    if (spendPrior7MicroUsd <= 0) return null;
    return (spendLast7MicroUsd - spendPrior7MicroUsd) /
        spendPrior7MicroUsd *
        100;
  }

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => (v as num?)?.toInt() ?? 0;
    Map<String, dynamic> obj(Object? v) =>
        v is Map ? v.cast<String, dynamic>() : const {};
    final spend = obj(json['spend']);
    final brain = obj(json['brain']);
    final vectors = obj(json['vectors']);
    return DashboardSummary(
      spendLast7MicroUsd: asInt(spend['last7MicroUsd']),
      spendPrior7MicroUsd: asInt(spend['prior7MicroUsd']),
      brainNodes: asInt(brain['nodesTotal']),
      entities: asInt(brain['entitiesTotal']),
      edges: asInt(brain['edgesTotal']),
      facts: asInt(brain['factsTotal']),
      vectorsTotal: asInt(vectors['vectorsTotal']),
      pendingCount: asInt(json['pendingCount']),
    );
  }
}

/// A pragmatic subset of `GET /api/health` — just what the dashboard shows.
/// Everything is nullable: probes can time out (see [degraded]).
class ServerHealth {
  const ServerHealth({
    this.cpuPct,
    this.memPct,
    this.diskPct,
    this.postgresUp,
    this.embedderUp,
    this.networkUp,
    this.minioUp,
    this.degraded = const [],
  });

  final double? cpuPct;
  final double? memPct;
  final double? diskPct;
  final bool? postgresUp;
  final bool? embedderUp;
  final bool? networkUp;
  final bool? minioUp;
  final List<String> degraded;

  factory ServerHealth.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? v) => (v as num?)?.toDouble();
    Map<String, dynamic>? obj(Object? v) =>
        v is Map ? v.cast<String, dynamic>() : null;
    final host = obj(json['host']);
    final mem = obj(host?['mem']);
    final disk = obj(host?['disk']);
    return ServerHealth(
      cpuPct: asDouble(host?['cpuLoadPct']),
      memPct: asDouble(mem?['usedPct']),
      diskPct: asDouble(disk?['usedPct']),
      postgresUp: obj(json['postgres'])?['up'] as bool?,
      embedderUp: obj(json['embedder'])?['up'] as bool?,
      networkUp: obj(json['network'])?['up'] as bool?,
      minioUp: obj(json['storage'])?['minioUp'] as bool?,
      degraded: ((json['degraded'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// The dashboard's combined payload: required summary + best-effort health.
class DashboardData {
  const DashboardData({required this.summary, this.health});

  final DashboardSummary summary;
  final ServerHealth? health;
}

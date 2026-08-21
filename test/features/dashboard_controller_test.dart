// DashboardController: loads summary + (best-effort) health. Plus model parsing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/dashboard/dashboard_api.dart';
import 'package:jackdaw/data/dashboard/dashboard_models.dart';
import 'package:jackdaw/features/dashboard/dashboard_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockDashboardApi extends Mock implements DashboardApi {}

const _summary = DashboardSummary(
  spendLast7MicroUsd: 1250000,
  spendPrior7MicroUsd: 1000000,
  brainNodes: 2840,
  entities: 320,
  edges: 1240,
  facts: 520,
  vectorsTotal: 452,
  pendingCount: 3,
);

void main() {
  late MockDashboardApi api;
  setUp(() => api = MockDashboardApi());

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [dashboardApiProvider.overrideWithValue(api)],
    );
    addTearDown(c.dispose);
    // Keep the auto-dispose controller alive for the duration of the read.
    c.listen(dashboardControllerProvider, (_, _) {});
    return c;
  }

  test('loads summary and health', () async {
    when(() => api.summary()).thenAnswer((_) async => _summary);
    when(() => api.health()).thenAnswer(
      (_) async => const ServerHealth(cpuPct: 12, postgresUp: true),
    );

    final c = make();
    final data = await c.read(dashboardControllerProvider.future);

    expect(data.summary.pendingCount, 3);
    expect(data.health?.postgresUp, isTrue);
  });

  test('health failure falls back to null but summary still loads', () async {
    when(() => api.summary()).thenAnswer((_) async => _summary);
    when(() => api.health()).thenThrow(Exception('health down'));

    final c = make();
    final data = await c.read(dashboardControllerProvider.future);

    expect(data.summary.brainNodes, 2840);
    expect(data.health, isNull);
  });

  // Note: a summary failure surfaces as an AsyncError (build() doesn't catch it,
  // unlike health) — the dashboard then shows its error + Retry. That's riverpod
  // default behaviour; the health-failure test above covers the seam we own.

  group('models', () {
    test('DashboardSummary.fromJson + spend helpers', () {
      final s = DashboardSummary.fromJson({
        'spend': {'last7MicroUsd': 1250000, 'prior7MicroUsd': 1000000},
        'brain': {
          'nodesTotal': 2840,
          'entitiesTotal': 320,
          'edgesTotal': 1240,
          'factsTotal': 520,
        },
        'vectors': {'vectorsTotal': 452, 'nodesIndexed': 45, 'nodesTotal': 50},
        'pendingCount': 3,
      });
      expect(s.spendLast7Usd, 1.25);
      expect(s.spendTrendPct, 25);
      expect(s.brainNodes, 2840);
      expect(s.vectorsTotal, 452);
    });

    test('spendTrendPct is null without a baseline', () {
      const s = DashboardSummary(
        spendLast7MicroUsd: 500000,
        spendPrior7MicroUsd: 0,
        brainNodes: 0,
        entities: 0,
        edges: 0,
        facts: 0,
        vectorsTotal: 0,
        pendingCount: 0,
      );
      expect(s.spendTrendPct, isNull);
    });

    test('ServerHealth.fromJson parses nested vitals and tolerates gaps', () {
      final h = ServerHealth.fromJson({
        'host': {
          'cpuLoadPct': 34.2,
          'mem': {'usedPct': 25.0},
          'disk': {'usedPct': 40.0},
        },
        'postgres': {'up': true},
        'storage': {'minioUp': false},
        'degraded': ['storage.minio'],
      });
      expect(h.cpuPct, 34.2);
      expect(h.memPct, 25.0);
      expect(h.diskPct, 40.0);
      expect(h.postgresUp, isTrue);
      expect(h.minioUp, isFalse);
      expect(h.embedderUp, isNull); // absent → null
      expect(h.degraded, ['storage.minio']);
    });
  });
}

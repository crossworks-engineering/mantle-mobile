// AgentController: loads agents, defaults to the first, switches on select.
// Plus Agent model helpers (initials, deterministic accent).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/agents/agent.dart';
import 'package:jackdaw/data/agents/agent_api.dart';
import 'package:jackdaw/features/agents/agent_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockAgentApi extends Mock implements AgentApi {}

const _saskia = Agent(slug: 'saskia', name: 'Saskia');
const _pages = Agent(slug: 'pages', name: 'Pages');

void main() {
  late MockAgentApi api;
  setUp(() => api = MockAgentApi());

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [agentApiProvider.overrideWithValue(api)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('build loads agents and defaults active to the first', () async {
    when(() => api.list()).thenAnswer((_) async => [_saskia, _pages]);
    final c = make();

    final state = await c.read(agentControllerProvider.future);
    expect(state.agents, hasLength(2));
    expect(state.active?.slug, 'saskia');
    expect(c.read(activeAgentSlugProvider), 'saskia');
  });

  test('select switches the active agent', () async {
    when(() => api.list()).thenAnswer((_) async => [_saskia, _pages]);
    final c = make();
    await c.read(agentControllerProvider.future);

    c.read(agentControllerProvider.notifier).select('pages');
    expect(c.read(agentControllerProvider).value!.active?.slug, 'pages');
    expect(c.read(activeAgentSlugProvider), 'pages');
  });

  test('select ignores an unknown slug', () async {
    when(() => api.list()).thenAnswer((_) async => [_saskia, _pages]);
    final c = make();
    await c.read(agentControllerProvider.future);

    c.read(agentControllerProvider.notifier).select('nope');
    expect(c.read(agentControllerProvider).value!.active?.slug, 'saskia');
  });

  test('no agents → active is null (Mantle default)', () async {
    when(() => api.list()).thenAnswer((_) async => <Agent>[]);
    final c = make();

    final state = await c.read(agentControllerProvider.future);
    expect(state.agents, isEmpty);
    expect(state.active, isNull);
    expect(c.read(activeAgentSlugProvider), isNull);
  });

  group('Agent model', () {
    test('initials', () {
      expect(const Agent(slug: 'a', name: 'Saskia Handler').initials, 'SH');
      expect(const Agent(slug: 'a', name: 'Saskia').initials, 'SA');
      expect(const Agent(slug: 'a', name: 'x').initials, 'X');
      expect(const Agent(slug: 'a', name: '   ').initials, '?');
    });

    test('accent hue is in range and depends only on the slug', () {
      final hue = const Agent(slug: 'pages', name: 'One').accentHue;
      expect(hue, inInclusiveRange(0, 359));
      expect(const Agent(slug: 'pages', name: 'Two').accentHue, hue);
    });

    test('fromJson falls back to slug when name is missing', () {
      final a = Agent.fromJson({'slug': 'reflector'});
      expect(a.name, 'reflector');
      expect(a.role, isNull);
    });
  });
}

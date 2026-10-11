// AgentController: loads agents, defaults to the first, switches on select.
// Plus Agent model helpers (initials, deterministic accent).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/agents/agent.dart';
import 'package:jackdaw/data/agents/agent_api.dart';
import 'package:jackdaw/data/auth/login_access.dart';
import 'package:jackdaw/features/agents/agent_controller.dart';
import 'package:jackdaw/features/auth/login_access_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixed_access.dart';

class MockAgentApi extends Mock implements AgentApi {}

const _saskia = Agent(slug: 'saskia', name: 'Saskia');
const _pages = Agent(slug: 'pages', name: 'Pages');

void main() {
  late MockAgentApi api;
  setUp(() {
    api = MockAgentApi();
    // Default: the server has no opinion (old route / failed call), so the
    // controller keeps its pre-v1.12 behaviour. Individual tests override.
    when(() => api.threadInfo()).thenAnswer((_) async => null);
  });

  ProviderContainer make({LoginAccess access = adminAccess}) {
    final c = ProviderContainer(
      overrides: [
        agentApiProvider.overrideWithValue(api),
        loginAccessControllerProvider.overrideWith(() => FixedAccess(access)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('a login without the assistants area', () {
    test('a member chats from the thread route\'s agents; /api/agents is '
        'never asked', () async {
      when(() => api.threadInfo()).thenAnswer(
        (_) async => const AssistantThreadInfo(
          chattableSlugs: {'team', 'sales'},
          defaultSlug: 'team',
          agents: [
            Agent(id: 'a-sales', slug: 'sales', name: 'Sales'),
            Agent(id: 'a-team', slug: 'team', name: 'Team'),
          ],
        ),
      );
      final c = make(access: memberAccess);

      final state = await c.read(agentControllerProvider.future);
      expect(state.agents.map((a) => a.slug), ['sales', 'team']);
      expect(state.active?.slug, 'team');
      verifyNever(() => api.list());
    });

    test('an older brain with no thread answer leaves no agents', () async {
      final c = make(access: memberAccess);
      final state = await c.read(agentControllerProvider.future);
      expect(state.agents, isEmpty);
      expect(state.active, isNull);
      verifyNever(() => api.list());
    });
  });

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

  group('server-owned list + default (/api/assistant/thread)', () {
    const disabled = Agent(slug: 'retired', name: 'Retired');

    test('hides agents the server does not consider chattable', () async {
      // /api/agents filters to conversational ROLES but not `enabled`, so a
      // disabled agent arrives here and must be dropped.
      when(() => api.list()).thenAnswer((_) async => [_saskia, disabled, _pages]);
      when(() => api.threadInfo()).thenAnswer(
        (_) async => const AssistantThreadInfo(
          chattableSlugs: {'saskia', 'pages'},
          defaultSlug: 'saskia',
        ),
      );
      final c = make();

      final state = await c.read(agentControllerProvider.future);
      expect(state.agents.map((a) => a.slug), ['saskia', 'pages']);
    });

    test("defaults to the server's resolved agent, not merely the first", () async {
      // The per-login assistant (v0.224 agents.assigned_user_id) ranks BELOW
      // its source in priority, so first-by-priority is the wrong answer.
      when(() => api.list()).thenAnswer((_) async => [_saskia, _pages]);
      when(() => api.threadInfo()).thenAnswer(
        (_) async => const AssistantThreadInfo(
          chattableSlugs: {'saskia', 'pages'},
          defaultSlug: 'pages',
        ),
      );
      final c = make();

      final state = await c.read(agentControllerProvider.future);
      expect(state.active?.slug, 'pages');
      expect(c.read(activeAgentSlugProvider), 'pages');
    });

    test('a resolved agent missing from the list falls back to the first', () async {
      when(() => api.list()).thenAnswer((_) async => [_saskia, _pages]);
      when(() => api.threadInfo()).thenAnswer(
        (_) async => const AssistantThreadInfo(
          chattableSlugs: {'saskia', 'pages'},
          defaultSlug: 'ghost',
        ),
      );
      final c = make();

      expect((await c.read(agentControllerProvider.future)).active?.slug, 'saskia');
    });

    test('an empty chattable set never empties the picker', () async {
      // An unrecognised response shape must not cost the user their agents.
      when(() => api.list()).thenAnswer((_) async => [_saskia, _pages]);
      when(() => api.threadInfo()).thenAnswer(
        (_) async =>
            const AssistantThreadInfo(chattableSlugs: {}, defaultSlug: null),
      );
      final c = make();

      final state = await c.read(agentControllerProvider.future);
      expect(state.agents, hasLength(2));
      expect(state.active?.slug, 'saskia');
    });
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The workspace the phone is in, chosen in the drawer's switcher and kept
/// on the device per login. Null on a brain from before workspaces (whoami
/// lists none): the phone then is what it always was.
///
/// A choice the login no longer has (it left the workspace, or it was
/// archived) falls back to the default: an Admin user's Admin workspace,
/// anyone else's first shared one.

@ProviderFor(CurrentWorkspace)
final currentWorkspaceProvider = CurrentWorkspaceProvider._();

/// The workspace the phone is in, chosen in the drawer's switcher and kept
/// on the device per login. Null on a brain from before workspaces (whoami
/// lists none): the phone then is what it always was.
///
/// A choice the login no longer has (it left the workspace, or it was
/// archived) falls back to the default: an Admin user's Admin workspace,
/// anyone else's first shared one.
final class CurrentWorkspaceProvider
    extends $AsyncNotifierProvider<CurrentWorkspace, ShellWorkspace?> {
  /// The workspace the phone is in, chosen in the drawer's switcher and kept
  /// on the device per login. Null on a brain from before workspaces (whoami
  /// lists none): the phone then is what it always was.
  ///
  /// A choice the login no longer has (it left the workspace, or it was
  /// archived) falls back to the default: an Admin user's Admin workspace,
  /// anyone else's first shared one.
  CurrentWorkspaceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentWorkspaceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentWorkspaceHash();

  @$internal
  @override
  CurrentWorkspace create() => CurrentWorkspace();
}

String _$currentWorkspaceHash() => r'444c08e059805b4e2e9e7994d91cb7c731736364';

/// The workspace the phone is in, chosen in the drawer's switcher and kept
/// on the device per login. Null on a brain from before workspaces (whoami
/// lists none): the phone then is what it always was.
///
/// A choice the login no longer has (it left the workspace, or it was
/// archived) falls back to the default: an Admin user's Admin workspace,
/// anyone else's first shared one.

abstract class _$CurrentWorkspace extends $AsyncNotifier<ShellWorkspace?> {
  FutureOr<ShellWorkspace?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ShellWorkspace?>, ShellWorkspace?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ShellWorkspace?>, ShellWorkspace?>,
              AsyncValue<ShellWorkspace?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Every workspace row the login reads (`GET /api/workspaces`), for each
/// one's assistant. Empty when the brain cannot say (offline, an older
/// brain): the chat then keeps the owner surface's agent choice.

@ProviderFor(workspaceRows)
final workspaceRowsProvider = WorkspaceRowsProvider._();

/// Every workspace row the login reads (`GET /api/workspaces`), for each
/// one's assistant. Empty when the brain cannot say (offline, an older
/// brain): the chat then keeps the owner surface's agent choice.

final class WorkspaceRowsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkspaceRow>>,
          List<WorkspaceRow>,
          FutureOr<List<WorkspaceRow>>
        >
    with
        $FutureModifier<List<WorkspaceRow>>,
        $FutureProvider<List<WorkspaceRow>> {
  /// Every workspace row the login reads (`GET /api/workspaces`), for each
  /// one's assistant. Empty when the brain cannot say (offline, an older
  /// brain): the chat then keeps the owner surface's agent choice.
  WorkspaceRowsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceRowsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceRowsHash();

  @$internal
  @override
  $FutureProviderElement<List<WorkspaceRow>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WorkspaceRow>> create(Ref ref) {
    return workspaceRows(ref);
  }
}

String _$workspaceRowsHash() => r'53bcdce46c4389e5b4b0be4fc5348f83fd5a69e0';

/// The ids of the assistants of workspaces other than Admin. Such an
/// assistant runs the workspace turn engine: text only, for every login.

@ProviderFor(workspaceAgentIds)
final workspaceAgentIdsProvider = WorkspaceAgentIdsProvider._();

/// The ids of the assistants of workspaces other than Admin. Such an
/// assistant runs the workspace turn engine: text only, for every login.

final class WorkspaceAgentIdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          FutureOr<Set<String>>
        >
    with $FutureModifier<Set<String>>, $FutureProvider<Set<String>> {
  /// The ids of the assistants of workspaces other than Admin. Such an
  /// assistant runs the workspace turn engine: text only, for every login.
  WorkspaceAgentIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceAgentIdsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceAgentIdsHash();

  @$internal
  @override
  $FutureProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<String>> create(Ref ref) {
    return workspaceAgentIds(ref);
  }
}

String _$workspaceAgentIdsHash() => r'83b3e56dc4c34dccc30028522747c0538259c5c1';

/// Where the Chat button goes now.

@ProviderFor(chatTarget)
final chatTargetProvider = ChatTargetProvider._();

/// Where the Chat button goes now.

final class ChatTargetProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChatTarget>,
          ChatTarget,
          FutureOr<ChatTarget>
        >
    with $FutureModifier<ChatTarget>, $FutureProvider<ChatTarget> {
  /// Where the Chat button goes now.
  ChatTargetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatTargetProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatTargetHash();

  @$internal
  @override
  $FutureProviderElement<ChatTarget> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ChatTarget> create(Ref ref) {
    return chatTarget(ref);
  }
}

String _$chatTargetHash() => r'b3907d354db393111f32d11d183acaff1d694f52';

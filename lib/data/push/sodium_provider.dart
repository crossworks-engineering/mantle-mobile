import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sodium_libs/sodium_libs.dart';

part 'sodium_provider.g.dart';

/// libsodium, initialized once. Used only to generate the device's X25519
/// keypair for E2E push — sealing happens in Mantle (`crypto_box_seal`) and
/// opening in the iOS Notification Service Extension (`crypto_box_seal_open`),
/// never here. Using real libsodium guarantees the key format is byte-compatible
/// with both ends.
@Riverpod(keepAlive: true)
Future<Sodium> sodium(Ref ref) => SodiumInit.init();

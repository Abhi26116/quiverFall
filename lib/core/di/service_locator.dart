import 'package:get_it/get_it.dart';

/// The composition root.
///
/// Registration happens in `bootstrap.dart`, in four ordered phases. Two rules:
///
///  1. **Register the interface, never the implementation.** Every service is
///     looked up by its port type so tests, the headless balance harness, and
///     platform-specific variants can all substitute freely. This is what makes
///     the deferred iOS ads/analytics situation from ADR 0001 a one-line
///     registration change rather than a refactor.
///  2. **Nothing inside a feature calls [locator] directly.** Features receive
///     dependencies through Riverpod providers, which read from here once at the
///     edge. Reaching into the locator from a widget re-creates the global-state
///     problem DI exists to solve.
final GetIt locator = GetIt.instance;

/// Convenience accessor. Fails loudly if [T] was never registered, rather than
/// returning null and producing a confusing NPE three frames later.
T resolve<T extends Object>() => locator<T>();

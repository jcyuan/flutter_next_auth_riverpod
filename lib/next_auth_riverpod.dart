import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_next_auth_core/next_auth.dart';

class Opt<T> {
  final T? value;
  const Opt(this.value);
  static const Opt absent = Opt(null);
}

class NextAuthState<T> {
  final T? session;
  final SessionStatus status;

  const NextAuthState({
    this.session,
    required this.status,
  });

  NextAuthState<T> copyWith({
    Opt<T>? session,
    Opt<SessionStatus>? status,
  }) {
    return NextAuthState<T>(
      session: session == null ? this.session : session.value,
      status: status == null ? this.status : status.value!
    );
  }
}

/// Notifier that manages NextAuthClient state, refetch timer, and app lifecycle
/// This is a pure synchronous Notifier that only listens to event stream
class NextAuthRiverpodNotifier<T>
    extends Notifier<NextAuthState<T>> with WidgetsBindingObserver {
  NextAuthClient<T>? _client;
  Timer? _refetchTimer;
  bool _isAppInForeground = true;
  int? _storedRefetchInterval;
  bool _storedRefetchOnWindowFocus = true;
  bool _isObserverAdded = false;

  @override
  NextAuthState<T> build() {
    // directly read client from provider (synchronous)
    final client = ref.watch(_nextAuthClientProvider) as NextAuthClient<T>?;
    if (client == null) {
      return NextAuthState<T>(status: SessionStatus.initial);
    }

    // if client changed, cleanup old subscriptions
    if (_client != client) {
      _dispose();
      _client = client;
    }

    _storedRefetchInterval = ref.watch(_refetchIntervalProvider);
    _storedRefetchOnWindowFocus = ref.watch(_refetchOnWindowFocusProvider);
    ref.listen(authEventStreamProvider, (prev, next) {
      next.whenData((event) {
        if (event == null) return;
        if (event is SessionChangedEvent) {
          _handleSessionChanged(event.session as T?);
        } else if (event is StatusChangedEvent) {
          _handleStatusChanged(event.status);
        }
      });
    });

    if (!_isObserverAdded) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverAdded = true;
    }

    ref.onDispose(() {
      _dispose();
    });

    if (_storedRefetchInterval != null && _storedRefetchInterval! > 0) {
      _startRefetchTimer(_storedRefetchInterval!);
    }

    // return the latest state from client
    return NextAuthState<T>(
      session: client.session,
      status: client.status,
    );
  }

  void _handleStatusChanged(SessionStatus status) {
    if (!ref.mounted) return;
    state = state.copyWith(status: Opt(status));
  }

  void _handleSessionChanged(T? session) {
    if (!ref.mounted) return;
    state = state.copyWith(session: Opt(session));
  }

  void _startRefetchTimer(int intervalMs) {
    if (intervalMs <= 0) return;
    if (!_isAppInForeground) return;

    _refetchTimer?.cancel();
    _refetchTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _refetchSession(),
    );
  }

  void _stopRefetchTimer() {
    _refetchTimer?.cancel();
    _refetchTimer = null;
  }

  Future<void> _refetchSession() async {
    if (_client == null || !_isAppInForeground) return;
    try {
      await _client!.refetchSession();
    } catch (_) {
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        _stopRefetchTimer();
        break;
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        if (_storedRefetchInterval != null && _storedRefetchInterval! > 0) {
          _startRefetchTimer(_storedRefetchInterval!);
          if (_storedRefetchOnWindowFocus) {
            _refetchSession();
          }
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  NextAuthClient<T>? get client => _client;

  void _dispose() {
    _stopRefetchTimer();
    if (_isObserverAdded) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverAdded = false;
    }
  }
}

final _nextAuthClientProvider = Provider<NextAuthClient<Object>?>((ref) => null);
final _refetchIntervalProvider = Provider<int?>((ref) => null);
final _refetchOnWindowFocusProvider = Provider<bool>((ref) => true);

// one-time initialization provider - only runs once on app startup
final _nextAuthInitProvider = FutureProvider<void>((ref) async {
  final client = ref.read(_nextAuthClientProvider);
  if (client == null) {
    throw Exception('NextAuthClient not provided in NextAuthRiverpodScope');
  }
  await client.recoverLoginStatusFromCache();
});

/// Scope widget for NextAuth Riverpod
/// Wrap your app with this widget to provide NextAuthClient and configuration
/// 
/// This widget will wait for the client to be initialized before rendering its child,
/// ensuring that session and status are available when any page first watches them.
/// 
/// Example:
/// ```dart
/// final client = NextAuthClient(config);
/// 
/// NextAuthRiverpodScope(
///   client: client,
///   refetchInterval: 30000,
///   refetchOnWindowFocus: true,
///   child: MyApp(),
/// )
/// ```
class NextAuthRiverpodScope<T> extends StatelessWidget {
  final NextAuthClient<T> client;
  /// in milliseconds
  final int? refetchInterval;
  final bool refetchOnWindowFocus;
  final Widget child;

  const NextAuthRiverpodScope({
    super.key,
    required this.client,
    this.refetchInterval,
    this.refetchOnWindowFocus = true,
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        _nextAuthClientProvider.overrideWithValue(client as NextAuthClient<Object>?),
        _refetchIntervalProvider.overrideWithValue(refetchInterval),
        _refetchOnWindowFocusProvider.overrideWithValue(refetchOnWindowFocus),
      ],
      child: _InitializationGuard(
        child: child,
      ),
    );
  }
}

/// AuthClient instance initialization guard before rendering child
/// Waits for one-time initialization to complete
class _InitializationGuard extends ConsumerWidget {
  final Widget child;

  const _InitializationGuard({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /* final initAsync = */ref.watch(_nextAuthInitProvider);

    // return initAsync.when(
    //   data: (a) {
    //     debugPrint('Initialization complete:');
    //     return child;
    //   },
    //   loading: () => const SizedBox.shrink(),
    //   error: (error, stack) => child,
    // );

    // Directly return child without waiting for _nextAuthInitProvider to finish initializing,
    // because the child widget needs to determine which UI to display based 
    // on SessionStatus and SessionStatus will be updated when _nextAuthInitProvider is finished initializing.
    return child;
  }
}

/// Main provider for state management
/// Usage: ref.watch(authProvider)
final authProvider = NotifierProvider<NextAuthRiverpodNotifier<Object>, NextAuthState<Object>>(() {
  return NextAuthRiverpodNotifier<Object>();
});

/// Provider that returns only the session
/// Usage: ref.watch(sessionProvider)
final sessionProvider = Provider<Object?>((ref) {
  return ref.watch(authProvider).session;
});

/// Provider that returns only the status
/// Usage: ref.watch(statusProvider)
final statusProvider = Provider<SessionStatus>((ref) {
  return ref.watch(authProvider).status;
});

/// Stream provider for next auth events
/// Usage: ref.listen(authEventStreamProvider)
final authEventStreamProvider = StreamProvider.autoDispose<NextAuthEvent?>((ref) {
  final client = ref.watch(_nextAuthClientProvider);
  if (client == null) return const Stream.empty();
  return client.eventBus.on<NextAuthEvent>();
});

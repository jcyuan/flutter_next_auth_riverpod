# flutter_next_auth_riverpod

Riverpod integration for [NextAuth.js](https://next-auth.js.org/) in Flutter via [`flutter_next_auth_core`](https://github.com/jcyuan/flutter_next_auth_core#readme), providing reactive state management for session and authentication status.

## Features

- **App-wide scope**: `NextAuthRiverpodScope` wires a `NextAuthClient` into Riverpod.
- **Reactive auth state**: watch session/status via providers.
- **Auto refetch**: optional periodic refetch and refetch when app returns to foreground.
- **Auth event stream**: listen to auth lifecycle events (sign in/out, session/status changes).

Example Video:

https://github.com/user-attachments/assets/57496047-716b-4419-b4b2-c6c240572edd

## Installation

Add dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_next_auth_core: ^1.0.5
  flutter_next_auth_riverpod: ^1.0.4
  flutter_riverpod: ^3.1.0
```

## NextAuthClient configuration

`flutter_next_auth_riverpod` uses `NextAuthClient` from `flutter_next_auth_core`.
For the complete API reference and examples, see: [NextAuthClient API reference](https://github.com/jcyuan/flutter_next_auth_core?tab=readme-ov-file#-nextauthclient-api-reference).

## Usage

### 1) Wrap your app with `NextAuthRiverpodScope`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_next_auth_core/next_auth.dart';
import 'package:flutter_next_auth_riverpod/next_auth_riverpod.dart';

void main() {
  final config = NextAuthConfig(
    domain: 'https://example.com',
    authBasePath: '/api/auth',
    httpClient: /* your HttpClient */,
  );

  final client = NextAuthClient<Object>(config);

  runApp(
    NextAuthRiverpodScope<Object>(
      client: client,
      // in milliseconds
      refetchInterval: 30000,
      // default: true
      refetchOnWindowFocus: true,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: SizedBox.shrink());
  }
}
```

### 2) Watch auth state with providers

`flutter_next_auth_riverpod` exposes these Riverpod providers:

- **`statusProvider`**: `Provider<SessionStatus>` (`initial`, `loading`, `authenticated`, `unauthenticated`)
- **`sessionProvider`**: `Provider<Object?>` (session data when authenticated, otherwise `null`)
- **`authProvider`**: `NotifierProvider<NextAuthRiverpodNotifier<Object>, NextAuthState<Object>>`
- **`authEventStreamProvider`**: `StreamProvider<NextAuthEvent?>`

Minimal example:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_next_auth_riverpod/next_auth_riverpod.dart';

class MyWidget extends ConsumerWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(statusProvider);
    final session = ref.watch(sessionProvider); // Object?

    return Text('Status: ${status.name}, Session: ${session?.toString()}');
  }
}
```

If you use a custom session model, cast it:

```dart
final session = ref.watch(sessionProvider) as MySession?;
```

## Example

See `example/` for a complete integration project.

```bash
cd example
flutter pub get
flutter run
```

## See also

**Flutter NextAuth Core**: [https://github.com/jcyuan/flutter_next_auth_core](https://github.com/jcyuan/flutter_next_auth_core)  
**BLoC integration**: [https://github.com/jcyuan/flutter_next_auth_bloc](https://github.com/jcyuan/flutter_next_auth_bloc)

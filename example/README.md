# flutter_next_auth_riverpod Integration Example

This is a minimal Flutter project demonstrating how to integrate `flutter_next_auth_core` with `flutter_next_auth_riverpod` for automatic session management and state handling.

## Project Structure

```
example/
├── lib/
│   ├── main.dart                          # flutter_next_auth_riverpod integration example
│   ├── simple_dio_httpclient.dart         # Simple HTTP client implementation using Dio
│   └── providers/
│       └── google_oauth_provider.dart     # Example Google OAuth provider implementation
├── pubspec.yaml                           # Flutter project configuration
└── README.md                              # Integration guide and examples
```

## Initialization Steps

### 1. Dependencies

This example project requires the following dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.1.1
  google_sign_in: ^7.2.0
  get_it: ^9.2.0
  flutter_next_auth_core: ^1.1.0
  flutter_next_auth_riverpod: ^1.0.8
  flutter_riverpod: ^3.1.0
```

Note: `dio` and `get_it` is not a dependency of the `flutter_next_auth_riverpod` package. It's only needed in this example.

### 2. NextAuthClient Configuration

For complete NextAuthClient API reference (Properties, Methods, Event Handling) and examples, please refer to:

[NextAuthClient API reference](https://github.com/jcyuan/flutter_next_auth_core?tab=readme-ov-file#-nextauthclient-api-reference)

## flutter_next_auth_riverpod Integration

### NextAuthRiverpodScope

`NextAuthRiverpodScope` is a widget that wraps your app and provides automatic session management. It handles session recovery, refetching, and state synchronization.

#### Parameters

- **client**: `NextAuthClient<T>` (required) - The NextAuthClient instance
- **refetchInterval**: `int?` (optional) - Interval in milliseconds to automatically refetch session from server
- **refetchOnWindowFocus**: `bool` (optional) - Whether to refetch session when app comes to foreground (default: `true`)
- **child**: `Widget` (required) - Your app widget

#### Minimal Example

```dart
import 'package:flutter_next_auth_riverpod/next_auth_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  final nextAuthClient = NextAuthClient<Map<String, dynamic>>(config);
  
  runApp(NextAuthRiverpodScope(
    client: nextAuthClient,
    refetchOnWindowFocus: true,
    child: const MyApp(),
  ));
}
```

### Providers

`next_auth_riverpod` provides the following Riverpod providers for accessing authentication state:

#### statusProvider

Provides the current session status.

- **Type**: `Provider<SessionStatus>`
- **Values**: `initial`, `loading`, `authenticated`, `unauthenticated`

#### sessionProvider

Provides the current session data.

- **Type**: `Provider<Object?>` (cast to your session model as needed)
- **Returns**: Session data if authenticated, `null` otherwise

#### Minimal Example

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_next_auth_riverpod/next_auth_riverpod.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionStatus = ref.watch(statusProvider);
    final session = ref.watch(sessionProvider); // as YourSessionType?
    
    return Text('Status: ${sessionStatus.name}, Session: ${session?.toString()}');
  }
}
```

### Complete Widget Example

Here's a minimal widget example showing how to use session and status in the build method:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_next_auth_riverpod/next_auth_riverpod.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch session status and session data
    final sessionStatus = ref.watch(statusProvider);
    final session = ref.watch(sessionProvider); // as YourSessionType?

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Session Status: ${sessionStatus.name}'),
              const SizedBox(height: 16),
              if (session != null)
                Text('Session: ${session.toString()}')
              else
                const Text('No session'),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Running the Example

1. Navigate to the example directory:
   ```bash
   cd example
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Run the example:
   ```bash
   flutter run
   ```

## Integration into Your Project

To integrate NextAuthClient with next_auth_riverpod into your project:

1. Add `flutter_next_auth_core` and `flutter_next_auth_riverpod` to your `pubspec.yaml`
2. Implement the `HttpClient` interface (or use the provided `SimpleDioHttpClient` as a reference)
3. Create `NextAuthConfig` with your server configuration
4. Configure cookie names to match your server-side NextAuth.js configuration
5. Initialize `NextAuthClient` with the config
6. Register OAuth providers if needed (see `lib/providers/google_oauth_provider.dart` for reference)
7. Wrap your app with `NextAuthRiverpodScope` and pass the `NextAuthClient` instance
8. Use `statusProvider` and `sessionProvider` in your widgets to access authentication state

## OAuth Provider Implementation

When implementing your own OAuth provider:

1. Implement the `OAuthProvider` interface
2. The `getAuthorizationData()` method should return `OAuthAuthorizationData` containing:
   - `idToken`: The ID token from the OAuth provider (required)
     - Used as the default silent authorization method
     - Only when the idToken expires or the client OAuth package's silent login fails, will it force login to refresh the idToken
   - `authorizationCode`: The authorization code (optional, for server-side token exchange)
3. See `lib/providers/google_oauth_provider.dart` for a complete example
4. Reference [https://github.com/jcyuan/flutter_next_auth_core/tree/main/example/lib/oauth_api](https://github.com/jcyuan/flutter_next_auth_core/tree/main/example/lib/oauth_api) for backend verification logic

## See Also

[flutter_next_auth_core](https://github.com/jcyuan/flutter_next_auth_core#readme)

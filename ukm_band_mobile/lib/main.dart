import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/music_provider.dart';
import 'screens/main_shell.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'providers/audio_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiService = ApiService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) {
            final authProvider = AuthProvider(apiService);
            authProvider.initialize();
            return authProvider;
          },
        ),
        ChangeNotifierProvider<AudioProvider>(create: (_) => AudioProvider()),
        ChangeNotifierProvider<MusicProvider>(
          create: (context) => MusicProvider(context.read<ApiService>()),
        ),
      ],
      child: const UKMBandApp(),
    ),
  );
}

class UKMBandApp extends StatelessWidget {
  const UKMBandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UKM Band Telkom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (auth.isAuthenticated) {
          return const MainShell();
        }

        return const WelcomeScreen();
      },
    );
  }
}

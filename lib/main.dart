import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_state.dart';
import 'pages/home_page.dart';
import 'pages/upload_page.dart';
import 'pages/data_view.dart';
import 'pages/login_screen.dart';
import 'pages/settings_screen.dart';
import 'sharednavbar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lxlfbvepigzsytwgncqy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx4bGZidmVwaWd6c3l0d2duY3F5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5Mzc5MDQsImV4cCI6MjA3NDUxMzkwNH0.cPnLEbWggOE_4Zm6YvuZpLeOCsBi2j15DXTWIUoi8i8',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const AIParserApp(),
    ),
  );
}

class AIParserApp extends StatefulWidget {
  const AIParserApp({super.key});
  @override
  State<AIParserApp> createState() => _AIParserAppState();
}

class _AIParserAppState extends State<AIParserApp> {
  int _currentIndex = 0;
  final List<Map<String, String>> _records = [];
  String _userName = "User";
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _hydrateUserFromSupabase();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      authState,
    ) async {
      if (authState.session != null) {
        await _hydrateUserFromSupabase();
        if (mounted) setState(() {});
      } else {
        if (mounted) setState(() => _userName = "User");
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void> _hydrateUserFromSupabase() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser?.email == null) return;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('user')
          .eq('email', authUser!.email!)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _userName = (row['user'] as String?)?.trim().isNotEmpty == true
              ? row['user'] as String
              : 'User';
        });
      }
    } catch (_) {}
  }

  void addRecord(Map<String, String> record) {
    setState(() {
      _records.add(record);
      _currentIndex = 2; // Records tab
    });
  }

  void handleNavTap(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDarkMode;

    // 0: Home, 1: Upload, 2: Records, 3: Settings
    final screens = <Widget>[
      Builder(
        builder: (innerContext) => HomePage(
          userName: _userName,
          submittedCount: _records.length,
          receivedCount: 0,
          onUploadTap: () => setState(() => _currentIndex = 1),
          onLoginTap: () async {
            final result = await Navigator.push<String>(
              innerContext,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
            if (result != null && result.trim().isNotEmpty) {
              setState(() => _userName = result.trim());
            } else {
              await _hydrateUserFromSupabase();
            }
          },
        ),
      ),
      UploadPage(onSave: addRecord),
      DataViewPage(records: _records),
      SettingsScreen(
        onLogoutComplete: () {
          if (mounted) setState(() => _currentIndex = 0);
        },
      ),
    ];

    final pageIndex = (_currentIndex >= 0 && _currentIndex < screens.length)
        ? _currentIndex
        : 0;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Parser',
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        extendBody: true,
        body: screens[pageIndex],
        bottomNavigationBar: SharedNavBar(
          currentIndex: pageIndex,
          isDarkMode: isDark,
          onItemTapped: (i) {
            final next = (i >= 0 && i < screens.length) ? i : 0;
            handleNavTap(next);
          },
        ),
      ),
    );
  }
}

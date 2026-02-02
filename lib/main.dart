import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'provider.dart';
import 'styles.dart';
import 'widgets/auth/login_screen.dart';
import 'widgets/auth/register_screen.dart';
import 'widgets/auth/forgot_password_screen.dart';
import 'widgets/sidebar.dart';
import 'widgets/header.dart';

import 'widgets/chat_view.dart';
import 'widgets/project_modal.dart';
import 'widgets/calendar_view.dart';
import 'widgets/settings_view.dart';
import 'database/objectbox_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'services/embedding_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");

  // Initialize ObjectBox database (optional - app works without it)
  try {
    await ObjectBoxService.instance.initialize();
    print("✅ ObjectBox database initialized");
  } catch (e) {
    print("⚠️ ObjectBox initialization failed: $e");
    print("   Semantic search will be disabled.");
  }

  // Initialize embedding service (uses OpenAI API)
  EmbeddingService.instance
      .initialize()
      .then((_) {
        print("✅ Embedding service initialized (OpenAI API)");
      })
      .catchError((e) {
        print("⚠️ Embedding service initialization failed: $e");
      });

  runApp(
    ChangeNotifierProvider(
      create: (_) => DayCrafterProvider(),
      child: const DayCrafterApp(),
    ),
  );
}

class DayCrafterApp extends StatelessWidget {
  const DayCrafterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();

    // Apply theme to styles
    AppStyles.setDarkMode(provider.isDarkMode);

    return MaterialApp(
      title: 'DayCrafter',
      debugShowCheckedModeBanner: false,

      // Localization
      locale: provider.flutterLocale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US'), Locale('zh', 'TW')],

      // Theme
      theme: AppStyles.getThemeData(),

      home: const SelectionArea(child: MainNavigator()),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  bool _showRegister = false;
  bool _showForgotPassword = false;

  @override
  void initState() {
    super.initState();
    // Check auth status on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DayCrafterProvider>().checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();

    // Show loading screen while checking auth status
    if (provider.isCheckingAuth) {
      return Scaffold(
        backgroundColor: AppStyles.mBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/logo.jpg',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'DayCrafter',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.mTextPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show auth screens if not logged in
    if (!provider.isLoggedIn) {
      if (_showRegister) {
        return RegisterScreen(
          onSwitchToLogin: () => setState(() => _showRegister = false),
          onRegister: (email, password, name) async {
            final error = await provider.register(
              email: email,
              password: password,
              name: name,
            );
            return error;
          },
        );
      }

      if (_showForgotPassword) {
        return Scaffold(
          backgroundColor: AppStyles.mBackground,
          body: Center(
            child: ForgotPasswordScreen(
              onBackToLogin: () => setState(() => _showForgotPassword = false),
            ),
          ),
        );
      }

      return LoginScreen(
        onSwitchToRegister: () => setState(() => _showRegister = true),
        onForgotPassword: () => setState(() => _showForgotPassword = true),
        onLogin: (email, password) async {
          return await provider.login(email: email, password: password);
        },
        onGetAccounts: () => provider.getRegisteredAccounts(),
        onDeleteAccount: (email) => provider.deleteAccount(email),
      );
    }

    return const MainLayout();
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  void _showProjectModal() {
    showDialog(
      context: context,
      builder: (context) => ProjectModal(
        onSubmit: (data) => context.read<DayCrafterProvider>().addProject(
          data.name,
          colorHex: data.colorHex,
          emoji: data.emoji,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();
    final activeProject = provider.activeProject;

    return Scaffold(
      backgroundColor: AppStyles.mBackground,
      body: Row(
        children: [
          Sidebar(onAddProject: _showProjectModal),
          Expanded(
            child: Container(
              color: AppStyles.mSurface,
              child: Column(
                children: [
                  Header(activeProjectName: activeProject?.name),
                  Expanded(child: _buildMainContent(provider)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(DayCrafterProvider provider) {
    // Show calendar when calendar is active
    if (provider.isCalendarActive) {
      return const CalendarView();
    }

    // Show settings when settings is active
    if (provider.isSettingsActive) {
      return const SettingsView();
    }

    if (provider.activeProjectId == null) {
      return _buildWelcomeBack(provider);
    }

    return const ChatView();
  }

  Widget _buildWelcomeBack(DayCrafterProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppStyles.mPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                LucideIcons.layoutGrid,
                size: 48,
                color: AppStyles.mPrimary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Welcome, ${provider.userName}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppStyles.mTextPrimary,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 40),
            OutlinedButton(
              onPressed: _showProjectModal,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(
                  color: AppStyles.mPrimary.withValues(alpha: 0.5),
                ),
                backgroundColor: Colors.transparent,
              ),
              child: Text(
                '+ Create New Project',
                style: TextStyle(
                  color: AppStyles.mTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

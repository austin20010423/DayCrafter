import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'provider.dart';
import 'styles.dart';
import 'widgets/name_entry.dart';
import 'widgets/sidebar.dart';
import 'widgets/header.dart';
import 'widgets/empty_state.dart';
import 'widgets/chat_view.dart';
import 'widgets/project_modal.dart';
import 'widgets/calendar_view.dart';
import 'database/objectbox_service.dart';
import 'services/embedding_service.dart';

// package for testing purposes
import 'package:shared_preferences/shared_preferences.dart';
//delete above line when not needed

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

  //start wipe code
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear(); // This deletes all saved names and projects!
  print("⚠️ All data wiped for testing!");
  // --- END OF WIPE CODE ---

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

      home: const MainNavigator(),
    );
  }
}

class MainNavigator extends StatelessWidget {
  const MainNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();

    if (provider.userName == null) {
      return const NameEntryScreen();
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ClipRRect(
          borderRadius: AppStyles.bRadiusLarge,
          child: Row(
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
        ),
      ),
    );
  }

  Widget _buildMainContent(DayCrafterProvider provider) {
    // Show calendar when calendar is active
    if (provider.isCalendarActive) {
      return const CalendarView();
    }

    if (provider.activeProjectId == null) {
      if (provider.projects.isEmpty) {
        return Center(child: EmptyState(onAdd: _showProjectModal));
      } else {
        return _buildWelcomeBack(provider);
      }
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppStyles.mPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.dashboard_outlined,
                size: 32,
                color: AppStyles.mPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome back, ${provider.userName}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppStyles.mTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a project from the sidebar to manage your plans, tasks, and research.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppStyles.mTextSecondary, fontSize: 16),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: _showProjectModal,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: AppStyles.mPrimary),
              ),
              child: Text(
                '+ Create New Project',
                style: TextStyle(
                  color: AppStyles.mPrimary,
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

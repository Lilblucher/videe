import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/download_service.dart';
import 'screens/home/home_screen.dart';
import 'screens/browser/browser_screen.dart';
import 'screens/downloads/downloads_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storage = StorageService();
  await storage.init();

  runApp(VideeApp(storage: storage));
}

class VideeApp extends StatelessWidget {
  final StorageService storage;

  const VideeApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DownloadService(storage),
      child: MaterialApp(
        title: 'Videe',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: AppShell(storage: storage),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  final StorageService storage;

  const AppShell({super.key, required this.storage});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final _browserKey = GlobalKey<BrowserScreenState>();
  String? _pendingBrowserUrl;

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
  }

  void _browseTo(String url) {
    setState(() {
      _pendingBrowserUrl = url;
      _currentIndex = 1;
    });
    Future.microtask(() {
      _browserKey.currentState?.loadUrl(url);
      _pendingBrowserUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            onNavigate: _navigateTo,
            onBrowse: _browseTo,
          ),
          BrowserScreen(
            key: _browserKey,
            initialUrl: _pendingBrowserUrl,
            storage: widget.storage,
          ),
          const DownloadsScreen(),
          LibraryScreen(storage: widget.storage),
          SettingsScreen(storage: widget.storage),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _navigateTo,
          items: [
            _navItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
            _navItem(Icons.language, Icons.language_outlined, 'Browse'),
            _navItem(
                Icons.download_rounded, Icons.download_outlined, 'Downloads'),
            _navItem(
                Icons.video_library, Icons.video_library_outlined, 'Library'),
            _navItem(Icons.settings, Icons.settings_outlined, 'Settings'),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(
      IconData active, IconData inactive, String label) {
    return BottomNavigationBarItem(
      icon: Icon(inactive),
      activeIcon: Icon(active),
      label: label,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/download_service.dart';
import 'services/clipboard_monitor.dart';
import 'services/extraction_service.dart';
import 'screens/home/home_screen.dart';
import 'screens/browser/browser_screen.dart';
import 'screens/downloads/downloads_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'widgets/download_sheet.dart';
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

  final clipboard = ClipboardMonitor();

  runApp(VideeApp(storage: storage, clipboardMonitor: clipboard));
}

class VideeApp extends StatelessWidget {
  final StorageService storage;
  final ClipboardMonitor clipboardMonitor;

  const VideeApp({super.key, required this.storage, required this.clipboardMonitor});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DownloadService(storage)),
        ChangeNotifierProvider.value(value: clipboardMonitor),
      ],
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

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _browserKey = GlobalKey<BrowserScreenState>();
  final _extractionService = ExtractionService();
  String? _pendingBrowserUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      context.read<ClipboardMonitor>().start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final monitor = context.read<ClipboardMonitor>();
    if (state == AppLifecycleState.resumed) {
      monitor.start();
    } else {
      monitor.stop();
    }
  }

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

  Future<void> _handleClipboardUrl(String url) async {
    final monitor = context.read<ClipboardMonitor>();
    monitor.dismiss();

    final result = await _extractionService.extractVideo(url);
    if (result != null && result.streams.isNotEmpty && mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => DownloadSheet(
          videoInfo: result,
          storage: widget.storage,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not extract video from this URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
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
          Consumer<ClipboardMonitor>(
            builder: (context, monitor, _) {
              if (!monitor.hasUrl) return const SizedBox.shrink();
              return Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.surface,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _handleClipboardUrl(monitor.detectedUrl!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.link, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Video link detected',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  monitor.detectedUrl!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'Download',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => monitor.dismiss(),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
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

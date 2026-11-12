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
import 'widgets/download_sheet.dart' show DownloadSheet;
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
      DownloadSheet.show(context, result);
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
                child: GestureDetector(
                  onTap: () => _handleClipboardUrl(monitor.detectedUrl!),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.link, color: AppColors.accentText, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'LINK IN CLIPBOARD',
                                style: AppText.mono(
                                  size: 10.5,
                                  weight: FontWeight.w500,
                                  letterSpacing: 1,
                                  color: AppColors.textFaint,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                monitor.detectedUrl!,
                                style: AppText.mono(size: 12, color: AppColors.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(AppRadius.control),
                          ),
                          child: Text(
                            'Analyze',
                            style: AppText.sans(
                              size: 13,
                              weight: FontWeight.w700,
                              color: AppColors.onAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => monitor.dismiss(),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: AppColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: _navigateTo,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _labels = ['HOME', 'BROWSE', 'DOWNLOADS', 'LIBRARY', 'SETTINGS'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        height: 2,
                        width: 24,
                        margin: const EdgeInsets.only(top: 0),
                        color: i == currentIndex
                            ? AppColors.accent
                            : Colors.transparent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _labels[i],
                        style: AppText.mono(
                          size: 11,
                          weight: FontWeight.w500,
                          letterSpacing: 0.8,
                          color: i == currentIndex
                              ? AppColors.text
                              : AppColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

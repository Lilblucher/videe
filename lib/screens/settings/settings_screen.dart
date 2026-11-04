import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storage;

  const SettingsScreen({super.key, required this.storage});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _downloadQuality;
  late bool _wifiOnly;
  late int _maxConcurrent;

  @override
  void initState() {
    super.initState();
    _downloadQuality =
        widget.storage.getSetting('downloadQuality', defaultValue: 'best') ??
            'best';
    _wifiOnly =
        widget.storage.getSetting('wifiOnly', defaultValue: false) ?? false;
    _maxConcurrent =
        widget.storage.getSetting('maxConcurrent', defaultValue: 3) ?? 3;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader('DOWNLOAD'),
            _buildCard([
              _dropdownTile(
                icon: Icons.high_quality,
                title: 'Default quality',
                subtitle: 'Auto-select quality for new downloads',
                value: _downloadQuality,
                items: const [
                  ('best', 'Best available'),
                  ('1080p', '1080p'),
                  ('720p', '720p'),
                  ('480p', '480p'),
                  ('audio', 'Audio only'),
                ],
                onChanged: (v) {
                  setState(() => _downloadQuality = v);
                  widget.storage.setSetting('downloadQuality', v);
                },
              ),
              const Divider(color: AppColors.divider, height: 1),
              _switchTile(
                icon: Icons.wifi,
                title: 'Wi-Fi only',
                subtitle: 'Download only on Wi-Fi',
                value: _wifiOnly,
                onChanged: (v) {
                  setState(() => _wifiOnly = v);
                  widget.storage.setSetting('wifiOnly', v);
                },
              ),
              const Divider(color: AppColors.divider, height: 1),
              _dropdownTile(
                icon: Icons.format_list_numbered,
                title: 'Concurrent downloads',
                subtitle: 'Max simultaneous downloads',
                value: _maxConcurrent.toString(),
                items: const [
                  ('1', '1'),
                  ('2', '2'),
                  ('3', '3'),
                  ('5', '5'),
                ],
                onChanged: (v) {
                  setState(() => _maxConcurrent = int.parse(v));
                  widget.storage.setSetting('maxConcurrent', int.parse(v));
                },
              ),
            ]),
            const SizedBox(height: 24),
            _sectionHeader('BROWSER'),
            _buildCard([
              _actionTile(
                icon: Icons.history,
                title: 'Clear browsing history',
                subtitle: 'Remove all history entries',
                onTap: () {
                  widget.storage.clearHistory();
                  _showSnack('History cleared');
                },
              ),
            ]),
            const SizedBox(height: 24),
            _sectionHeader('ABOUT'),
            _buildCard([
              _infoTile(
                icon: Icons.info_outline,
                title: 'Version',
                trailing: '1.0.0',
              ),
              const Divider(color: AppColors.divider, height: 1),
              _infoTile(
                icon: Icons.code,
                title: 'Built with',
                trailing: 'Flutter',
              ),
              const Divider(color: AppColors.divider, height: 1),
              _infoTile(
                icon: Icons.block,
                title: 'Ads',
                trailing: 'None. Ever.',
              ),
            ]),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Videe',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'Clean downloads. No ads. No tracking.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _dropdownTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      trailing: DropdownButton<String>(
        value: value,
        dropdownColor: AppColors.surface,
        underline: const SizedBox(),
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        items: items
            .map((i) => DropdownMenuItem(value: i.$1, child: Text(i.$2)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent, size: 22),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: Text(trailing,
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary)),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

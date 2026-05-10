import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/song_artwork.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _audioQuality = 'Tinggi';
  bool _downloadWifiOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0E17), AppColors.ink],
            begin: Alignment.topLeft,
            end: FractionalOffset(0.2, 0.55),
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                title: const Text('PENGATURAN'),
                floating: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(18),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const _SectionHeader(title: 'Audio'),
                    const SizedBox(height: 12),
                    AppGlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _SettingsTile(
                            title: 'Kualitas Streaming',
                            subtitle: _audioQuality,
                            icon: Icons.high_quality_rounded,
                            onTap: () {
                              _showQualityPicker();
                            },
                          ),
                          const Divider(height: 1, color: AppColors.line),
                          _SettingsSwitchTile(
                            title: 'Download via Wi-Fi Saja',
                            value: _downloadWifiOnly,
                            icon: Icons.wifi_rounded,
                            onChanged: (val) => setState(() => _downloadWifiOnly = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    const _SectionHeader(title: 'Notifikasi'),
                    const SizedBox(height: 12),
                    AppGlassCard(
                      padding: EdgeInsets.zero,
                      child: _SettingsSwitchTile(
                        title: 'Notifikasi Aplikasi',
                        subtitle: 'Dapatkan info rilis lagu terbaru',
                        value: _notificationsEnabled,
                        icon: Icons.notifications_active_rounded,
                        onChanged: (val) => setState(() => _notificationsEnabled = val),
                      ),
                    ),
                    const SizedBox(height: 26),
                    const _SectionHeader(title: 'Tentang'),
                    const SizedBox(height: 12),
                    AppGlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          const _SettingsTile(
                            title: 'Versi Aplikasi',
                            subtitle: '1.0.0 (Build 20260510)',
                            icon: Icons.info_outline_rounded,
                          ),
                          const Divider(height: 1, color: AppColors.line),
                          _SettingsTile(
                            title: 'Bantuan & Dukungan',
                            subtitle: 'Hubungi kami jika ada kendala',
                            icon: Icons.help_outline_rounded,
                            onTap: () {
                              _showHelpDialog();
                            },
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Bantuan & Dukungan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apa yang bisa kami bantu?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('• Masalah pemutaran lagu\n• Kesalahan data profil\n• Saran dan kritik'),
            const SizedBox(height: 20),
            const Text(
              'Hubungi Admin via Email:',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const Text(
              'admin.ukmband.telu@gmail.com',
              style: TextStyle(color: AppColors.accentHot, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showQualityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ['Hemat Data', 'Normal', 'Tinggi', 'Lossless'].map((q) {
                return ListTile(
                  title: Text(q, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: _audioQuality == q
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.accentHot)
                      : null,
                  onTap: () {
                    setState(() => _audioQuality = q);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accentHot,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.muted),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: AppColors.muted)) : null,
      trailing: onTap != null ? const Icon(Icons.chevron_right_rounded, color: AppColors.muted) : null,
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.muted),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: AppColors.muted)) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.accentHot,
      ),
    );
  }
}

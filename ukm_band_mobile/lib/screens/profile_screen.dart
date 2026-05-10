import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/song_artwork.dart';
import 'welcome_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    ImageProvider imageProvider;
    if (user?.avatarUrl != null) {
      imageProvider = NetworkImage(user!.avatarUrl!);
    } else {
      imageProvider = const AssetImage('assets/img/logo.png');
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('PROFIL SAYA'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0E17), AppColors.ink],
            begin: Alignment.topLeft,
            end: FractionalOffset(0.2, 0.55),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Profile Picture Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentHot.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: imageProvider,
                      backgroundColor: AppColors.cardSoft,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Name
                Text(
                  user?.name ?? 'Pengguna',
                  style: const TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                // Email
                Text(
                  user?.email ?? '-',
                  style: const TextStyle(
                    fontSize: 16, 
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Menu Card
                AppGlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ProfileMenuTile(
                        icon: Icons.edit_rounded,
                        title: 'Edit Profil',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, color: AppColors.line),
                      _ProfileMenuTile(
                        icon: Icons.settings_rounded,
                        title: 'Pengaturan',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      if (authProvider.isAdmin) ...[
                        const Divider(height: 1, color: AppColors.line),
                        _ProfileMenuTile(
                          icon: Icons.admin_panel_settings_rounded,
                          title: 'Admin Panel',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AdminDashboardScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: authProvider.isLoading
                        ? null
                        : () async {
                            await context.read<AuthProvider>().logout();
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WelcomeScreen(),
                              ),
                              (route) => false,
                            );
                          },
                    icon: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(
                      authProvider.isLoading ? 'MEMPROSES...' : 'KELUAR (LOG OUT)',
                      style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB71C1C),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.muted),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}

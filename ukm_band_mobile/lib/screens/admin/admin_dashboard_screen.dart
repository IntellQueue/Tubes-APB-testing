import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/music_provider.dart';
import '../../theme/app_theme.dart';
import 'admin_song_list_screen.dart';
import 'admin_song_form_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

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
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                title: const Text(
                  'Admin Dashboard',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: const Text(
                    'Statistik Aplikasi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cream,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: FutureBuilder<Map<String, dynamic>>(
                  future: context.read<MusicProvider>().getAdminStats(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    
                    final stats = snapshot.data ?? {};
                    final statsList = [
                      {
                        'title': 'Pendengar',
                        'value': '${stats['total_listeners'] ?? 0}',
                        'icon': Icons.headset_rounded,
                        'color': AppColors.accent,
                      },
                      {
                        'title': 'Total Like',
                        'value': '${stats['total_likes'] ?? 0}',
                        'icon': Icons.favorite_rounded,
                        'color': AppColors.accentHot,
                      },
                      {
                        'title': 'Jumlah Lagu',
                        'value': '${stats['total_songs'] ?? 0}',
                        'icon': Icons.music_note_rounded,
                        'color': Colors.blueAccent,
                      },
                      {
                        'title': 'Pengguna',
                        'value': '${stats['total_users'] ?? 0}',
                        'icon': Icons.people_rounded,
                        'color': Colors.orangeAccent,
                      },
                    ];

                    return SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        mainAxisExtent: 110,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = statsList[index];
                          return _StatCard(
                            title: item['title'] as String,
                            value: item['value'] as String,
                            icon: item['icon'] as IconData,
                            color: item['color'] as Color,
                          );
                        },
                        childCount: statsList.length,
                      ),
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'Manajemen Konten',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.cream,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AdminActionTile(
                        title: 'Kelola Daftar Lagu',
                        subtitle: 'Tambah, edit, atau hapus lagu dari perpustakaan.',
                        icon: Icons.library_music_rounded,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdminSongListScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _AdminActionTile(
                        title: 'Upload Lagu Baru',
                        subtitle: 'Tambahkan karya musik terbaru ke UKM Band.',
                        icon: Icons.cloud_upload_rounded,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdminSongFormScreen()),
                          );
                        },
                      ),
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
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.cream,
              ),
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentHot.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.accentHot),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.cream,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

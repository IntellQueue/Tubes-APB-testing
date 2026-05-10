import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/music_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/song_artwork.dart';
import 'admin_song_form_screen.dart';

class AdminSongListScreen extends StatefulWidget {
  const AdminSongListScreen({super.key});

  @override
  State<AdminSongListScreen> createState() => _AdminSongListScreenState();
}

class _AdminSongListScreenState extends State<AdminSongListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteSong(BuildContext context, Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.ink,
        title: const Text('Hapus Lagu?'),
        content: Text('Apakah Anda yakin ingin menghapus "${song.title}"? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentHot),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<MusicProvider>().removeSong(song.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lagu berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus lagu: $e')),
          );
        }
      }
    }
  }

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
          child: Consumer<MusicProvider>(
            builder: (context, music, _) {
              final filteredSongs = music.songs.where((song) {
                final q = _searchQuery.toLowerCase();
                return song.title.toLowerCase().contains(q) ||
                    song.artist.toLowerCase().contains(q);
              }).toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    title: const Text('Daftar Lagu'),
                    actions: [
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdminSongFormScreen()),
                          );
                        },
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    sliver: SliverToBoxAdapter(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Cari judul atau artis...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: AppColors.card.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = filteredSongs[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SongManageTile(
                              song: song,
                              onEdit: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AdminSongFormScreen(song: song),
                                  ),
                                );
                              },
                              onDelete: () => _deleteSong(context, song),
                            ),
                          );
                        },
                        childCount: filteredSongs.length,
                      ),
                    ),
                  ),
                  if (filteredSongs.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'Tidak ada lagu ditemukan.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SongManageTile extends StatelessWidget {
  final Song song;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SongManageTile({
    required this.song,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      child: Row(
        children: [
          SongArtwork(
            source: song.displayCover,
            size: 64,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.headset_rounded, size: 12, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text('${song.plays} plays',
                            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite_rounded, size: 12, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text('${song.likes} likes',
                            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onEdit,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
                tooltip: 'Edit',
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_rounded, color: AppColors.accentHot),
                tooltip: 'Hapus',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/music_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_artwork.dart';
import 'profile_screen.dart';
import 'song_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicProvider>().load();
    });
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 17) return 'Selamat Siang';
    return 'Selamat Malam';
  }

  Future<void> _playSong(Song song, List<Song> queue) async {
    final apiService = context.read<ApiService>();
    final audioProvider = context.read<AudioProvider>();

    try {
      await apiService.recordPlay(song.id);
    } catch (_) {
      // Keep playback running even if tracking API fails.
    }

    if (!mounted) {
      return;
    }

    await audioProvider.playSong(song, queue: queue);
  }

  void _openSong(Song song, List<Song> queue) {
    Navigator.of(context).push(songDetailRoute(song: song, queue: queue));
  }

  Future<void> _toggleLike(Song song) async {
    try {
      await context.read<MusicProvider>().toggleLike(song);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui like: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, music, _) {
        final songs = music.songs;
        final popularSongs = music.popularSongs.take(8).toList();
        final latestSongs = songs.take(10).toList();
        final likedCount = songs.where((song) => song.isLiked).length;

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
              child: RefreshIndicator(
                onRefresh: () => context.read<MusicProvider>().refresh(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 118),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _HomeHeader(greeting: getGreeting()),
                          const SizedBox(height: 22),
                          _HeroPanel(
                            song: latestSongs.isNotEmpty
                                ? latestSongs.first
                                : null,
                            queue: songs,
                            onPlay: _playSong,
                            onOpen: _openSong,
                          ),
                          const SizedBox(height: 26),
                          _HomeStatsStrip(
                            songCount: songs.length,
                            playlistCount: music.playlists.length,
                            likedCount: likedCount,
                          ),
                          const SizedBox(height: 26),
                          if (music.isLoading && !music.hasLoaded)
                            const _LoadingState()
                          else if (music.errorMessage != null && songs.isEmpty)
                            _ErrorState(
                              message: music.errorMessage!,
                              onRetry: () =>
                                  context.read<MusicProvider>().refresh(),
                            )
                          else ...[
                            _PlaylistStrip(
                              playlists: music.playlists,
                              onPlay: (playlist) {
                                if (playlist.songs.isNotEmpty) {
                                  _playSong(
                                    playlist.songs.first,
                                    playlist.songs,
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 28),
                            _SectionTitle(
                              title: 'Paling Populer',
                              subtitle: 'Berdasarkan pemutaran dan like',
                            ),
                            const SizedBox(height: 14),
                            _HorizontalSongList(
                              songs: popularSongs,
                              queue: popularSongs,
                              onOpen: _openSong,
                              onPlay: _playSong,
                              onLike: _toggleLike,
                            ),
                            const SizedBox(height: 30),
                            _SectionTitle(
                              title: 'Recently Added Songs',
                              subtitle: 'Rilis terbaru UKM Band Telkom',
                            ),
                            const SizedBox(height: 14),
                            _HorizontalSongList(
                              songs: latestSongs,
                              queue: latestSongs,
                              onOpen: _openSong,
                              onPlay: _playSong,
                              onLike: _toggleLike,
                            ),
                            const SizedBox(height: 30),
                            _SectionTitle(
                              title: 'Deskripsi Lagu',
                              subtitle: 'Baca cerita singkat sebelum mendengar',
                            ),
                            const SizedBox(height: 14),
                            ...songs
                                .take(5)
                                .map(
                                  (song) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _DescriptionTile(
                                      song: song,
                                      onOpen: () => _openSong(song, songs),
                                      onPlay: () => _playSong(song, songs),
                                    ),
                                  ),
                                ),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String greeting;

  const _HomeHeader({required this.greeting});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    
    ImageProvider avatar;
    if (user?.avatarUrl != null) {
      avatar = NetworkImage(user!.avatarUrl!);
    } else {
      avatar = const AssetImage('assets/img/logo.png');
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Temukan ritme UKM Band hari ini.',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentHot.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: avatar,
              backgroundColor: AppColors.cardSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final Song? song;
  final List<Song> queue;
  final Future<void> Function(Song song, List<Song> queue) onPlay;
  final void Function(Song song, List<Song> queue) onOpen;

  const _HeroPanel({
    required this.song,
    required this.queue,
    required this.onPlay,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final featured = song;

    return AppGlassCard(
      padding: EdgeInsets.zero,
      onTap: featured == null ? null : () => onOpen(featured, queue),
      child: featured == null
          ? const SizedBox(
              height: 130,
              child: Center(
                child: Text(
                  'Belum ada lagu yang tersedia.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.82, -0.7),
                          radius: 1.25,
                          colors: [
                            AppColors.accentHot.withValues(alpha: 0.34),
                            AppColors.card.withValues(alpha: 0.96),
                            AppColors.ink,
                          ],
                          stops: const [0, 0.52, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -36,
                    top: -44,
                    child: Icon(
                      Icons.album_rounded,
                      color: Colors.white.withValues(alpha: 0.045),
                      size: 190,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(
                                            alpha: 0.22,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: AppColors.accentHot
                                                .withValues(alpha: 0.26),
                                          ),
                                        ),
                                        child: const Text(
                                          'Now Featured',
                                          style: TextStyle(
                                            color: AppColors.accentHot,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const _SignalBars(),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    featured.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 26,
                                      height: 1.02,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    featured.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Hero(
                              tag: 'hero-song-${featured.id}',
                              child: SongArtwork(
                                source: featured.displayCover,
                                size: 106,
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                              icon: Icons.play_arrow_rounded,
                              label: '${featured.plays} plays',
                            ),
                            _InfoChip(
                              icon: Icons.favorite_rounded,
                              label: '${featured.likes} likes',
                            ),
                            _InfoChip(
                              icon: Icons.mode_comment_rounded,
                              label: '${featured?.commentsCount ?? 0} comments',
                            ),
                            const _InfoChip(
                              icon: Icons.bolt_rounded,
                              label: 'Fresh drop',
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => onPlay(featured, queue),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Putar Sekarang'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              tooltip: 'Buka detail',
                              onPressed: () => onOpen(featured, queue),
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _HomeStatsStrip extends StatelessWidget {
  final int songCount;
  final int playlistCount;
  final int likedCount;

  const _HomeStatsStrip({
    required this.songCount,
    required this.playlistCount,
    required this.likedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: '$songCount',
            label: 'Tracks',
            icon: Icons.library_music_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: '$playlistCount',
            label: 'Playlist',
            icon: Icons.queue_music_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: '$likedCount',
            label: 'Liked',
            icon: Icons.favorite_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accentHot, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accentHot, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _SignalBar(height: 10),
        _SignalBar(height: 17),
        _SignalBar(height: 12),
        _SignalBar(height: 22),
      ],
    );
  }
}

class _SignalBar extends StatelessWidget {
  final double height;

  const _SignalBar({required this.height});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.45, end: 1),
      duration: Duration(milliseconds: 420 + height.round() * 10),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Container(
          width: 4,
          height: height * value,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: AppColors.accentHot,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      },
    );
  }
}

class _PlaylistStrip extends StatelessWidget {
  final List<Playlist> playlists;
  final ValueChanged<Playlist> onPlay;

  const _PlaylistStrip({required this.playlists, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Playlist Saya',
          subtitle: 'Putar koleksi yang sudah kamu susun',
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.72,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: playlists.length > 6 ? 6 : playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            final cover = playlist.songs.isNotEmpty
                ? playlist.songs.first.displayCover
                : '';

            return AppGlassCard(
              padding: EdgeInsets.zero,
              onTap: playlist.songs.isEmpty ? null : () => onPlay(playlist),
              child: Row(
                children: [
                  SongArtwork(
                    source: cover,
                    size: 58,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      playlist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HorizontalSongList extends StatelessWidget {
  final List<Song> songs;
  final List<Song> queue;
  final void Function(Song song, List<Song> queue) onOpen;
  final Future<void> Function(Song song, List<Song> queue) onPlay;
  final ValueChanged<Song> onLike;

  const _HorizontalSongList({
    required this.songs,
    required this.queue,
    required this.onOpen,
    required this.onPlay,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const AppGlassCard(
        child: Text(
          'Belum ada lagu yang tersedia.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    return SizedBox(
      height: 246,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: songs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = songs[index];
          return _SongCard(
            song: song,
            onOpen: () => onOpen(song, queue),
            onPlay: () => onPlay(song, queue),
            onLike: () => onLike(song),
          );
        },
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onLike;

  const _SongCard({
    required this.song,
    required this.onOpen,
    required this.onPlay,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 154,
      child: AppGlassCard(
        padding: const EdgeInsets.all(10),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SongArtwork(source: song.displayCover, size: 134),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: InkWell(
                    onTap: onPlay,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.35),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const Spacer(),
            Row(
              children: [
                InkWell(
                  onTap: onLike,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Icon(
                      song.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: song.isLiked
                          ? AppColors.accentHot
                          : AppColors.muted,
                    ),
                  ),
                ),
                Text(
                  '${song.likes}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.mode_comment_outlined,
                  size: 18,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${song.commentsCount}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionTile extends StatelessWidget {
  final Song song;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  const _DescriptionTile({
    required this.song,
    required this.onOpen,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      onTap: onOpen,
      child: Row(
        children: [
          SongArtwork(
            source: song.displayCover,
            size: 72,
            borderRadius: BorderRadius.circular(18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  song.description.isEmpty ? song.artist : song.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Putar lagu',
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 42),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.accentHot),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

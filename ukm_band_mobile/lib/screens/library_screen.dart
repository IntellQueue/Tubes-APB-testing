import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/history_entry.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_artwork.dart';
import 'song_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicProvider>().load();
    });
  }

  Future<void> _playSong(Song song, List<Song> queue) async {
    final apiService = context.read<ApiService>();
    final audioProvider = context.read<AudioProvider>();

    try {
      await apiService.recordPlay(song.id);
    } catch (_) {
      // History tracking should not block playback.
    }

    if (!mounted) {
      return;
    }

    await audioProvider.playSong(song, queue: queue);
  }

  void _openSong(Song song, List<Song> queue) {
    Navigator.of(context).push(songDetailRoute(song: song, queue: queue));
  }

  Future<void> _showCreatePlaylistSheet() async {
    final musicProvider = context.read<MusicProvider>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _CreatePlaylistSheet(
          musicProvider: musicProvider,
          onError: (message) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
        );
      },
    );
  }

  Future<void> _renamePlaylist(Playlist playlist) async {
    final controller = TextEditingController(text: playlist.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ubah Nama Playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nama playlist'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newName == null || newName.isEmpty || newName == playlist.name) {
      return;
    }

    if (!mounted) {
      return;
    }

    final musicProvider = context.read<MusicProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await musicProvider.renamePlaylist(playlist, newName);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal mengubah playlist: $error')),
      );
    }
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus playlist?'),
          content: Text('Playlist "${playlist.name}" akan dihapus permanen.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    final musicProvider = context.read<MusicProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await musicProvider.deletePlaylist(playlist);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menghapus playlist: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, music, _) {
        final playlistSongCount = music.playlists.fold<int>(
          0,
          (total, playlist) => total + playlist.songs.length,
        );
        final historySongs = music.history
            .where((entry) => entry.song != null)
            .map((entry) => entry.song!)
            .toList();

        return Scaffold(
          backgroundColor: AppColors.ink,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF07131B), AppColors.ink, Color(0xFF2C080D)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                stops: [0, 0.56, 1],
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: () => context.read<MusicProvider>().refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 118),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pustaka',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Playlist, riwayat, dan lagu yang sering kamu putar.',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filled(
                          tooltip: 'Buat playlist',
                          onPressed: _showCreatePlaylistSheet,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _LibraryHero(
                      playlistCount: music.playlists.length,
                      playlistSongCount: playlistSongCount,
                      historyCount: historySongs.length,
                      onCreate: _showCreatePlaylistSheet,
                    ),
                    const SizedBox(height: 22),
                    if (music.isLoading && !music.hasLoaded)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 42),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (music.errorMessage != null &&
                        music.playlists.isEmpty &&
                        music.history.isEmpty)
                      AppGlassCard(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              color: AppColors.accentHot,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              music.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () =>
                                  context.read<MusicProvider>().refresh(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      const _LibrarySectionTitle(
                        title: 'Playlist Saya',
                      ),
                      const SizedBox(height: 12),
                      if (music.playlists.isEmpty)
                        _EmptyLibraryCard(onCreate: _showCreatePlaylistSheet)
                      else
                        ...music.playlists.asMap().entries.map(
                          (entry) => _LibraryReveal(
                            index: entry.key,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PlaylistCard(
                                playlist: entry.value,
                                onPlay: entry.value.songs.isEmpty
                                    ? null
                                    : () => _playSong(
                                        entry.value.songs.first,
                                        entry.value.songs,
                                      ),
                                onRename: () => _renamePlaylist(entry.value),
                                onDelete: () => _deletePlaylist(entry.value),
                                onOpenSong: (song) =>
                                    _openSong(song, entry.value.songs),
                                onPlaySong: (song) =>
                                    _playSong(song, entry.value.songs),
                                onRemoveSong: (song) async {
                                  final musicProvider = context
                                      .read<MusicProvider>();
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    await musicProvider.removeSongFromPlaylist(
                                      entry.value,
                                      song,
                                    );
                                  } catch (error) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Gagal menghapus lagu: $error',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const _LibrarySectionTitle(title: 'Baru Diputar'),
                      const SizedBox(height: 12),
                      if (music.history.isEmpty)
                        const AppGlassCard(
                          child: Text(
                            'Riwayat pemutaran masih kosong.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      else
                        ...music.history
                            .where((entry) => entry.song != null)
                            .take(20)
                            .toList()
                            .asMap()
                            .entries
                            .map(
                              (entry) => _LibraryReveal(
                                index: entry.key,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _HistoryTile(
                                    entry: entry.value,
                                    onOpen: () => _openSong(
                                      entry.value.song!,
                                      historySongs,
                                    ),
                                    onPlay: () => _playSong(
                                      entry.value.song!,
                                      historySongs,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ],
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

class _CreatePlaylistSheet extends StatefulWidget {
  final MusicProvider musicProvider;
  final ValueChanged<String> onError;

  const _CreatePlaylistSheet({
    required this.musicProvider,
    required this.onError,
  });

  @override
  State<_CreatePlaylistSheet> createState() => _CreatePlaylistSheetState();
}

class _CreatePlaylistSheetState extends State<_CreatePlaylistSheet> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    var shouldResetSaving = true;

    try {
      await widget.musicProvider.createPlaylist(name);
      shouldResetSaving = false;
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      widget.onError('Gagal membuat playlist: $error');
    } finally {
      if (shouldResetSaving && mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.stage,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Buat Playlist Baru',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Nama playlist',
                    prefixIcon: Icon(Icons.queue_music_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: Text(_isSaving ? 'Menyimpan...' : 'Buat'),
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

class _LibraryHero extends StatelessWidget {
  final int playlistCount;
  final int playlistSongCount;
  final int historyCount;
  final VoidCallback onCreate;

  const _LibraryHero({
    required this.playlistCount,
    required this.playlistSongCount,
    required this.historyCount,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF061A22).withValues(alpha: 0.9),
              AppColors.card.withValues(alpha: 0.7),
              AppColors.accent.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Icon(
                    Icons.library_music_rounded,
                    color: AppColors.accentHot,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ruang Koleksi',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Atur setlist pribadi dan buka lagu dengan satu tap.',
                        style: TextStyle(color: AppColors.muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _LibraryStat(
                    value: '$playlistCount',
                    label: 'Playlist',
                    icon: Icons.queue_music_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LibraryStat(
                    value: '$playlistSongCount',
                    label: 'Tersimpan',
                    icon: Icons.bookmark_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LibraryStat(
                    value: '$historyCount',
                    label: 'Riwayat',
                    icon: Icons.history_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Buat Playlist Baru'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _LibraryStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentHot, size: 18),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryReveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _LibraryReveal({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final clampedIndex = index.clamp(0, 8).toInt();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (clampedIndex * 32)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onPlay;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final ValueChanged<Song> onOpenSong;
  final ValueChanged<Song> onPlaySong;
  final ValueChanged<Song> onRemoveSong;

  const _PlaylistCard({
    required this.playlist,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
    required this.onOpenSong,
    required this.onPlaySong,
    required this.onRemoveSong,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PlaylistCover(songs: playlist.songs),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniLibraryPill(
                          icon: Icons.library_music_rounded,
                          label: '${playlist.songs.length} lagu',
                        ),
                        if (playlist.songs.isNotEmpty)
                          const _MiniLibraryPill(
                            icon: Icons.touch_app_rounded,
                            label: 'Tap lagu',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Kelola playlist',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 'rename') {
                    onRename();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Ubah nama')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Putar Playlist'),
            ),
          ),
          const SizedBox(height: 12),
          if (playlist.songs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: const Text(
                'Playlist ini masih kosong. Tambahkan lagu dari halaman detail lagu.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            ...playlist.songs.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == playlist.songs.length - 1 ? 0 : 8,
                ),
                child: _PlaylistSongTile(
                  song: entry.value,
                  position: entry.key + 1,
                  onOpen: () => onOpenSong(entry.value),
                  onPlay: () => onPlaySong(entry.value),
                  onRemove: () => onRemoveSong(entry.value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaylistCover extends StatelessWidget {
  final List<Song> songs;

  const _PlaylistCover({required this.songs});

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: const Icon(
          Icons.queue_music_rounded,
          color: AppColors.accentHot,
        ),
      );
    }

    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: SongArtwork(
              source: songs.first.displayCover,
              size: 58,
              borderRadius: BorderRadius.circular(19),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.accentHot,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLibraryPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniLibraryPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cardSoft.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistSongTile extends StatelessWidget {
  final Song song;
  final int position;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  const _PlaylistSongTile({
    required this.song,
    required this.position,
    required this.onOpen,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.64)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cardSoft.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  '$position',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              SongArtwork(
                source: song.displayCover,
                size: 48,
                borderRadius: BorderRadius.circular(14),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Putar lagu',
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
              ),
              IconButton(
                tooltip: 'Hapus dari playlist',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  const _HistoryTile({
    required this.entry,
    required this.onOpen,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final song = entry.song!;

    return AppGlassCard(
      padding: const EdgeInsets.all(12),
      onTap: onOpen,
      child: Row(
        children: [
          Stack(
            children: [
              SongArtwork(
                source: song.displayCover,
                size: 58,
                borderRadius: BorderRadius.circular(17),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.86),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: AppColors.cream,
                    size: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 3),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatPlayedAt(entry.playedAt),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Putar lagi',
            onPressed: onPlay,
            icon: const Icon(Icons.replay_rounded),
          ),
        ],
      ),
    );
  }

  String _formatPlayedAt(DateTime? time) {
    if (time == null) {
      return '-';
    }

    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$day/$month/${time.year} $hour:$minute';
  }
}

class _EmptyLibraryCard extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyLibraryCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      child: Column(
        children: [
          const Icon(
            Icons.queue_music_outlined,
            color: AppColors.accentHot,
            size: 38,
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada playlist.',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Buat playlist untuk menyimpan lagu favorit dan memutarnya sebagai antrean.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Buat Playlist'),
          ),
        ],
      ),
    );
  }
}

class _LibrarySectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _LibrarySectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}

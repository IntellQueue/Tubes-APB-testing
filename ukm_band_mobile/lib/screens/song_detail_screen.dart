import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../models/song_comment.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/music_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_artwork.dart';

Route<void> songDetailRoute({required Song song, List<Song> queue = const []}) {
  return PageRouteBuilder<void>(
    settings: RouteSettings(name: '/song/${song.id}'),
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) {
      return SongDetailScreen(song: song, queue: queue);
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class SongDetailScreen extends StatefulWidget {
  final Song song;
  final List<Song> queue;

  const SongDetailScreen({
    super.key,
    required this.song,
    this.queue = const [],
  });

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  late Future<List<SongComment>> _commentsFuture;
  int? _replyTo;
  String? _replyToName;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _commentsFuture = _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<List<SongComment>> _loadComments() {
    return context.read<ApiService>().fetchComments(widget.song.id);
  }

  Song _currentSong(MusicProvider music) {
    for (final song in music.songs) {
      if (song.id == widget.song.id) {
        return song;
      }
    }
    return widget.song;
  }

  Future<void> _play(Song song, List<Song> queue) async {
    final api = context.read<ApiService>();
    final audio = context.read<AudioProvider>();

    try {
      await api.recordPlay(song.id);
    } catch (_) {
      // Playback must not depend on analytics/history tracking.
    }

    if (!mounted) {
      return;
    }

    await audio.playSong(song, queue: queue.isEmpty ? [song] : queue);
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

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isPosting) {
      return;
    }

    setState(() => _isPosting = true);

    try {
      await context.read<ApiService>().storeComment(
        songId: widget.song.id,
        content: content,
        parentId: _replyTo,
      );
      if (mounted) {
        context.read<MusicProvider>().incrementCommentCount(widget.song.id);
      }
      _commentController.clear();
      _replyTo = null;
      _replyToName = null;
      _commentsFuture = _loadComments();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Komentar terkirim.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim komentar: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  Future<void> _deleteComment(SongComment comment) async {
    try {
      await context.read<ApiService>().deleteComment(comment.id);
      if (mounted) {
        context.read<MusicProvider>().decrementCommentCount(widget.song.id);
      }
      setState(() {
        _commentsFuture = _loadComments();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus komentar: $error')),
      );
    }
  }

  void _reply(SongComment comment) {
    setState(() {
      _replyTo = comment.id;
      _replyToName = comment.userName;
    });
    _commentFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyTo = null;
      _replyToName = null;
    });
  }

  Future<void> _showPlaylistSheet(Song song) async {
    final nameController = TextEditingController();
    final musicProvider = context.read<MusicProvider>();
    var busyPlaylistId = 0;
    var isCreating = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final music = context.watch<MusicProvider>();
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            Future<void> toggle(Playlist playlist) async {
              if (busyPlaylistId != 0 || isCreating) {
                return;
              }

              setSheetState(() => busyPlaylistId = playlist.id);
              try {
                await musicProvider.toggleSongInPlaylist(playlist, song);
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Gagal mengubah playlist: $error')),
                  );
                }
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => busyPlaylistId = 0);
                }
              }
            }

            Future<void> create() async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                return;
              }

              setSheetState(() => isCreating = true);
              try {
                await musicProvider.createPlaylist(name, seedSong: song);
                nameController.clear();
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Gagal membuat playlist: $error')),
                  );
                }
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isCreating = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.84,
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: AppColors.stage,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
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
                    const SizedBox(height: 20),
                    Text(
                      'Tambahkan ke Playlist',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      song.title,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),
                    Flexible(
                      child: music.playlists.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 28),
                                child: Text(
                                  'Belum ada playlist. Buat playlist pertama untuk menyimpan lagu ini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: music.playlists.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final playlist = music.playlists[index];
                                final inPlaylist = music.playlistContainsSong(
                                  playlist,
                                  song,
                                );
                                final busy = busyPlaylistId == playlist.id;

                                return AppGlassCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  onTap: busy ? null : () => toggle(playlist),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: AppColors.cardSoft,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          inPlaylist
                                              ? Icons.check_rounded
                                              : Icons.playlist_add_rounded,
                                          color: inPlaylist
                                              ? AppColors.success
                                              : AppColors.accentHot,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              playlist.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              '${playlist.songs.length} lagu',
                                              style: const TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (busy)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        Text(
                                          inPlaylist ? 'Sudah ada' : 'Tambah',
                                          style: TextStyle(
                                            color: inPlaylist
                                                ? AppColors.success
                                                : AppColors.accentHot,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => create(),
                            decoration: const InputDecoration(
                              hintText: 'Nama playlist baru',
                              prefixIcon: Icon(Icons.queue_music_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: isCreating ? null : create,
                          child: isCreating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 350));
    nameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MusicProvider, AudioProvider>(
      builder: (context, music, audio, _) {
        final song = _currentSong(music);
        final queue = widget.queue.isEmpty ? music.songs : widget.queue;
        final isCurrent = audio.currentSong?.id == song.id;

        return Scaffold(
          backgroundColor: AppColors.ink,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A0E17), AppColors.ink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    title: const Text('Detail Lagu'),
                    actions: [
                      IconButton(
                        tooltip: 'Playlist',
                        onPressed: () => _showPlaylistSheet(song),
                        icon: const Icon(Icons.playlist_add_rounded),
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _SongDetailHero(
                          song: song,
                          isCurrent: isCurrent,
                          isPlaying: audio.isPlaying,
                        ),
                        const SizedBox(height: 16),
                        if (isCurrent) ...[
                          _SongSeeker(
                            position: audio.position,
                            duration: audio.duration,
                            onSeek: (pos) => audio.seek(pos),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _DetailActionDock(
                          isPlaying: isCurrent && audio.isPlaying,
                          isLiked: song.isLiked,
                          onPlay: () => _play(song, queue),
                          onLike: () => _toggleLike(song),
                          onPlaylist: () => _showPlaylistSheet(song),
                        ),
                        if (audio.playbackError != null && isCurrent) ...[
                          const SizedBox(height: 12),
                          AppGlassCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.accentHot,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    audio.playbackError!,
                                    style: const TextStyle(
                                      color: AppColors.accentHot,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 26),
                        AppGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Deskripsi Lagu',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                song.description.isEmpty
                                    ? 'Belum ada deskripsi untuk lagu ini.'
                                    : song.description,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Komentar',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        _CommentComposer(
                          controller: _commentController,
                          focusNode: _commentFocus,
                          replyToName: _replyToName,
                          isPosting: _isPosting,
                          onCancelReply: _cancelReply,
                          onSubmit: _postComment,
                        ),
                        const SizedBox(height: 18),
                        FutureBuilder<List<SongComment>>(
                          future: _commentsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 28),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return AppGlassCard(
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: AppColors.accentHot,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      snapshot.error.toString(),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _commentsFuture = _loadComments();
                                        });
                                      },
                                      child: const Text('Muat ulang'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final comments = snapshot.data ?? [];
                            if (comments.isEmpty) {
                              return const AppGlassCard(
                                child: Text(
                                  'Belum ada komentar. Jadilah yang pertama.',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              );
                            }

                            final user = context.watch<AuthProvider>().user;
                            return Column(
                              children: comments
                                  .map(
                                    (comment) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12.0,
                                      ),
                                      child: _CommentCard(
                                        comment: comment,
                                        currentUserId: user?.id,
                                        isAdmin: user?.role == 'admin',
                                        onReply: _reply,
                                        onDelete: _deleteComment,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SongDetailHero extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final bool isPlaying;

  const _SongDetailHero({
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final artworkSize = (screenWidth - 92).clamp(210.0, 330.0).toDouble();

    return AppGlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.18),
              AppColors.card.withValues(alpha: 0.76),
              const Color(0xFF071018).withValues(alpha: 0.82),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LiveBadge(isPlaying: isCurrent && isPlaying),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Text(
                    'DETAIL TRACK',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: artworkSize + 32,
                  height: artworkSize + 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.ink.withValues(alpha: 0.4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.28),
                        blurRadius: 52,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: isCurrent && isPlaying ? 1 : 0.97,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: SongArtwork(
                    source: song.displayCover,
                    size: artworkSize,
                    borderRadius: BorderRadius.circular(34),
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 16,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.accentHot,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ink, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentHot.withValues(alpha: 0.38),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Icon(
                      isCurrent && isPlaying
                          ? Icons.graphic_eq_rounded
                          : Icons.music_note_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              song.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              song.artist,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.accentHot,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricChip(
                  icon: Icons.play_arrow_rounded,
                  label: '${song.plays} plays',
                ),
                _MetricChip(
                  icon: song.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${song.likes} likes',
                  active: song.isLiked,
                ),
                const _MetricChip(
                  icon: Icons.touch_app_rounded,
                  label: 'tap actions',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final bool isPlaying;

  const _LiveBadge({required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: isPlaying
            ? AppColors.accent.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isPlaying ? AppColors.accentHot : AppColors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPlaying ? Icons.equalizer_rounded : Icons.album_rounded,
            size: 15,
            color: isPlaying ? AppColors.accentHot : AppColors.muted,
          ),
          const SizedBox(width: 6),
          Text(
            isPlaying ? 'LIVE PLAYING' : 'READY TO PLAY',
            style: TextStyle(
              color: isPlaying ? AppColors.cream : AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailActionDock extends StatelessWidget {
  final bool isPlaying;
  final bool isLiked;
  final VoidCallback onPlay;
  final VoidCallback onLike;
  final VoidCallback onPlaylist;

  const _DetailActionDock({
    required this.isPlaying,
    required this.isLiked,
    required this.onPlay,
    required this.onLike,
    required this.onPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPlay,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(isPlaying ? 'Sedang Diputar' : 'Putar Sekarang'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionPill(
                  label: isLiked ? 'Disukai' : 'Like',
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  active: isLiked,
                  onTap: onLike,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionPill(
                  label: 'Playlist',
                  icon: Icons.playlist_add_rounded,
                  onTap: onPlaylist,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _ActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.22)
              : AppColors.cardSoft.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? AppColors.accentHot : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? AppColors.accentHot : AppColors.cream,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _MetricChip({
    required this.icon,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? AppColors.accent.withValues(alpha: 0.18)
            : AppColors.card.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? AppColors.accentHot : AppColors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: active ? AppColors.accentHot : AppColors.muted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? AppColors.cream : AppColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyToName;
  final bool isPosting;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmit;

  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.replyToName,
    required this.isPosting,
    required this.onCancelReply,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyToName != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Membalas $replyToName',
                    style: const TextStyle(
                      color: AppColors.accentHot,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onCancelReply,
                  child: const Text('Batal'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Tulis komentar...',
                    prefixIcon: Icon(Icons.mode_comment_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: isPosting ? null : onSubmit,
                icon: isPosting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(isPosting ? 'Mengirim...' : 'Kirim'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final SongComment comment;
  final int? currentUserId;
  final bool isAdmin;
  final ValueChanged<SongComment> onReply;
  final ValueChanged<SongComment> onDelete;

  const _CommentCard({
    required this.comment,
    required this.currentUserId,
    required this.isAdmin,
    required this.onReply,
    required this.onDelete,
  });

  bool get _canManage => isAdmin || currentUserId == comment.userId;

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.accent.withValues(alpha: 0.22),
                foregroundColor: AppColors.cream,
                child: Text(
                  comment.userName.isEmpty
                      ? 'U'
                      : comment.userName.characters.first.toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(comment.createdAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_canManage)
                IconButton(
                  tooltip: 'Hapus komentar',
                  onPressed: () => onDelete(comment),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.accentHot,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(comment.content, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => onReply(comment),
            icon: const Icon(Icons.reply_rounded, size: 18),
            label: const Text('Balas'),
          ),
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(left: 14),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.line)),
              ),
              child: Column(
                children: comment.replies.map((reply) {
                  final canManageReply =
                      isAdmin || currentUserId == reply.userId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: AppColors.cardSoft,
                          foregroundColor: AppColors.cream,
                          child: Text(
                            reply.userName.isEmpty
                                ? 'U'
                                : reply.userName.characters.first.toUpperCase(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reply.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reply.content,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canManageReply)
                          IconButton(
                            tooltip: 'Hapus balasan',
                            onPressed: () => onDelete(reply),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) {
      return 'Baru saja';
    }

    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return 'Baru saja';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} menit lalu';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} jam lalu';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} hari lalu';
    }

    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    return '$day/$month/${time.year}';
  }
}

class _SongSeeker extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _SongSeeker({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final double maxVal = duration.inMilliseconds.toDouble();
    final double currentVal = position.inMilliseconds.toDouble().clamp(0.0, maxVal);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: AppColors.accentHot,
            inactiveTrackColor: AppColors.line,
            thumbColor: AppColors.accentHot,
            overlayColor: AppColors.accentHot.withOpacity(0.12),
          ),
          child: Slider(
            value: currentVal,
            max: maxVal > 0 ? maxVal : 1.0,
            onChanged: (val) {
              onSeek(Duration(milliseconds: val.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


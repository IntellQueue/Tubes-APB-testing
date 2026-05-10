import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/song_artwork.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'song_detail_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicProvider>().load(force: true);
    });
  }

  void _openCurrentSong(Song song) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SongDetailScreen(
          song: song,
          queue: context.read<AudioProvider>().queue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, _) {
        final song = audioProvider.currentSong;
        final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
        const navigationBarSpace = 88.0;

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              IndexedStack(index: _selectedIndex, children: _pages),
              if (song != null)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: bottomSafeArea + navigationBarSpace,
                  child: _MiniPlayer(
                    song: song,
                    audioProvider: audioProvider,
                    onOpen: () => _openCurrentSong(song),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Beranda',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.manage_search_rounded),
                label: 'Cari',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music_rounded),
                label: 'Pustaka',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  final Song song;
  final AudioProvider audioProvider;
  final VoidCallback onOpen;

  const _MiniPlayer({
    required this.song,
    required this.audioProvider,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final duration = audioProvider.duration.inMilliseconds > 0
        ? audioProvider.duration.inMilliseconds
        : 1;
    final position = audioProvider.position.inMilliseconds.clamp(0, duration);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.36),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SongArtwork(
                    source: song.displayCover,
                    size: 50,
                    borderRadius: BorderRadius.circular(16),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          audioProvider.playbackError ?? song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: audioProvider.playbackError == null
                                ? AppColors.muted
                                : AppColors.accentHot,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sebelumnya',
                    onPressed: audioProvider.canPlayPrevious
                        ? () => audioProvider.playPrevious()
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  IconButton.filled(
                    tooltip: audioProvider.isPlaying ? 'Jeda' : 'Putar',
                    onPressed: audioProvider.isLoading
                        ? null
                        : () {
                            if (audioProvider.isPlaying) {
                              audioProvider.pause();
                            } else {
                              audioProvider.resume();
                            }
                          },
                    icon: audioProvider.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            audioProvider.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                  ),
                  IconButton(
                    tooltip: 'Berikutnya',
                    onPressed: audioProvider.canPlayNext
                        ? () => audioProvider.playNext()
                        : null,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 0,
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                  trackHeight: 3,
                  activeTrackColor: AppColors.accentHot,
                  inactiveTrackColor: AppColors.line,
                ),
                child: Slider(
                  min: 0,
                  max: duration.toDouble(),
                  value: position.toDouble(),
                  onChanged: (value) {
                    audioProvider.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

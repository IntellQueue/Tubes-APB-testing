import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/song.dart';

class AudioProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _playbackError;

  AudioProvider() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      _duration = newDuration;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      _position = newPosition;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) async {
      if (canPlayNext) {
        await playNext();
      } else {
        _isPlaying = false;
        _position = _duration;
        notifyListeners();
      }
    });
  }

  Song? get currentSong => _currentSong;
  List<Song> get queue => _queue;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get duration => _duration;
  Duration get position => _position;
  String? get playbackError => _playbackError;
  bool get canPlayNext =>
      _currentIndex >= 0 && _currentIndex < _queue.length - 1;
  bool get canPlayPrevious =>
      _currentIndex > 0 && _currentIndex < _queue.length;

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    if (queue != null && queue.isNotEmpty) {
      _queue = List<Song>.from(queue);
      _currentIndex = _queue.indexWhere((item) => item.id == song.id);
      if (_currentIndex == -1) {
        _queue.insert(0, song);
        _currentIndex = 0;
      }
    } else if (_queue.isNotEmpty) {
      final existingIndex = _queue.indexWhere((item) => item.id == song.id);
      if (existingIndex >= 0) {
        _currentIndex = existingIndex;
      } else {
        _queue = [song];
        _currentIndex = 0;
      }
    } else {
      _queue = [song];
      _currentIndex = 0;
    }

    await _audioPlayer.stop();

    _currentSong = song;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();

    _isLoading = true;
    _playbackError = null;
    notifyListeners();

    debugPrint('Memutar lagu: ${song.title} (ID: ${song.id})');

    final candidates = song.playbackCandidates.isNotEmpty
        ? song.playbackCandidates
        : [song.playbackUrl];

    Object? lastError;
    for (final candidate in candidates) {
      try {
        await _audioPlayer.play(_sourceFor(candidate));
        _isLoading = false;
        _playbackError = null;
        notifyListeners();
        return;
      } catch (error) {
        lastError = error;
        debugPrint('Error playing audio source "$candidate": $error');
      }
    }

    _isLoading = false;
    _isPlaying = false;
    _playbackError =
        'Audio tidak dapat diputar. Pastikan file audio lokal valid.';
    notifyListeners();
    debugPrint('All audio sources failed for ${song.title}: $lastError');
  }

  Future<void> playNext() async {
    if (!canPlayNext) {
      return;
    }

    _currentIndex += 1;
    final nextSong = _queue[_currentIndex];
    await playSong(nextSong, queue: _queue);
  }

  Future<void> playPrevious() async {
    if (!canPlayPrevious) {
      return;
    }

    _currentIndex -= 1;
    final previousSong = _queue[_currentIndex];
    await playSong(previousSong, queue: _queue);
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  Future<void> seek(Duration pos) async {
    await _audioPlayer.seek(pos);
  }

  Source _sourceFor(String rawPath) {
    var sourcePath = rawPath.trim();

    if (sourcePath.startsWith('http://') || sourcePath.startsWith('https://')) {
      return UrlSource(sourcePath);
    }

    if (sourcePath.startsWith('/')) {
      sourcePath = sourcePath.substring(1);
    }

    if (sourcePath.startsWith('public/')) {
      sourcePath = sourcePath.substring(7);
    }

    if (sourcePath.startsWith('assets/')) {
      sourcePath = sourcePath.substring(7);
    }

    return AssetSource(sourcePath);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

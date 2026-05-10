import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/api_service.dart';

class MusicProvider with ChangeNotifier {
  final ApiService _apiService;

  List<Song> _songs = [];
  List<Playlist> _playlists = [];
  List<HistoryEntry> _history = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  MusicProvider(this._apiService);

  List<Song> get songs => List.unmodifiable(_songs);
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  List<HistoryEntry> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  List<Song> get popularSongs {
    final ordered = [..._songs]
      ..sort((a, b) {
        final bScore = b.plays + (b.likes * 2);
        final aScore = a.plays + (a.likes * 2);
        return bScore.compareTo(aScore);
      });
    return ordered;
  }

  Future<void> load({bool force = false}) async {
    if (_isLoading || (_hasLoaded && !force)) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final songs = await _apiService.fetchSongs();
      final playlists = await _apiService.fetchPlaylists();
      final history = await _apiService.fetchHistory();

      _songs = songs;
      _playlists = playlists;
      _history = history;
      _hasLoaded = true;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(force: true);

  Future<Song> toggleLike(Song song) async {
    final previous = _findSong(song.id) ?? song;
    final optimistic = previous.copyWith(
      isLiked: !previous.isLiked,
      likes: previous.isLiked
          ? (previous.likes - 1).clamp(0, 1 << 31).toInt()
          : previous.likes + 1,
    );

    _replaceSong(optimistic);
    notifyListeners();

    try {
      final result = await _apiService.toggleLike(song.id);
      final confirmed = optimistic.copyWith(
        likes: result.likes,
        isLiked: result.status == 'liked',
      );
      _replaceSong(confirmed);
      notifyListeners();
      return confirmed;
    } catch (error) {
      _replaceSong(previous);
      notifyListeners();
      rethrow;
    }
  }

  Future<Playlist> createPlaylist(String name, {Song? seedSong}) async {
    final playlist = await _apiService.createPlaylist(name.trim());
    _playlists = [playlist, ..._playlists];
    notifyListeners();

    if (seedSong == null) {
      return playlist;
    }

    return toggleSongInPlaylist(playlist, seedSong);
  }

  Future<Playlist> renamePlaylist(Playlist playlist, String name) async {
    final updated = await _apiService.renamePlaylist(
      playlistId: playlist.id,
      name: name.trim(),
    );
    _replacePlaylist(updated);
    notifyListeners();
    return updated;
  }

  Future<Playlist> toggleSongInPlaylist(Playlist playlist, Song song) async {
    final updated = await _apiService.togglePlaylistSong(
      playlistId: playlist.id,
      songId: song.id,
    );
    _replacePlaylist(updated);
    notifyListeners();
    return updated;
  }

  Future<Playlist> removeSongFromPlaylist(Playlist playlist, Song song) async {
    final updated = await _apiService.removePlaylistSong(
      playlistId: playlist.id,
      songId: song.id,
    );
    _replacePlaylist(updated);
    notifyListeners();
    return updated;
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    await _apiService.deletePlaylist(playlist.id);
    _playlists = _playlists.where((item) => item.id != playlist.id).toList();
    notifyListeners();
  }

  bool playlistContainsSong(Playlist playlist, Song song) {
    return playlist.songs.any((item) => item.id == song.id);
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    return _apiService.fetchAdminStats();
  }

  Future<void> addSong({
    required String title,
    required String artist,
    required String description,
    String? coverPath,
    String? filePath,
  }) async {
    final song = await _apiService.createSong(
      title: title,
      artist: artist,
      description: description,
      coverPath: coverPath,
      filePath: filePath,
    );
    _songs = [..._songs, song];
    notifyListeners();
  }

  Future<void> editSong({
    required int id,
    String? title,
    String? artist,
    String? description,
    String? coverPath,
    String? filePath,
  }) async {
    final updated = await _apiService.updateSong(
      id: id,
      title: title,
      artist: artist,
      description: description,
      coverPath: coverPath,
      filePath: filePath,
    );
    _replaceSong(updated);
    notifyListeners();
  }

  Future<void> removeSong(int id) async {
    await _apiService.deleteSong(id);
    _songs = _songs.where((s) => s.id != id).toList();
    notifyListeners();
  }

  void incrementCommentCount(int songId) {
    final song = _findSong(songId);
    if (song != null) {
      _replaceSong(song.copyWith(commentsCount: song.commentsCount + 1));
      notifyListeners();
    }
  }

  void decrementCommentCount(int songId) {
    final song = _findSong(songId);
    if (song != null) {
      _replaceSong(song.copyWith(
        commentsCount: (song.commentsCount - 1).clamp(0, 1 << 31).toInt(),
      ));
      notifyListeners();
    }
  }

  Song? _findSong(int songId) {
    for (final song in _songs) {
      if (song.id == songId) {
        return song;
      }
    }

    for (final playlist in _playlists) {
      for (final song in playlist.songs) {
        if (song.id == songId) {
          return song;
        }
      }
    }

    return null;
  }

  void _replaceSong(Song updated) {
    _songs = _songs
        .map((song) => song.id == updated.id ? updated : song)
        .toList();

    _playlists = _playlists.map((playlist) {
      return playlist.copyWith(
        songs: playlist.songs
            .map((song) => song.id == updated.id ? updated : song)
            .toList(),
      );
    }).toList();
  }

  void _replacePlaylist(Playlist updated) {
    final exists = _playlists.any((playlist) => playlist.id == updated.id);
    if (exists) {
      _playlists = _playlists
          .map((playlist) => playlist.id == updated.id ? updated : playlist)
          .toList();
    } else {
      _playlists = [updated, ..._playlists];
    }
  }
}

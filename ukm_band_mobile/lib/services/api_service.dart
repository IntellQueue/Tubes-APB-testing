import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/history_entry.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/song_comment.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthResult {
  final String token;
  final AppUser user;

  const AuthResult({required this.token, required this.user});
}

class LikeResult {
  final String status;
  final int likes;

  const LikeResult({required this.status, required this.likes});
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );
  static const bool localFirst = bool.fromEnvironment(
    'LOCAL_FIRST',
    defaultValue: true,
  );
  static const String _localUsersKey = 'ukm_band_local_users_v1';
  static const String _localPlaylistsKey = 'ukm_band_local_playlists_v1';
  static const String _localHistoryKey = 'ukm_band_local_history_v1';
  static const String _localCommentsKey = 'ukm_band_local_comments_v1';
  static const String _localPlaysKey = 'ukm_band_local_plays_v1';
  static const String _localLikesPrefix = 'ukm_band_local_likes_';
  static const String _localSongsKey = 'ukm_band_local_songs_v1';
  static const List<Map<String, dynamic>> _localSongs = [
    {
      'id': 1,
      'title': 'Prisoner',
      'artist': 'Secrets',
      'description':
          'Lagu ini menggambarkan perasaan terkurung oleh pikiran dan rahasia yang selama ini dipendam.',
      'cover_path': 'assets/img/c5.jpg',
      'file_path': 'assets/songs/Prisoner.wav',
      'plays': 120,
      'likes': 45,
    },
    {
      'id': 2,
      'title': 'Strangled',
      'artist': 'Dystopia',
      'description':
          'Sebuah lagu bernuansa intens tentang tekanan, kekacauan, dan rasa tercekik oleh keadaan.',
      'cover_path': 'assets/img/c3.jpg',
      'file_path': 'assets/songs/Dystopia.wav',
      'plays': 200,
      'likes': 90,
    },
    {
      'id': 3,
      'title': 'New World',
      'artist': 'The Overtrain',
      'description':
          'Lagu ini bercerita tentang perjalanan menuju perubahan dan awal yang baru.',
      'cover_path': 'assets/img/c7.jpg',
      'file_path': 'assets/songs/The Overtrain.wav',
      'plays': 180,
      'likes': 75,
    },
    {
      'id': 4,
      'title': 'Langit Kelabu',
      'artist': 'The Harper',
      'description':
          'Lagu ini membawa suasana sendu dan melankolis, seperti langit mendung yang mencerminkan hati.',
      'cover_path': 'assets/img/c6.jpg',
      'file_path': 'assets/songs/The Harper.wav',
      'plays': 110,
      'likes': 55,
    },
    {
      'id': 5,
      'title': 'Form',
      'artist': 'Coral',
      'description':
          'Sebuah lagu reflektif tentang pencarian jati diri dan proses perubahan dalam hidup.',
      'cover_path': 'assets/img/c2.jpg',
      'file_path': 'assets/songs/Coral.wav',
      'plays': 85,
      'likes': 30,
    },
    {
      'id': 6,
      'title': 'Au Revoir',
      'artist': 'Elisya',
      'description':
          'Lagu ini menggambarkan perpisahan yang lembut namun penuh makna.',
      'cover_path': 'assets/img/c4.jpg',
      'file_path': 'assets/songs/Elisya.wav',
      'plays': 150,
      'likes': 60,
    },
    {
      'id': 7,
      'title': 'Lust',
      'artist': "Bachelor's Thrill",
      'description':
          'Lagu penuh energi tentang hasrat, ketertarikan, dan dorongan emosi yang kuat.',
      'cover_path': 'assets/img/c1.jpg',
      'file_path': 'assets/songs/Lust.wav',
      'plays': 120,
      'likes': 45,
    },
  ];

  String? _token;

  String? get token => _token;

  void setAuthToken(String? token) {
    _token = token;
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (localFirst) {
      return _localRegister(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
    }

    final data = await _request(
      method: 'POST',
      path: '/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      requiresAuth: false,
    );

    return _parseAuthResult(data);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    if (localFirst) {
      return _localLogin(email: email, password: password);
    }

    final data = await _request(
      method: 'POST',
      path: '/login',
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );

    return _parseAuthResult(data);
  }

  Future<AppUser> fetchMe() async {
    if (localFirst || _isLocalSession) {
      return _localFetchMe();
    }

    final data = await _request(method: 'GET', path: '/me');
    return AppUser.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    if (localFirst || _isLocalSession) {
      return;
    }

    await _request(method: 'POST', path: '/logout');
  }

  Future<AppUser> updateProfile({
    required String name,
    required String email,
    String? avatarPath,
  }) async {
    if (localFirst || _isLocalSession) {
      return _localUpdateProfile(name: name, email: email, avatarPath: avatarPath);
    }

    final uri = Uri.parse('$baseUrl/profile');
    final request = http.MultipartRequest('POST', uri);
    
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.headers['Accept'] = 'application/json';

    request.fields['name'] = name;
    request.fields['email'] = email;

    if (avatarPath != null) {
      request.files.add(await http.MultipartFile.fromPath('avatar', avatarPath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      return AppUser.fromJson(data['data'] as Map<String, dynamic>);
    } else {
      final decoded = json.decode(response.body);
      final message = decoded['message'] ?? 'Gagal memperbarui profil';
      throw ApiException(message, statusCode: response.statusCode);
    }
  }

  Future<List<Song>> fetchSongs({String? query}) async {
    if (localFirst || _isLocalSession) {
      return _localFetchSongs(query: query);
    }

    final q = query?.trim();
    final data = await _request(
      method: 'GET',
      path: q == null || q.isEmpty
          ? '/songs'
          : '/songs?q=${Uri.encodeQueryComponent(q)}',
    );
    final items = data['data'] as List<dynamic>? ?? [];
    return items
        .map((item) => Song.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Playlist>> fetchPlaylists() async {
    if (localFirst || _isLocalSession) {
      return _localFetchPlaylists();
    }

    final data = await _request(method: 'GET', path: '/playlists');
    final items = data['data'] as List<dynamic>? ?? [];
    return items
        .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Playlist> createPlaylist(String name) async {
    if (localFirst || _isLocalSession) {
      return _localCreatePlaylist(name);
    }

    final data = await _request(
      method: 'POST',
      path: '/playlists',
      body: {'name': name},
    );

    return Playlist.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<Playlist> renamePlaylist({
    required int playlistId,
    required String name,
  }) async {
    if (localFirst || _isLocalSession) {
      return _localRenamePlaylist(playlistId: playlistId, name: name);
    }

    final data = await _request(
      method: 'PUT',
      path: '/playlists/$playlistId',
      body: {'name': name},
    );

    return Playlist.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<Playlist> togglePlaylistSong({
    required int playlistId,
    required int songId,
  }) async {
    if (localFirst || _isLocalSession) {
      return _localTogglePlaylistSong(playlistId: playlistId, songId: songId);
    }

    final data = await _request(
      method: 'PUT',
      path: '/playlists/$playlistId',
      body: {'song_id': songId},
    );

    return Playlist.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<Playlist> removePlaylistSong({
    required int playlistId,
    required int songId,
  }) async {
    if (localFirst || _isLocalSession) {
      return _localRemovePlaylistSong(playlistId: playlistId, songId: songId);
    }

    final data = await _request(
      method: 'PUT',
      path: '/playlists/$playlistId',
      body: {'remove_song_id': songId},
    );

    return Playlist.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> deletePlaylist(int playlistId) async {
    if (localFirst || _isLocalSession) {
      return _localDeletePlaylist(playlistId);
    }

    await _request(method: 'DELETE', path: '/playlists/$playlistId');
  }

  Future<List<HistoryEntry>> fetchHistory() async {
    if (localFirst || _isLocalSession) {
      return _localFetchHistory();
    }

    final data = await _request(method: 'GET', path: '/history');
    final items = data['data'] as List<dynamic>? ?? [];
    return items
        .map((item) => HistoryEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> recordPlay(int songId) async {
    if (localFirst || _isLocalSession) {
      return _localRecordPlay(songId);
    }

    await _request(method: 'POST', path: '/songs/$songId/record-play');
  }

  Future<LikeResult> toggleLike(int songId) async {
    if (localFirst || _isLocalSession) {
      return _localToggleLike(songId);
    }

    final data = await _request(method: 'POST', path: '/songs/$songId/like');
    final payload = data['data'] as Map<String, dynamic>? ?? {};

    return LikeResult(
      status: data['status']?.toString() ?? '',
      likes: payload['likes'] ?? 0,
    );
  }

  Future<List<SongComment>> fetchComments(int songId) async {
    if (localFirst || _isLocalSession) {
      return _localFetchComments(songId);
    }

    final data = await _request(method: 'GET', path: '/songs/$songId/comments');
    final items = data['data'] as List<dynamic>? ?? [];
    return items
        .map((item) => SongComment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SongComment> storeComment({
    required int songId,
    required String content,
    int? parentId,
  }) async {
    if (localFirst || _isLocalSession) {
      return _localStoreComment(
        songId: songId,
        content: content,
        parentId: parentId,
      );
    }

    final data = await _request(
      method: 'POST',
      path: '/songs/$songId/comments',
      body: {'content': content, 'parent_id': parentId},
    );

    return SongComment.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<SongComment> updateComment({
    required int commentId,
    required String content,
  }) async {
    if (localFirst || _isLocalSession) {
      return _localUpdateComment(commentId: commentId, content: content);
    }

    final data = await _request(
      method: 'PUT',
      path: '/comments/$commentId',
      body: {'content': content},
    );

    return SongComment.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteComment(int commentId) async {
    if (localFirst || _isLocalSession) {
      return _localDeleteComment(commentId);
    }

    await _request(method: 'DELETE', path: '/comments/$commentId');
  }

  Future<Map<String, dynamic>> fetchAdminStats() async {
    if (localFirst || _isLocalSession) {
      return _localFetchAdminStats();
    }

    final data = await _request(method: 'GET', path: '/admin/stats');
    return data['data'] as Map<String, dynamic>;
  }

  Future<Song> createSong({
    required String title,
    required String artist,
    required String description,
    String? coverPath,
    String? filePath,
  }) async {
    if (localFirst || _isLocalSession) {
      return _localCreateSong(
        title: title,
        artist: artist,
        description: description,
        coverPath: coverPath,
        filePath: filePath,
      );
    }

    final uri = Uri.parse('$baseUrl/admin/songs');
    final request = http.MultipartRequest('POST', uri);
    
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.headers['Accept'] = 'application/json';

    request.fields['title'] = title;
    request.fields['artist'] = artist;
    request.fields['description'] = description;

    if (coverPath != null) {
      request.files.add(await http.MultipartFile.fromPath('cover', coverPath));
    }
    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      return Song.fromJson(data['data'] as Map<String, dynamic>);
    } else {
      final decoded = json.decode(response.body);
      final message = decoded['message'] ?? 'Gagal mengunggah lagu';
      throw ApiException(message, statusCode: response.statusCode);
    }
  }

  Future<Song> updateSong({
    required int id,
    String? title,
    String? artist,
    String? description,
    String? coverPath,
    String? filePath,
  }) async {
    if (localFirst || _isLocalSession) {
      return _localUpdateSong(
        id: id,
        title: title,
        artist: artist,
        description: description,
        coverPath: coverPath,
        filePath: filePath,
      );
    }

    final uri = Uri.parse('$baseUrl/admin/songs/$id');
    final request = http.MultipartRequest('POST', uri); // Using POST for multipart update
    
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.headers['Accept'] = 'application/json';
    request.fields['_method'] = 'PUT';

    if (title != null) request.fields['title'] = title;
    if (artist != null) request.fields['artist'] = artist;
    if (description != null) request.fields['description'] = description;

    if (coverPath != null) {
      request.files.add(await http.MultipartFile.fromPath('cover', coverPath));
    }
    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      return Song.fromJson(data['data'] as Map<String, dynamic>);
    } else {
      final decoded = json.decode(response.body);
      final message = decoded['message'] ?? 'Gagal memperbarui lagu';
      throw ApiException(message, statusCode: response.statusCode);
    }
  }

  Future<void> deleteSong(int id) async {
    if (localFirst || _isLocalSession) {
      return _localDeleteSong(id);
    }

    await _request(method: 'DELETE', path: '/admin/songs/$id');
  }

  bool get _isLocalSession => _token?.startsWith('local:') ?? false;

  int get _currentLocalUserId {
    final token = _token;
    final parts = token?.split(':') ?? const [];
    if (parts.length >= 2 && parts.first == 'local') {
      final id = int.tryParse(parts[1]);
      if (id != null) {
        return id;
      }
    }
    throw ApiException('Sesi lokal tidak tersedia. Silakan login kembali.');
  }

  String _localTokenFor(int userId) {
    return 'local:$userId:${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<AuthResult> _localRegister({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (password != passwordConfirmation) {
      throw ApiException('Konfirmasi kata sandi tidak cocok.');
    }
    if (password.length < 8) {
      throw ApiException('Kata sandi minimal 8 karakter.');
    }

    await _ensureLocalSeed();
    final users = await _readJsonList(_localUsersKey);
    final normalizedEmail = email.trim().toLowerCase();
    final exists = users.any(
      (user) => user['email']?.toString().toLowerCase() == normalizedEmail,
    );

    if (exists) {
      throw ApiException('Email sudah terdaftar di mode lokal.');
    }

    final nextId = _nextId(users);
    final user = <String, dynamic>{
      'id': nextId,
      'name': name.trim(),
      'email': normalizedEmail,
      'password': password,
      'role': 'user',
    };

    users.add(user);
    await _writeJsonList(_localUsersKey, users);

    final appUser = AppUser.fromJson(user);
    final token = _localTokenFor(appUser.id);
    _token = token;
    return AuthResult(token: token, user: appUser);
  }

  Future<AuthResult> _localLogin({
    required String email,
    required String password,
  }) async {
    await _ensureLocalSeed();
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readJsonList(_localUsersKey);

    Map<String, dynamic>? matched;
    for (final user in users) {
      if (user['email']?.toString().toLowerCase() == normalizedEmail &&
          user['password'] == password) {
        matched = user;
        break;
      }
    }

    if (matched == null) {
      throw ApiException('Email atau kata sandi salah.');
    }

    final appUser = AppUser.fromJson(matched);
    final token = _localTokenFor(appUser.id);
    _token = token;
    return AuthResult(token: token, user: appUser);
  }

  Future<AppUser> _localFetchMe() async {
    await _ensureLocalSeed();
    final userId = _currentLocalUserId;
    final users = await _readJsonList(_localUsersKey);
    final user = users.cast<Map<String, dynamic>>().firstWhere(
      (item) => item['id'] == userId,
      orElse: () => throw ApiException('User lokal tidak ditemukan.'),
    );
    return AppUser.fromJson(user);
  }

  Future<AppUser> _localUpdateProfile({
    required String name,
    required String email,
    String? avatarPath,
  }) async {
    await _ensureLocalSeed();
    final userId = _currentLocalUserId;
    final users = await _readJsonList(_localUsersKey);
    final normalizedEmail = email.trim().toLowerCase();

    final emailExists = users.any(
      (u) => u['id'] != userId && u['email']?.toString().toLowerCase() == normalizedEmail,
    );

    if (emailExists) {
      throw ApiException('Email sudah digunakan oleh pengguna lain.');
    }

    final index = users.indexWhere((item) => item['id'] == userId);
    if (index == -1) {
      throw ApiException('User lokal tidak ditemukan.');
    }

    users[index]['name'] = name.trim();
    users[index]['email'] = normalizedEmail;
    
    // For local mock, we just store the path
    if (avatarPath != null) {
      users[index]['avatar_url'] = avatarPath;
    }

    await _writeJsonList(_localUsersKey, users);
    return AppUser.fromJson(users[index] as Map<String, dynamic>);
  }

  Future<List<Song>> _localFetchSongs({String? query}) async {
    await _ensureLocalSeed();
    final payloads = await _localSongPayloads();
    final q = query?.trim().toLowerCase();
    final filtered = q == null || q.isEmpty
        ? payloads
        : payloads.where((song) {
            return song['title'].toString().toLowerCase().contains(q) ||
                song['artist'].toString().toLowerCase().contains(q);
          }).toList();

    return filtered.map((json) => Song.fromJson(json)).toList();
  }

  Future<List<Playlist>> _localFetchPlaylists() async {
    await _ensureLocalSeed();
    final userId = _currentLocalUserId;
    final rows = await _readJsonList(_localPlaylistsKey);
    final songPayloads = await _localSongPayloadsById();

    return rows.where((playlist) => playlist['user_id'] == userId).map((
      playlist,
    ) {
      final songIds = (playlist['song_ids'] as List<dynamic>? ?? [])
          .map((id) => int.tryParse(id.toString()) ?? 0)
          .where((id) => id > 0)
          .toList();

      return Playlist.fromJson({
        'id': playlist['id'],
        'user_id': playlist['user_id'],
        'name': playlist['name'],
        'songs': songIds
            .where((songId) => songPayloads.containsKey(songId))
            .map((songId) => songPayloads[songId]!)
            .toList(),
      });
    }).toList();
  }

  Future<Playlist> _localCreatePlaylist(String name) async {
    await _ensureLocalSeed();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ApiException('Nama playlist tidak boleh kosong.');
    }

    final rows = await _readJsonList(_localPlaylistsKey);
    final playlist = <String, dynamic>{
      'id': _nextId(rows),
      'user_id': _currentLocalUserId,
      'name': trimmed,
      'song_ids': <int>[],
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    rows.add(playlist);
    await _writeJsonList(_localPlaylistsKey, rows);
    return (await _localFetchPlaylists()).firstWhere(
      (item) => item.id == playlist['id'],
    );
  }

  Future<Playlist> _localRenamePlaylist({
    required int playlistId,
    required String name,
  }) async {
    await _ensureLocalSeed();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ApiException('Nama playlist tidak boleh kosong.');
    }

    final rows = await _readJsonList(_localPlaylistsKey);
    final userId = _currentLocalUserId;
    final index = rows.indexWhere(
      (item) => item['id'] == playlistId && item['user_id'] == userId,
    );

    if (index == -1) {
      throw ApiException('Playlist lokal tidak ditemukan.');
    }

    rows[index]['name'] = trimmed;
    rows[index]['updated_at'] = DateTime.now().toIso8601String();
    await _writeJsonList(_localPlaylistsKey, rows);
    return (await _localFetchPlaylists()).firstWhere(
      (item) => item.id == playlistId,
    );
  }

  Future<Playlist> _localTogglePlaylistSong({
    required int playlistId,
    required int songId,
  }) async {
    await _ensureLocalSeed();
    final rows = await _readJsonList(_localPlaylistsKey);
    final userId = _currentLocalUserId;
    final index = rows.indexWhere(
      (item) => item['id'] == playlistId && item['user_id'] == userId,
    );

    if (index == -1) {
      throw ApiException('Playlist lokal tidak ditemukan.');
    }

    final songIds = (rows[index]['song_ids'] as List<dynamic>? ?? [])
        .map((id) => int.tryParse(id.toString()) ?? 0)
        .where((id) => id > 0)
        .toList();

    if (songIds.contains(songId)) {
      songIds.remove(songId);
    } else {
      songIds.add(songId);
    }

    rows[index]['song_ids'] = songIds;
    rows[index]['updated_at'] = DateTime.now().toIso8601String();
    await _writeJsonList(_localPlaylistsKey, rows);
    return (await _localFetchPlaylists()).firstWhere(
      (item) => item.id == playlistId,
    );
  }

  Future<Playlist> _localRemovePlaylistSong({
    required int playlistId,
    required int songId,
  }) async {
    await _ensureLocalSeed();
    final rows = await _readJsonList(_localPlaylistsKey);
    final userId = _currentLocalUserId;
    final index = rows.indexWhere(
      (item) => item['id'] == playlistId && item['user_id'] == userId,
    );

    if (index == -1) {
      throw ApiException('Playlist lokal tidak ditemukan.');
    }

    final songIds = (rows[index]['song_ids'] as List<dynamic>? ?? [])
        .map((id) => int.tryParse(id.toString()) ?? 0)
        .where((id) => id > 0 && id != songId)
        .toList();

    rows[index]['song_ids'] = songIds;
    rows[index]['updated_at'] = DateTime.now().toIso8601String();
    await _writeJsonList(_localPlaylistsKey, rows);
    return (await _localFetchPlaylists()).firstWhere(
      (item) => item.id == playlistId,
    );
  }

  Future<void> _localDeletePlaylist(int playlistId) async {
    await _ensureLocalSeed();
    final userId = _currentLocalUserId;
    final rows = await _readJsonList(_localPlaylistsKey);
    rows.removeWhere(
      (item) => item['id'] == playlistId && item['user_id'] == userId,
    );
    await _writeJsonList(_localPlaylistsKey, rows);
  }

  Future<List<HistoryEntry>> _localFetchHistory() async {
    await _ensureLocalSeed();
    final userId = _currentLocalUserId;
    final rows = await _readJsonList(_localHistoryKey);
    final songPayloads = await _localSongPayloadsById();
    final userRows = rows.where((item) => item['user_id'] == userId).toList()
      ..sort(
        (a, b) =>
            b['played_at'].toString().compareTo(a['played_at'].toString()),
      );

    return userRows.map((entry) {
      final songId = int.tryParse(entry['song_id'].toString()) ?? 0;
      return HistoryEntry.fromJson({
        'id': entry['id'],
        'user_id': entry['user_id'],
        'song_id': songId,
        'played_at': entry['played_at'],
        'song': songPayloads[songId],
      });
    }).toList();
  }

  Future<void> _localRecordPlay(int songId) async {
    await _ensureLocalSeed();
    final userId = _currentLocalUserId;
    final now = DateTime.now().toIso8601String();
    final rows = await _readJsonList(_localHistoryKey);
    final index = rows.indexWhere(
      (item) => item['user_id'] == userId && item['song_id'] == songId,
    );

    if (index == -1) {
      rows.add({
        'id': _nextId(rows),
        'user_id': userId,
        'song_id': songId,
        'played_at': now,
      });
    } else {
      rows[index]['played_at'] = now;
    }

    await _writeJsonList(_localHistoryKey, rows);

    final plays = await _readIntMap(_localPlaysKey);
    plays[songId] = (plays[songId] ?? 0) + 1;
    await _writeIntMap(_localPlaysKey, plays);
  }

  Future<LikeResult> _localToggleLike(int songId) async {
    await _ensureLocalSeed();
    final likedIds = await _localLikedSongIds();
    final wasLiked = likedIds.contains(songId);

    if (wasLiked) {
      likedIds.remove(songId);
    } else {
      likedIds.add(songId);
    }

    await _writeLocalLikedSongIds(likedIds);
    final counts = await _localLikeCounts();

    return LikeResult(
      status: wasLiked ? 'unliked' : 'liked',
      likes: counts[songId] ?? 0,
    );
  }

  Future<List<SongComment>> _localFetchComments(int songId) async {
    await _ensureLocalSeed();
    final rows = await _readJsonList(_localCommentsKey);
    final parents =
        rows
            .where(
              (item) => item['song_id'] == songId && item['parent_id'] == null,
            )
            .toList()
          ..sort(
            (a, b) => b['created_at'].toString().compareTo(
              a['created_at'].toString(),
            ),
          );

    return parents.map((comment) {
      final replies =
          rows.where((item) => item['parent_id'] == comment['id']).toList()
            ..sort(
              (a, b) => a['created_at'].toString().compareTo(
                b['created_at'].toString(),
              ),
            );

      return SongComment.fromJson({...comment, 'replies': replies});
    }).toList();
  }

  Future<SongComment> _localStoreComment({
    required int songId,
    required String content,
    int? parentId,
  }) async {
    await _ensureLocalSeed();
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ApiException('Komentar tidak boleh kosong.');
    }

    final user = await _localFetchMe();
    final rows = await _readJsonList(_localCommentsKey);
    final now = DateTime.now().toIso8601String();
    final comment = <String, dynamic>{
      'id': _nextId(rows),
      'user_id': user.id,
      'song_id': songId,
      'parent_id': parentId,
      'user_name': user.name,
      'content': trimmed,
      'created_at': now,
      'updated_at': now,
      'replies': <Map<String, dynamic>>[],
    };

    rows.add(comment);
    await _writeJsonList(_localCommentsKey, rows);
    return SongComment.fromJson(comment);
  }

  Future<SongComment> _localUpdateComment({
    required int commentId,
    required String content,
  }) async {
    await _ensureLocalSeed();
    final user = await _localFetchMe();
    final rows = await _readJsonList(_localCommentsKey);
    final index = rows.indexWhere((item) => item['id'] == commentId);

    if (index == -1) {
      throw ApiException('Komentar lokal tidak ditemukan.');
    }
    if (rows[index]['user_id'] != user.id && user.role != 'admin') {
      throw ApiException('Tidak diizinkan mengubah komentar ini.');
    }

    rows[index]['content'] = content.trim();
    rows[index]['updated_at'] = DateTime.now().toIso8601String();
    await _writeJsonList(_localCommentsKey, rows);
    return SongComment.fromJson({...rows[index], 'replies': []});
  }

  Future<void> _localDeleteComment(int commentId) async {
    await _ensureLocalSeed();
    final user = await _localFetchMe();
    final rows = await _readJsonList(_localCommentsKey);
    final comment = rows.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == commentId,
      orElse: () => null,
    );

    if (comment == null) {
      return;
    }
    if (comment['user_id'] != user.id && user.role != 'admin') {
      throw ApiException('Tidak diizinkan menghapus komentar ini.');
    }

    rows.removeWhere(
      (item) => item['id'] == commentId || item['parent_id'] == commentId,
    );
    await _writeJsonList(_localCommentsKey, rows);
  }

  Future<Map<String, dynamic>> _localFetchAdminStats() async {
    await _ensureLocalSeed();
    final songs = await _localSongPayloads();
    final users = await _readJsonList(_localUsersKey);
    
    int totalPlays = 0;
    int totalLikes = 0;
    for (final song in songs) {
      totalPlays += (song['plays'] as int? ?? 0);
      totalLikes += (song['likes'] as int? ?? 0);
    }

    return {
      'total_listeners': totalPlays,
      'total_likes': totalLikes,
      'total_songs': songs.length,
      'total_users': users.length,
    };
  }

  Future<Song> _localCreateSong({
    required String title,
    required String artist,
    required String description,
    String? coverPath,
    String? filePath,
  }) async {
    await _ensureLocalSeed();
    final songs = await _readJsonList(_localSongsKey);
    final id = _nextId(songs);
    
    final newSong = {
      'id': id,
      'title': title,
      'artist': artist,
      'description': description,
      'cover_path': coverPath ?? 'assets/img/c1.jpg',
      'file_path': filePath ?? 'assets/songs/Prisoner.wav',
      'plays': 0,
      'likes': 0,
    };

    songs.add(newSong);
    await _writeJsonList(_localSongsKey, songs);
    return Song.fromJson(newSong);
  }

  Future<Song> _localUpdateSong({
    required int id,
    String? title,
    String? artist,
    String? description,
    String? coverPath,
    String? filePath,
  }) async {
    await _ensureLocalSeed();
    final songs = await _readJsonList(_localSongsKey);
    final index = songs.indexWhere((s) => s['id'] == id);
    if (index == -1) throw ApiException('Lagu tidak ditemukan.');

    if (title != null) songs[index]['title'] = title;
    if (artist != null) songs[index]['artist'] = artist;
    if (description != null) songs[index]['description'] = description;
    if (coverPath != null) songs[index]['cover_path'] = coverPath;
    if (filePath != null) songs[index]['file_path'] = filePath;

    await _writeJsonList(_localSongsKey, songs);
    return Song.fromJson(songs[index]);
  }

  Future<void> _localDeleteSong(int id) async {
    await _ensureLocalSeed();
    final songs = await _readJsonList(_localSongsKey);
    songs.removeWhere((s) => s['id'] == id);
    await _writeJsonList(_localSongsKey, songs);
  }

  Future<List<Map<String, dynamic>>> _localSongPayloads() async {
    await _ensureLocalSeed();
    final likedIds = await _localLikedSongIds();
    final likeCounts = await _localLikeCounts();
    final plays = await _readIntMap(_localPlaysKey);
    final songs = await _readJsonList(_localSongsKey);

    return songs.map((song) {
      final id = song['id'] as int;
      return {
        ...song,
        'plays': (song['plays'] as int? ?? 0) + (plays[id] ?? 0),
        'likes': likeCounts[id] ?? (song['likes'] as int? ?? 0),
        'is_liked': likedIds.contains(id),
      };
    }).toList();
  }

  Future<Map<int, Map<String, dynamic>>> _localSongPayloadsById() async {
    final payloads = await _localSongPayloads();
    return {for (final payload in payloads) payload['id'] as int: payload};
  }

  Future<Set<int>> _localLikedSongIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getStringList('$_localLikesPrefix$_currentLocalUserId') ??
        const <String>[];
    return raw
        .map((item) => int.tryParse(item) ?? 0)
        .where((id) => id > 0)
        .toSet();
  }

  Future<void> _writeLocalLikedSongIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      '$_localLikesPrefix$_currentLocalUserId',
      ids.map((id) => id.toString()).toList(),
    );
  }

  Future<Map<int, int>> _localLikeCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final users = await _readJsonList(_localUsersKey);
    final counts = <int, int>{
      for (final song in _localSongs) song['id'] as int: song['likes'] as int,
    };

    for (final user in users) {
      final userId = user['id'];
      final raw =
          prefs.getStringList('$_localLikesPrefix$userId') ?? const <String>[];
      for (final item in raw) {
        final songId = int.tryParse(item);
        if (songId != null) {
          counts[songId] = (counts[songId] ?? 0) + 1;
        }
      }
    }

    return counts;
  }

  Future<void> _ensureLocalSeed() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_localUsersKey)) {
      await _writeJsonList(_localUsersKey, [
        {
          'id': 1,
          'name': 'Administrator',
          'email': 'admin@ukmband.telkom',
          'password': 'admin123',
          'role': 'admin',
        },
        {
          'id': 2,
          'name': 'User Demo',
          'email': 'user@example.com',
          'password': 'password',
          'role': 'user',
        },
      ]);
    }
    if (!prefs.containsKey(_localSongsKey)) {
      await _writeJsonList(_localSongsKey, _localSongs);
    }
    if (!prefs.containsKey(_localPlaylistsKey)) {
      await _writeJsonList(_localPlaylistsKey, []);
    }
    if (!prefs.containsKey(_localHistoryKey)) {
      await _writeJsonList(_localHistoryKey, []);
    }
    if (!prefs.containsKey(_localCommentsKey)) {
      await _writeJsonList(_localCommentsKey, []);
    }
  }

  Future<List<Map<String, dynamic>>> _readJsonList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _writeJsonList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<Map<int, int>> _readIntMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) =>
          MapEntry(int.parse(key), int.tryParse(value.toString()) ?? 0),
    );
  }

  Future<void> _writeIntMap(String key, Map<int, int> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(value.map((key, value) => MapEntry(key.toString(), value))),
    );
  }

  int _nextId(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return 1;
    }
    return items
            .map((item) => int.tryParse(item['id'].toString()) ?? 0)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    if (requiresAuth && (_token?.isEmpty ?? true)) {
      throw ApiException('Sesi tidak tersedia. Silakan login kembali.');
    }

    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Accept': 'application/json'};

    if (_token?.isNotEmpty ?? false) {
      headers['Authorization'] = 'Bearer $_token';
    }

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          throw ApiException('Metode request tidak didukung: $method');
      }
    } catch (_) {
      throw ApiException(
        'Tidak dapat terhubung ke server. Pastikan backend berjalan dan URL API benar.',
      );
    }

    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    }

    var message = 'Terjadi kesalahan pada server.';

    if (decoded is Map<String, dynamic>) {
      if (decoded['message'] is String &&
          decoded['message'].toString().isNotEmpty) {
        message = decoded['message'].toString();
      }

      final errors = decoded['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          message = firstError.first.toString();
        }
      }
    }

    throw ApiException(message, statusCode: response.statusCode);
  }

  AuthResult _parseAuthResult(Map<String, dynamic> data) {
    final token = data['token']?.toString() ?? '';
    final userData = data['data'] as Map<String, dynamic>?;

    if (token.isEmpty || userData == null) {
      throw ApiException('Respons login dari server tidak valid.');
    }

    return AuthResult(token: token, user: AppUser.fromJson(userData));
  }
}

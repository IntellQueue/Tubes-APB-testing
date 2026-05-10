import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  static const String _tokenKey = 'auth_token';

  final ApiService _apiService;

  AppUser? _user;
  String? _token;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  AuthProvider(this._apiService);

  AppUser? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _user != null && _token != null && _token!.isNotEmpty;

  bool get isAdmin => _user?.role == 'admin';

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(_tokenKey);

      if (storedToken == null || storedToken.isEmpty) {
        _token = null;
        _user = null;
      } else {
        _token = storedToken;
        _apiService.setAuthToken(storedToken);
        _user = await _apiService.fetchMe();
      }
    } catch (_) {
      await _clearSession();
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.login(email: email, password: password);
      await _setSession(result.token, result.user);
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      await _setSession(result.token, result.user);
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.logout();
    } catch (_) {
      // Ignore remote logout error and still clear local session.
    } finally {
      await _clearSession();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    String? avatarPath,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _apiService.updateProfile(
        name: name,
        email: email,
        avatarPath: avatarPath,
      );
      _user = updatedUser;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _setSession(String token, AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    _token = token;
    _user = user;
    _apiService.setAuthToken(token);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);

    _token = null;
    _user = null;
    _errorMessage = null;
    _apiService.setAuthToken(null);
  }
}

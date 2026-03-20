import 'package:flutter/foundation.dart';

import '../models/user_credentials.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import '../services/token_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthService authService,
      required RealtimeService realtimeService,
    required TokenStorageService tokenStorage,
  })  : _authService = authService,
      _realtimeService = realtimeService,
        _tokenStorage = tokenStorage;

  final AuthService _authService;
    final RealtimeService _realtimeService;
  final TokenStorageService _tokenStorage;

  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _username;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  String? get error => _error;

  Future<void> bootstrap() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _tokenStorage.getAccessToken();
      _username = await _tokenStorage.getUsername();
      _isAuthenticated = token != null && token.isNotEmpty;
      if (_isAuthenticated) {
        await _realtimeService.connect();
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tokenPair = await _authService.login(
        UserCredentials(username: username, password: password),
      );

      await _tokenStorage.saveTokens(tokenPair);
      await _tokenStorage.saveUsername(username);
      await _realtimeService.connect();
      _username = username;
      _isAuthenticated = true;
      return true;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.register(
        UserCredentials(username: username, password: password),
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    _realtimeService.disconnect();
    await _tokenStorage.clear();
    _isAuthenticated = false;
    _username = null;
    _isLoading = false;
    notifyListeners();
  }
}

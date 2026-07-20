import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.zidash.com/api/v1',
  );

  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshInFlight;
  String? _userRole;
  String? _userId;

  /// Whether the signed-in user has admin privileges.
  /// Value is cached each time [bootstrap] is called.
  bool get isAdmin => _isAdminRole(_userRole);

  /// Expose the raw access token so admin-specific code can inspect it.
  String? get accessToken => _accessToken;
  String? get currentUserId => _userId;

  /// Override the cached role (used in tests / edge cases).
  void setUserRole(String? role) => _userRole = role;

  bool _isAdminRole(String? role) => role?.trim().toLowerCase() == 'admin';

  static const Map<String, String> _adminHeaders = {'X-Admin-Request': 'true'};
  static const String _signupCompleteKey = 'signupComplete';
  static const String _anonymousSessionKey = 'anonymousSession';

  Future<SharedPreferences?> _preferences() async {
    try {
      return await SharedPreferences.getInstance();
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> loadSession() async {
    final prefs = await _preferences();
    if (prefs == null) return;
    _accessToken = prefs.getString('accessToken');
    _refreshToken = prefs.getString('refreshToken');
  }

  Future<void> saveSession(Map<String, dynamic> tokens) async {
    _accessToken = tokens['accessToken'] as String?;
    _refreshToken = tokens['refreshToken'] as String?;
    final prefs = await _preferences();
    if (prefs == null) return;
    await prefs.remove(_anonymousSessionKey);
    if (_accessToken != null) {
      await prefs.setString('accessToken', _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString('refreshToken', _refreshToken!);
    }
  }

  Future<bool> hasCompletedSignup() async {
    await loadSession();
    final prefs = await _preferences();
    if (prefs?.getBool(_anonymousSessionKey) ?? false) return true;
    return (_accessToken != null || _refreshToken != null) &&
        (prefs?.getBool(_signupCompleteKey) ?? false);
  }

  Future<bool> isAnonymousSession() async {
    final prefs = await _preferences();
    return prefs?.getBool(_anonymousSessionKey) ?? false;
  }

  Future<void> startAnonymousSession() async {
    _accessToken = null;
    _refreshToken = null;
    _refreshInFlight = null;
    _userRole = null;
    _userId = null;
    final prefs = await _preferences();
    if (prefs == null) return;
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.setBool(_signupCompleteKey, true);
    await prefs.setBool(_anonymousSessionKey, true);
  }

  Future<void> markSignupComplete() async {
    await post('/app/signup-complete', {});
    final prefs = await _preferences();
    await prefs?.remove(_anonymousSessionKey);
    await prefs?.setBool(_signupCompleteKey, true);
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _refreshInFlight = null;
    _userId = null;
    final prefs = await _preferences();
    if (prefs == null) return;
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove(_signupCompleteKey);
    await prefs.remove(_anonymousSessionKey);
  }

  bool get isAuthenticated => _accessToken != null;

  Future<void> logout() async {
    await loadSession();
    final refreshToken = _refreshToken;
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await post('/auth/logout', {
          'refreshToken': refreshToken,
        }, authenticated: false);
      }
    } finally {
      await clearSession();
    }
  }

  Future<Map<String, dynamic>> requestOtp(
    String email, {
    String mode = 'auto',
    String? firstName,
    String? lastName,
  }) {
    return post('/auth/request-otp', {
      'email': email,
      'mode': mode,
      if (firstName != null && firstName.trim().isNotEmpty)
        'firstName': firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty)
        'lastName': lastName.trim(),
    }, authenticated: false);
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    final response = await post('/auth/verify-otp', {
      'email': email,
      'code': code,
    }, authenticated: false);
    final tokens = response['tokens'];
    if (tokens is! Map<String, dynamic>) {
      throw ApiException(
        'Verification succeeded, but no auth token was returned',
      );
    }
    await saveSession(tokens);
    return response;
  }

  Future<Map<String, dynamic>> authenticateWithGoogle({
    String? idToken,
    String? providerId,
    String? email,
    String? name,
    String? photo,
  }) {
    return _socialAuth('/auth/google', {
      if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
      if (providerId != null && providerId.isNotEmpty) 'providerId': providerId,
      if (email != null && email.isNotEmpty) 'email': email,
      if (name != null && name.isNotEmpty) 'name': name,
      if (photo != null && photo.isNotEmpty) 'photo': photo,
    });
  }

  Future<Map<String, dynamic>> authenticateWithApple({
    String? identityToken,
    String? authorizationCode,
    String? userIdentifier,
    String? email,
    String? givenName,
    String? familyName,
  }) {
    return _socialAuth('/auth/apple', {
      if (identityToken != null && identityToken.isNotEmpty)
        'identityToken': identityToken,
      if (authorizationCode != null && authorizationCode.isNotEmpty)
        'authorizationCode': authorizationCode,
      if (userIdentifier != null && userIdentifier.isNotEmpty)
        'userIdentifier': userIdentifier,
      if (email != null && email.isNotEmpty) 'email': email,
      if (givenName != null && givenName.isNotEmpty) 'givenName': givenName,
      if (familyName != null && familyName.isNotEmpty) 'familyName': familyName,
    });
  }

  Future<Map<String, dynamic>> _socialAuth(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await post(path, payload, authenticated: false);
    final tokens = response['tokens'];
    if (tokens is! Map<String, dynamic>) {
      throw ApiException(
        'Authentication succeeded, but no auth token was returned',
      );
    }
    await saveSession(tokens);
    final prefs = await _preferences();
    await prefs?.setBool(_signupCompleteKey, true);
    final user = (response['user'] as Map?)?.cast<String, dynamic>();
    _userRole = user?['role']?.toString();
    _userId = user?['id']?.toString();
    return response;
  }

  Future<Map<String, dynamic>> bootstrap() async {
    final data = await get('/app/bootstrap');
    // Cache the user role for admin gating.
    final user = (data['user'] as Map?)?.cast<String, dynamic>();
    _userRole = user?['role']?.toString();
    _userId = user?['id']?.toString();
    return data;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) {
    return patch('/app/profile', payload);
  }

  Future<Map<String, dynamic>> updateLocation(String location) {
    return updateProfile({
      'sellerProfile': {'location': location},
    });
  }

  Future<Map<String, dynamic>> deleteAccount() {
    return delete('/app/account');
  }

  Future<Map<String, dynamic>> createListing(Map<String, dynamic> payload) {
    return post('/app/listings', payload);
  }

  Future<List<dynamic>> preferredProducts() async {
    try {
      final response = await get('/app/preferred-products');
      return response['items'] as List<dynamic>;
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      final bootstrapData = await bootstrap();
      final user = (bootstrapData['user'] as Map?)?.cast<String, dynamic>();
      final userId = user?['id']?.toString();
      if (userId == null || userId.isEmpty) return [];
      final response = await get(
        '/saved-listings?userId=${Uri.encodeQueryComponent(userId)}',
      );
      return (response['items'] as List<dynamic>)
          .map((item) {
            if (item is! Map) return null;
            final listing = item['listing'];
            return listing is Map ? listing.cast<String, dynamic>() : null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    }
  }

  Future<Map<String, dynamic>> togglePreferredProduct(String id) {
    return post('/listings/$id/save', {});
  }

  Future<List<dynamic>> myListings({String status = 'listed'}) async {
    final response = await get('/app/my-listings?status=$status');
    return response['items'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateMyListing(
    String id,
    Map<String, dynamic> payload,
  ) {
    return patch('/app/my-listings/$id', payload);
  }

  Future<Map<String, dynamic>> closeMyListing(String id) {
    return post('/app/my-listings/$id/close', {});
  }

  Future<Map<String, dynamic>> reopenMyListing(String id) {
    return post('/app/my-listings/$id/reopen', {});
  }

  Future<Map<String, dynamic>> boostMyListing(String id, {int days = 7}) {
    return post('/app/my-listings/$id/boost', {'days': days});
  }

  Future<Map<String, dynamic>> payListingPromotion(
    String id, {
    required int days,
    required String method,
  }) {
    return post('/app/my-listings/$id/promotion-payment', {
      'days': days,
      'method': method,
    });
  }

  Future<List<dynamic>> conversations() async {
    final response = await get('/app/conversations');
    return response['items'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> startConversation({
    String? sellerId,
    String? listingId,
    String? message,
  }) {
    return post('/app/conversations/start', {
      'sellerId': ?sellerId,
      'listingId': ?listingId,
      'message': ?message,
    });
  }

  Future<Map<String, dynamic>> conversationMessages(String conversationId) {
    return get('/app/conversations/$conversationId/messages');
  }

  Future<Map<String, dynamic>> sendMessage(
    String conversationId, {
    required String body,
    String type = 'text',
    String? mediaUrl,
  }) {
    return post('/app/conversations/$conversationId/messages', {
      'type': type,
      'body': body,
      'mediaUrl': ?mediaUrl,
    });
  }

  Future<Map<String, dynamic>> deleteMyListing(String id) {
    return delete('/app/my-listings/$id');
  }

  Future<List<dynamic>> communityPosts({String? location}) async {
    final query = location == null || location == 'All'
        ? ''
        : '?location=${Uri.encodeQueryComponent(location)}';
    final response = await get(
      '/app/community/posts$query',
      authenticated: false,
    );
    return response['items'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCommunitySalePost(
    Map<String, dynamic> payload,
  ) {
    return post('/app/community/posts', payload);
  }

  Future<List<dynamic>> myCommunityPosts() async {
    final response = await get('/app/my-community-posts');
    return response['items'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateMyCommunityPost(
    String id,
    Map<String, dynamic> payload,
  ) {
    return patch('/app/my-community-posts/$id', payload);
  }

  Future<Map<String, dynamic>> deleteMyCommunityPost(String id) {
    return delete('/app/my-community-posts/$id');
  }

  Future<Map<String, dynamic>> toggleCommunityPostLike(String id) {
    return post('/app/community/posts/$id/like', {});
  }

  Future<List<String>> uploadImages(List<UploadFilePayload> files) async {
    if (_accessToken == null) await loadSession();
    var response = await _sendUpload(files);
    if (_shouldRefresh(response.statusCode) && await _refreshAccessToken()) {
      response = await _sendUpload(files);
    }
    final decoded = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'] as Map<String, dynamic>?;
      if (_shouldRefresh(response.statusCode)) await clearSession();
      throw ApiException(
        error?['message'] as String? ?? 'Upload failed',
        statusCode: response.statusCode,
      );
    }
    final data = decoded['data'];
    if (data is! List) throw ApiException('Upload did not return files');
    return data
        .map((item) => (item as Map<String, dynamic>)['url']?.toString())
        .whereType<String>()
        .toList();
  }

  Future<http.Response> _sendUpload(List<UploadFilePayload> files) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/uploads'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    });
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          file.bytes,
          filename: file.filename,
          contentType: MediaType('image', 'webp'),
        ),
      );
    }
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  Future<Map<String, dynamic>> postJob(Map<String, dynamic> payload) {
    return post('/app/jobs', payload);
  }

  Future<List<dynamic>> myJobs({String? status}) async {
    final query = status == null
        ? ''
        : '?status=${Uri.encodeQueryComponent(status)}';
    final response = await get('/app/my-jobs$query');
    return response['items'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateMyJob(
    String id,
    Map<String, dynamic> payload,
  ) {
    return patch('/app/my-jobs/$id', payload);
  }

  Future<Map<String, dynamic>> closeMyJob(String id) {
    return post('/app/my-jobs/$id/close', {});
  }

  Future<Map<String, dynamic>> reopenMyJob(String id) {
    return post('/app/my-jobs/$id/reopen', {});
  }

  Future<Map<String, dynamic>> deleteMyJob(String id) {
    return delete('/app/my-jobs/$id');
  }

  Future<Map<String, dynamic>> applyForJob(
    String jobId,
    Map<String, dynamic> payload,
  ) {
    return post('/app/jobs/$jobId/apply', payload);
  }

  Future<Map<String, dynamic>> becomeCreator(Map<String, dynamic> payload) {
    return post('/app/creators', payload);
  }

  Future<List<dynamic>> creators() async {
    final response = await get('/creators', authenticated: false);
    return response['items'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> submitIdentityVerification(
    Map<String, dynamic> payload,
  ) {
    return post('/app/identity-verifications', payload);
  }

  Future<Map<String, dynamic>> requestPhoneVerification(
    String phone, {
    required String identityMethod,
    String? identityNumber,
  }) {
    return post('/app/phone-verifications/request', {
      'phone': phone,
      'identityMethod': identityMethod,
      'identityNumber': ?identityNumber,
    });
  }

  Future<Map<String, dynamic>> verifyPhoneVerification(String code) {
    return post('/app/phone-verifications/verify', {'code': code});
  }

  Future<List<dynamic>> listings({
    String? categoryId,
    String? category,
    String? query,
    String? condition,
    num? minPrice,
    num? maxPrice,
    String? sort,
  }) async {
    final params = <String>[];
    void addParam(String key, Object? value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) return;
      params.add('$key=${Uri.encodeQueryComponent(text)}');
    }

    addParam('categoryId', categoryId);
    addParam('category', category);
    addParam('q', query);
    addParam('condition', condition);
    addParam('minPrice', minPrice);
    addParam('maxPrice', maxPrice);
    addParam('sort', sort);

    final queryString = params.isEmpty ? '' : '?${params.join('&')}';
    final response = await get('/listings$queryString', authenticated: false);
    return response['items'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> listing(String id) {
    return get('/listings/$id', authenticated: false);
  }

  Future<Map<String, dynamic>> sellerProfile(String id) {
    return get('/seller-profiles/$id', authenticated: false);
  }

  Future<Map<String, dynamic>> sellerFollowStatus(String sellerId) {
    return get(
      '/app/seller-profiles/${Uri.encodeQueryComponent(sellerId)}/follow-status',
    );
  }

  Future<Map<String, dynamic>> toggleSellerFollow(String sellerId) {
    return post(
      '/app/seller-profiles/${Uri.encodeQueryComponent(sellerId)}/follow-toggle',
      {},
    );
  }

  Future<List<dynamic>> sellerListings(String sellerId) async {
    final response = await get(
      '/listings?sellerId=${Uri.encodeQueryComponent(sellerId)}',
      authenticated: false,
    );
    return response['items'] as List<dynamic>;
  }

  Future<List<dynamic>> jobs() async {
    final response = await get('/jobs', authenticated: false);
    return response['items'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) {
    return _send('GET', path, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) {
    return _send('POST', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) {
    return _send('PATCH', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool authenticated = true,
  }) {
    return _send('DELETE', path, authenticated: authenticated);
  }

  // ── Admin HTTP helpers ───────────────────────────────────────────────────
  // All admin calls are authenticated and carry X-Admin-Request: true.
  // The server must independently verify the JWT role; the header is an
  // additional signal, not the sole security control.

  Future<Map<String, dynamic>> _adminGet(String path) =>
      _send('GET', path, extraHeaders: _adminHeaders);

  Future<Map<String, dynamic>> _adminPost(
    String path,
    Map<String, dynamic> body,
  ) => _send('POST', path, body: body, extraHeaders: _adminHeaders);

  Future<Map<String, dynamic>> _adminPatch(
    String path,
    Map<String, dynamic> body,
  ) => _send('PATCH', path, body: body, extraHeaders: _adminHeaders);

  Future<Map<String, dynamic>> _adminDelete(String path) =>
      _send('DELETE', path, extraHeaders: _adminHeaders);

  // ── Admin API methods ────────────────────────────────────────────────────

  /// Summary KPIs + 7-day revenue series.
  Future<Map<String, dynamic>> adminAnalytics() =>
      _adminGet('/admin/analytics');

  /// Paginated user list. Optionally filter by [query] (name / email).
  Future<Map<String, dynamic>> adminUsers({int page = 1, String? query}) {
    final params = ['page=$page', 'limit=20'];
    if (query != null && query.trim().isNotEmpty) {
      params.add('q=${Uri.encodeQueryComponent(query.trim())}');
    }
    return _adminGet('/admin/users?${params.join("&")}');
  }

  /// Block or unblock a user. [blocked] = true to block.
  Future<Map<String, dynamic>> adminSetUserBlocked(
    String userId, {
    required bool blocked,
  }) => _adminPatch('/admin/users/$userId', {'blocked': blocked});

  /// Paginated listing list. [status] can be null (all), 'active', 'paused', 'rejected'.
  Future<Map<String, dynamic>> adminListings({
    int page = 1,
    String? status,
    String? query,
  }) {
    final params = ['page=$page', 'limit=20'];
    if (status != null) params.add('status=$status');
    if (query != null && query.trim().isNotEmpty) {
      params.add('q=${Uri.encodeQueryComponent(query.trim())}');
    }
    return _adminGet('/admin/listings?${params.join("&")}');
  }

  /// Pause or unpause a listing.
  Future<Map<String, dynamic>> adminSetListingPaused(
    String listingId, {
    required bool paused,
  }) => _adminPatch('/admin/listings/$listingId', {
    'status': paused ? 'paused' : 'active',
  });

  /// Permanently delete a listing.
  Future<Map<String, dynamic>> adminDeleteListing(String listingId) =>
      _adminDelete('/admin/listings/$listingId');

  /// Paginated payment / transaction log.
  Future<Map<String, dynamic>> adminPayments({int page = 1}) =>
      _adminGet('/admin/payments?page=$page&limit=20');

  /// Paginated identity verification queue.
  Future<Map<String, dynamic>> adminVerifications({
    int page = 1,
    String status = 'pending',
  }) => _adminGet('/admin/verifications?page=$page&status=$status&limit=20');

  /// Approve or reject an identity verification.
  Future<Map<String, dynamic>> adminReviewVerification(
    String verificationId, {
    required bool approved,
    String? reason,
  }) => _adminPost('/admin/verifications/$verificationId/review', {
    'approved': approved,
    if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
  });

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    bool canRetry = true,
    Map<String, String>? extraHeaders,
  }) async {
    if (authenticated && _accessToken == null) await loadSession();
    final hadAuthToken = _accessToken != null || _refreshToken != null;
    var response = await _performRequest(
      method,
      path,
      body: body,
      authenticated: authenticated,
      extraHeaders: extraHeaders,
    );

    if (authenticated &&
        canRetry &&
        _shouldRefresh(response.statusCode) &&
        await _refreshAccessToken()) {
      response = await _performRequest(
        method,
        path,
        body: body,
        authenticated: authenticated,
        extraHeaders: extraHeaders,
      );
    }

    final decoded = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'] as Map<String, dynamic>?;
      if (authenticated &&
          hadAuthToken &&
          _shouldRefresh(response.statusCode)) {
        await clearSession();
      }
      throw ApiException(
        error?['message'] as String? ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }
    final data = decoded['data'];
    if (data is List) return {'items': data, 'meta': decoded['meta']};
    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }

  Future<http.Response> _performRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (authenticated && _accessToken != null)
        'Authorization': 'Bearer $_accessToken',
      if (extraHeaders != null) ...extraHeaders,
    };

    late http.Response response;
    if (method == 'GET') {
      response = await http.get(uri, headers: headers);
    } else if (method == 'PATCH') {
      response = await http.patch(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
    } else if (method == 'DELETE') {
      response = await http.delete(uri, headers: headers);
    } else {
      response = await http.post(uri, headers: headers, body: jsonEncode(body));
    }
    return response;
  }

  Future<bool> _refreshAccessToken() {
    final refresh = _refreshInFlight ??= _refreshSession();
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  Future<bool> _refreshSession() async {
    if (_refreshToken == null) await loadSession();
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      final decoded = _decodeResponse(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) return false;
      final tokens = data['tokens'];
      if (tokens is! Map<String, dynamic>) return false;
      await saveSession(tokens);
      return _accessToken != null;
    } catch (_) {
      return false;
    }
  }

  bool _shouldRefresh(int statusCode) => statusCode == 401;

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }
}

class UploadFilePayload {
  const UploadFilePayload({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

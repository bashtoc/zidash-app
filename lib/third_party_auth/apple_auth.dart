import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/api_service.dart';

Future<Map<String, dynamic>> signInOrSignUpWithApple() async {
  try {
    final isAvailable = await SignInWithApple.isAvailable();
    if (!isAvailable) {
      return {
        'success': false,
        'message': 'Sign in with Apple is not available on this device.',
      };
    }

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final data = await ApiService.instance.authenticateWithApple(
      identityToken: credential.identityToken,
      authorizationCode: credential.authorizationCode,
      userIdentifier: credential.userIdentifier,
      email: credential.email,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );

    return {'success': true, 'data': data};
  } catch (error) {
    if (error is SignInWithAppleAuthorizationException &&
        error.code == AuthorizationErrorCode.canceled) {
      return {
        'success': false,
        'cancelled': true,
        'title': 'Apple sign-in cancelled',
        'message':
            'No worries. Your Zidash account was not changed, and you can try Apple again whenever you are ready.',
      };
    }
    return {'success': false, 'message': 'Apple sign-in error: $error'};
  }
}

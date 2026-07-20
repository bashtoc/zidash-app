import 'package:google_sign_in/google_sign_in.dart';

import '../services/api_service.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

Future<Map<String, dynamic>> signInWithGoogle() async {
  try {
    const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    await _googleSignIn.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );

    final account = await _googleSignIn.authenticate();
    final auth = account.authentication;

    final data = await ApiService.instance.authenticateWithGoogle(
      idToken: auth.idToken,
      providerId: account.id,
      email: account.email,
      name: account.displayName,
      photo: account.photoUrl,
    );

    return {'success': true, 'data': data};
  } catch (error) {
    if (error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled) {
      return {
        'success': false,
        'cancelled': true,
        'title': 'Google sign-in cancelled',
        'message':
            'No worries. Your Zidash account was not changed, and you can try Google again whenever you are ready.',
      };
    }
    return {'success': false, 'message': 'Google sign-in error: $error'};
  }
}

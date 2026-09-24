import '../domain/entities/user_entity.dart';

/// Sealed class representing the discrete states of the authentication lifecycle.
sealed class AuthState {
  const AuthState();
}

/// Initial app startup state while restoring secure session from storage.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// User is not logged in.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.message});
  final String? message;
}

/// Active login / OTP verification in progress.
class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

/// User is authenticated, but has not completed basic profile & locality setup.
class AuthOnboardingRequired extends AuthState {
  const AuthOnboardingRequired(this.user);
  final UserEntity user;
}

/// User is fully authenticated and onboarding is complete. Access to 5-tab shell granted.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final UserEntity user;
}

/// Error encountered during authentication flow.
class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

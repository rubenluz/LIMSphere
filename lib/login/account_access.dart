// account_access.dart - Central account-status gate used by every auth entry point.

bool hasActiveAccount(Map<String, dynamic>? userRow) =>
    userRow?['user_status']?.toString().trim().toLowerCase() == 'active';

String accountAccessMessage(Map<String, dynamic>? userRow) {
  final status = userRow?['user_status']?.toString().trim().toLowerCase();
  if (status == 'pending') {
    return 'Your account is waiting for administrator validation.';
  }
  if (status == 'inactive') {
    return 'Your account is inactive. Please contact an administrator.';
  }
  return 'Your account is not active. Please contact an administrator.';
}

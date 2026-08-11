import '../core/app_constants.dart';

class MasterUserGuard {
  static bool isMaster(String login) => login == AppConstants.masterLogin;
}

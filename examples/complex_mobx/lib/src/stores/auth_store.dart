import 'package:mobx/mobx.dart';
import '../domain/entities.dart';

part 'auth_store.g.dart';

class AuthStore = _AuthStore with _$AuthStore;

abstract class _AuthStore with Store {
  @observable
  User? user;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @computed
  bool get isLoggedIn => user != null;

  @action
  Future<void> login(String username, String password) async {
    isLoading = true;
    errorMessage = null;
    
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (password == 'password') {
      user = User(username, 'token_123');
    } else {
      errorMessage = 'Invalid credentials';
    }
    isLoading = false;
  }

  @action
  void logout() {
    user = null;
    errorMessage = null;
  }
}

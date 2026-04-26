import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain_app/models/vault_model.dart';

void main() {
  test('global search finds password account names without exposing password', () {
    final vault = VaultData.empty().copyWith(
      passwords: const [
        VaultPassword(
          id: '1',
          accountName: 'HDFC Bank',
          username: 'rachit',
          password: 'secret-password',
        ),
      ],
    );

    final results = vault.search('hdfc');

    expect(results, hasLength(1));
    expect(results.single.title, 'HDFC Bank');
    expect(results.single.subtitle, 'rachit');
    expect(results.single.secret, 'secret-password');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/core/network/api_config.dart';

void main() {
  test('release-safe API fallback targets the deployed HTTPS backend', () {
    expect(ApiConfig.baseUrl, 'https://syncrofit-api.onrender.com');
    expect(Uri.parse(ApiConfig.baseUrl).scheme, 'https');
  });
}

import 'package:c_shield_sdk/c_shield_sdk.dart';
import 'package:dio/dio.dart';

const baseUrl = 'https://demo-spring-server.onrender.com';
const sslHostname = 'demo-spring-server.onrender.com';
const sslPins = ['sha256/kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4='];

Dio buildDio() {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  // createDioAdapter() checks the SPKI pin post-handshake via
  // HttpClientResponse.certificate — works for CA-signed certs too, unlike
  // IOHttpClientAdapter + badCertificateCallback which only fires for
  // invalid/untrusted certificates.
  dio.httpClientAdapter = CShieldSSL.createDioAdapter();
  dio.interceptors.add(const CShieldDioInterceptor());
  return dio;
}

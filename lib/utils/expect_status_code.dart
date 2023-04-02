import 'package:http/http.dart';

extension ExpectStatusCode on Response {
  void expectStatusCode(int code) {
    if (statusCode != code) {
      throw 'HTTP $statusCode: $body (expected $code)';
    }
  }
}

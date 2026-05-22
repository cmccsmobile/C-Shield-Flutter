import 'package:flutter/services.dart';
import '../../api/exceptions/c_shield_exception.dart';

class ErrorCodec {
  static CShieldException fromPlatformException(PlatformException e) {
    return CShieldException(
      CShieldErrorCode.fromPlatformCode(e.code),
      e.message ?? e.code,
      e,
    );
  }
}

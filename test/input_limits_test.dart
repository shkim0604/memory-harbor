import 'package:flutter_test/flutter_test.dart';
import 'package:memory_harbor/constants/input_limits.dart';

void main() {
  test('한 마디 최대 글자 수는 40자다', () {
    expect(InputLimits.introMessageMaxLength, 40);
  });
}

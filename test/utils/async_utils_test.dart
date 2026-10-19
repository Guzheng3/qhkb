import 'package:flutter_test/flutter_test.dart';
import 'package:qhkb/utils/async_utils.dart';

void main() {
  group('buildMirrorCandidateUrls', () {
    test('puts the selected mirror first and keeps the original last', () {
      final candidates = buildMirrorCandidateUrls(
        'github.com/Guzheng3/qhkb',
        selectedMirrorPrefix: 'https://mirror.example.com/',
      );

      expect(
        candidates.first,
        'https://mirror.example.com/github.com/Guzheng3/qhkb',
      );
      expect(candidates.last, 'github.com/Guzheng3/qhkb');
    });

    test('does not duplicate mirror candidates', () {
      final prefix = allBuiltinMirrorUrlPrefixes.first;
      final candidates = buildMirrorCandidateUrls(
        'github.com/Guzheng3/qhkb',
        selectedMirrorPrefix: prefix,
      );

      expect(candidates.where((url) => url.startsWith(prefix)).length, 1);
    });
  });
}

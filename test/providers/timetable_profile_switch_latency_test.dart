import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qhkb/models/timetable_profile.dart';
import 'package:qhkb/providers/timetable_provider.dart';
import 'package:qhkb/services/miui_live_activities_service.dart';
import 'package:qhkb/services/storage_service.dart';

class _BlockingProfileStorage extends StorageService {
  _BlockingProfileStorage() : super.forTesting();

  Completer<void>? _nextSaveGate;

  void blockNextSave() {
    _nextSaveGate = Completer<void>();
  }

  void releaseSave() {
    _nextSaveGate?.complete();
  }

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) async {
    final gate = _nextSaveGate;
    if (gate != null) {
      await gate.future;
      _nextSaveGate = null;
    }
    await super.saveProfiles(profiles);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('profile switch notifies UI before persistence completes', () async {
    final storage = _BlockingProfileStorage();
    final provider = TimetableProvider(
      storageService: storage,
      liveActivitiesService: TestMiuiLiveActivitiesService(),
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    final firstProfileId = provider.activeProfileId!;
    final second = await provider.createProfile(name: '第二课表');
    await provider.switchProfile(firstProfileId);

    var notifications = 0;
    provider.addListener(() => notifications++);
    storage.blockNextSave();

    final switchFuture = provider.switchProfile(second.id);
    await pumpEventQueue();

    expect(provider.activeProfileId, second.id);
    expect(notifications, 1);

    storage.releaseSave();
    await switchFuture;
  });
}

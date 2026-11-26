import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';
import 'progression.dart';
import 'save.dart';

/// Where the Story save lives.
abstract class SaveBackend {
  Future<String?> read();
  Future<void> write(String data);
}

/// Writes to a temp file, then renames it over the save, so a crash mid-write
/// never leaves a half-written save (6a.13).
class FileSaveBackend implements SaveBackend {
  FileSaveBackend(this.directory, {this.name = 'story_save.json'});

  final Directory directory;
  final String name;

  File get file => File('${directory.path}/$name');

  @override
  Future<String?> read() async => await file.exists() ? file.readAsString() : null;

  @override
  Future<void> write(String data) async {
    await directory.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(file.path);
  }
}

/// Web has no file system: keep the save in shared preferences.
class PrefsSaveBackend implements SaveBackend {
  PrefsSaveBackend(this.prefs);

  final SharedPreferences prefs;
  static const _key = 'fore_story_v1';

  @override
  Future<String?> read() async => prefs.getString(_key);

  @override
  Future<void> write(String data) => prefs.setString(_key, data);
}

class MemorySaveBackend implements SaveBackend {
  MemorySaveBackend([this.data]);

  String? data;
  int writes = 0;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String d) async {
    data = d;
    writes++;
  }
}

/// Holds Story content and the save, notifies the UI and persists changes.
class StoryStore extends ChangeNotifier {
  StoryStore(this.content, this.save, this._backend) {
    grantStartingCaddies(content, save.player);
    for (final id in save.unlockedCourses) {
      if (content.courseContent.containsKey(id)) courseSave(save, content, id);
    }
    // Rounds are saved the moment they end; apply any result an older build left pending.
    for (final id in save.courses.keys.toList()) {
      if (save.courses[id]!.pendingResult != null && content.courseContent.containsKey(id)) commitResult(save, content, id);
    }
  }

  final StoryContent content;
  StorySave save;
  final SaveBackend _backend;
  Future<void> _writing = Future.value();

  static Future<StoryStore> load() async {
    final content = await StoryContent.load((path) => rootBundle.loadString('${StoryContent.assetRoot}/$path'));
    final SaveBackend backend = kIsWeb ? PrefsSaveBackend(await SharedPreferences.getInstance()) : FileSaveBackend(await getApplicationSupportDirectory());
    return StoryStore(content, await readSave(backend), backend);
  }

  static Future<StorySave> readSave(SaveBackend backend) async {
    try {
      final raw = await backend.read();
      if (raw != null) return StorySave.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      // Corrupt save: start fresh rather than crash.
    }
    return StorySave();
  }

  Rules get rules => content.rules;

  CourseSave course(String id) => courseSave(save, content, id);

  /// Runs [change], saves and notifies. Returns what [change] returned.
  T update<T>(T Function(StorySave s) change) {
    final out = change(save);
    persist();
    notifyListeners();
    return out;
  }

  /// Writes the save. Writes are queued so they never overlap.
  Future<void> persist() {
    final data = jsonEncode(save.toJson());
    return _writing = _writing.then((_) => _backend.write(data)).catchError((Object _) {});
  }
}

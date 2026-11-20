import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/group_model.dart';

class GroupRepository {
  static const String _groupsKey = 'wlink_local_groups';
  static const String _savedKey = 'wlink_saved_group_ids';

  Future<List<GroupModel>> getGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_groupsKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) =>
                GroupModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (error) {
      final backupKey =
          '${_groupsKey}_corrupt_backup_${DateTime.now().millisecondsSinceEpoch}';

      await prefs.setString(backupKey, raw);

      throw FormatException(
        'Saved group data is corrupted. A backup was created.',
        error,
      );
    }
  }

  Future<void> saveGroup(GroupModel group) async {
    final groups = await getGroups();
    groups.removeWhere((item) => item.id == group.id);
    groups.insert(0, group);
    await _saveGroups(groups);
  }

  Future<void> deleteGroup(String id) async {
    final groups = await getGroups();
    groups.removeWhere((group) => group.id == id);
    await _saveGroups(groups);

    final savedIds = await getSavedIds();
    savedIds.remove(id);
    await _saveSavedIds(savedIds);
  }

  Future<List<String>> getSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_savedKey) ?? [];
    final uniqueIds = ids.toSet().toList();

    if (uniqueIds.length != ids.length) {
      await _saveSavedIds(uniqueIds);
    }

    return uniqueIds;
  }

  Future<bool> isSaved(String id) async {
    final ids = await getSavedIds();
    return ids.contains(id);
  }

  Future<void> toggleSaved(String id) async {
    final ids = await getSavedIds();

    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }

    await _saveSavedIds(ids);
  }

  Future<void> _saveGroups(List<GroupModel> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(groups.map((group) => group.toJson()).toList());
    await prefs.setString(_groupsKey, encoded);
  }

  Future<void> _saveSavedIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final uniqueIds = ids.toSet().toList();
    await prefs.setStringList(_savedKey, uniqueIds);
  }
}

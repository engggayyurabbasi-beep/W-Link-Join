import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:w_link_join/data/group_repository.dart';
import 'package:w_link_join/models/group_model.dart';

void main() {
  late GroupRepository repository;

  GroupModel createGroup({String id = 'group-1', String name = 'Test Group'}) {
    return GroupModel(
      id: id,
      name: name,
      currentLink: 'https://chat.whatsapp.com/Abc123',
      imageUrl: 'https://example.com/image.png',
      category: 'Education',
      subcategory: 'Study',
      country: 'India',
      state: 'Haryana',
      city: 'Mathura',
      language: 'Hindi',
      description: 'Test description',
      rules: 'Be respectful',
      createdAt: DateTime(2026, 1, 1),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = GroupRepository();
  });

  test('Group can be saved and loaded', () async {
    await repository.saveGroup(createGroup());

    final groups = await repository.getGroups();

    expect(groups.length, 1);
    expect(groups.first.name, 'Test Group');
  });

  test('Duplicate Group ID updates existing group', () async {
    await repository.saveGroup(createGroup(name: 'Old Name'));
    await repository.saveGroup(createGroup(name: 'New Name'));

    final groups = await repository.getGroups();

    expect(groups.length, 1);
    expect(groups.first.name, 'New Name');
  });

  test('Deleting a group also removes it from saved list', () async {
    await repository.saveGroup(createGroup());
    await repository.toggleSaved('group-1');

    await repository.deleteGroup('group-1');

    expect(await repository.getGroups(), isEmpty);
    expect(await repository.getSavedIds(), isEmpty);
  });

  test('Saved group can be toggled on and off', () async {
    await repository.toggleSaved('group-1');
    expect(await repository.isSaved('group-1'), isTrue);

    await repository.toggleSaved('group-1');
    expect(await repository.isSaved('group-1'), isFalse);
  });

  test('Duplicate saved IDs are removed', () async {
    SharedPreferences.setMockInitialValues({
      'wlink_saved_group_ids': ['group-1', 'group-1', 'group-2'],
    });

    final ids = await repository.getSavedIds();

    expect(ids, ['group-1', 'group-2']);
  });
}

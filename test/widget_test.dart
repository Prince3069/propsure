// Replaces the default Flutter counter test, which looked for a class called
// MyApp/PropsureApp that this test never imported. These are plain Dart tests
// that need no Firebase, so they run with: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:propsure/core/constants/rooms.dart';

void main() {
  test('room label keeps only the room name before the detail', () {
    expect(baseRoomLabel('Kitchen · Oven'), 'Kitchen');
    expect(baseRoomLabel('Bedroom 1'), 'Bedroom 1');
    expect(baseRoomLabel('  Living room  '), 'Living room');
  });

  test('kitchen offers separate views such as cooker and oven', () {
    final choices = detailChoices(RoomKind.kitchen);
    expect(choices, contains('Oven'));
    expect(choices, contains('Gas cooker'));
  });
}

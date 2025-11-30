import 'package:flutter_test/flutter_test.dart';
import 'package:contacts_kit/contacts_kit.dart';
import 'package:contacts_kit/contacts_kit_platform_interface.dart';
import 'package:contacts_kit/contacts_kit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockContactsKitPlatform
    with MockPlatformInterfaceMixin
    implements ContactsKitPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ContactsKitPlatform initialPlatform = ContactsKitPlatform.instance;

  test('$MethodChannelContactsKit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelContactsKit>());
  });

  test('getPlatformVersion', () async {
    ContactsKit contactsKitPlugin = ContactsKit();
    MockContactsKitPlatform fakePlatform = MockContactsKitPlatform();
    ContactsKitPlatform.instance = fakePlatform;

    expect(await contactsKitPlugin.getPlatformVersion(), '42');
  });
}

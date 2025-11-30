import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Contact {
  final String id;
  final String displayName;
  final String? givenName;
  final String? familyName;
  final List<String> phones;
  final List<String> emails;

  Contact({
    required this.id,
    required this.displayName,
    this.givenName,
    this.familyName,
    required this.phones,
    required this.emails,
  });

  factory Contact.fromMap(Map<dynamic, dynamic> map) {
    return Contact(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      givenName: map['givenName'] as String?,
      familyName: map['familyName'] as String?,
      phones: List<String>.from(map['phones'] ?? []),
      emails: List<String>.from(map['emails'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'givenName': givenName,
      'familyName': familyName,
      'phones': phones,
      'emails': emails,
    };
  }

  @override
  String toString() {
    return 'Contact(id: $id, displayName: $displayName, phones: $phones, emails: $emails)';
  }
}

class ContactsKit {
  static const MethodChannel _channel = MethodChannel('contacts_kit');

  /// Get platform version (your existing method)
  Future<String?> getPlatformVersion() async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  /// Request contacts permission
  static Future<bool> requestPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('requestPermission');
      return granted;
    } catch (e) {
      debugPrint('Error requesting permission: $e');
      return false;
    }
  }

  /// Check if contacts permission is granted
  static Future<bool> hasPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('hasPermission');
      return granted;
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }

  /// Get all contacts from device
  static Future<List<Contact>> getAllContacts({
    bool withPhones = false,
    bool withEmails = false,
    bool withStructuredNames = true,
  }) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod(
        'getAllContacts',
        <String, bool>{
          'withPhones': withPhones,
          'withEmails': withEmails,
          'withStructuredNames': withStructuredNames,
        },
      );
      return result.map((contact) => Contact.fromMap(contact)).toList();
    } catch (e) {
      debugPrint('Error getting contacts: $e');
      return [];
    }
  }

  /// Get contacts count without fetching all data (faster)
  static Future<int> getContactsCount() async {
    try {
      final int count = await _channel.invokeMethod('getContactsCount');
      return count;
    } catch (e) {
      debugPrint('Error getting contacts count: $e');
      return 0;
    }
  }
}

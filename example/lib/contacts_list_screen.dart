import 'package:contacts_kit/contacts_kit.dart' show ContactsKit, Contact;
import 'package:flutter/material.dart';

class ContactsListScreen extends StatefulWidget {
  const ContactsListScreen({super.key});

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  final _contactsKit = ContactsKit();
  List<Contact> _contacts = [];
  bool _loading = false;
  bool _hasPermission = false;
  String? _platformVersion;
  String _fetchTime = "Not yet fetched";

  @override
  void initState() {
    super.initState();
    _initPlugin();
  }

  Future<void> _initPlugin() async {
    final version = await _contactsKit.getPlatformVersion();
    final hasPermission = await ContactsKit.hasPermission();

    setState(() {
      _platformVersion = version;
      _hasPermission = hasPermission;
    });

    if (hasPermission) {
      _loadContacts();
    }
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _fetchTime = "Fetching...";
      _contacts = [];
    });

    final start = DateTime.now();
    final contacts = await ContactsKit.getAllContacts(withEmails: false);
    final end = DateTime.now();
    final duration = end.difference(start);

    setState(() {
      _contacts = contacts;
      _loading = false;
      if (duration.inMilliseconds < 1000) {
        _fetchTime = "${duration.inMilliseconds} ms";
      } else {
        _fetchTime =
            "${(duration.inMilliseconds / 1000).toStringAsFixed(2)} sec";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Manager'),
        centerTitle: false, // Align title to start
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20), // Smaller icon
            tooltip: 'Refresh Contacts',
            onPressed: _hasPermission && !_loading ? _loadContacts : null,
          ),
        ],
      ),
      body: Container(
        color: Colors.grey.shade50, // Very light background
        child: Column(
          children: [
            // --- Compact Info Header Section ---
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 16,
              ), // Smaller padding
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_contacts.length} Contacts', // More concise text
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                  Text(
                    'Load Time: $_fetchTime', // More concise text
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          _fetchTime.contains('ms') ||
                              _fetchTime.contains('sec')
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // --- Platform Version Info (optional, can be removed for smallest UI) ---
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 16,
              ), // Smaller padding
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Platform: $_platformVersion',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.blue.shade800),
                ),
              ),
            ),
            // --- Main Content ---
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0), // Reduced padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.security,
                size: 50,
                color: Colors.redAccent,
              ), // Slightly smaller icon
              const SizedBox(height: 15),
              Text(
                'Permission Denied', // More direct
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Contact access is required. Please tap below to grant permission.', // More concise
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                onPressed: () async {
                  final granted = await ContactsKit.requestPermission();
                  setState(() {
                    _hasPermission = granted;
                  });
                  if (granted) {
                    _loadContacts();
                  }
                },
                icon: const Icon(Icons.vpn_key, size: 18), // Smaller icon
                label: const Text('Grant Access'), // More concise label
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ), // Smaller button
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                  ), // Smaller text
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.indigo),
            const SizedBox(height: 12),
            Text(
              "Loading contacts...",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.indigo),
            ),
          ],
        ),
      );
    }

    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.contact_phone_outlined,
              size: 50,
              color: Colors.grey,
            ),
            const SizedBox(height: 15),
            Text(
              'No contacts found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadContacts,
              icon: const Icon(Icons.group_add, size: 18),
              label: const Text('Reload Contacts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                textStyle: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    // --- Compact Contacts List View ---
    return ListView.builder(
      itemCount: _contacts.length,
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 0,
      ), // Minimal padding
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        final bool hasPhone = contact.phones.isNotEmpty;
        final bool hasEmail = contact.emails.isNotEmpty;

        return Card(
          margin: const EdgeInsets.symmetric(
            vertical: 3,
            horizontal: 6,
          ), // Very small margins
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.shade400,
              radius: 20, // Smaller avatar
              child: Text(
                contact.displayName.isNotEmpty
                    ? contact.displayName[0].toUpperCase()
                    : '?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Smaller text in avatar
                ),
              ),
            ),
            title: Text(
              contact.displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ), // Slightly smaller
              overflow: TextOverflow.ellipsis, // Handle long names
            ),
            subtitle: Text(
              hasPhone
                  ? contact.phones.first
                  : hasEmail
                  ? contact.emails.first
                  : 'No primary info', // More concise
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ), // Smaller subtitle
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min, // Make row take minimal space
              children: [
                if (hasPhone)
                  Padding(
                    padding: const EdgeInsets.only(
                      right: 6.0,
                    ), // Space between icons
                    child: Icon(
                      Icons.phone,
                      size: 16,
                      color: Colors.green.shade700,
                    ), // Smaller icon
                  ),
                if (hasEmail)
                  Icon(
                    Icons.email,
                    size: 16,
                    color: Colors.redAccent.shade700,
                  ), // Smaller icon
                // Removed the count text to make it more compact, just icons
              ],
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tapped on ${contact.displayName}')),
              );
            },
          ),
        );
      },
    );
  }
}

// Integration tests for Voys / VoIPGRID Resgate endpoints.
//
// These tests are specific to the Voys environment and cannot be run without
// valid credentials and access to the VoIPGRID and Resgate infrastructure.
// The following environment variables must be set before running:
//
//   VOIPGRID_API_TOKEN   - VoIPGRID API token
//   VOIPGRID_EMAIL       - VoIPGRID account email address
//   RESGATE_URL          - WebSocket URL of the Resgate server
//   VOIPGRID_API_URL     - Base URL of the VoIPGRID API
//   AVAILABILITY_API_URL - Base URL of the availability/user-status API
//
// Use run_voys_tests.sh to set these and run the tests.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:resgate_client/client.dart';
import 'package:resgate_client/collection.dart';
import 'package:resgate_client/model.dart';
import 'package:test/test.dart';

void main() {
  final apiToken = _requireEnv('VOIPGRID_API_TOKEN');
  final email = _requireEnv('VOIPGRID_EMAIL');
  final resgateUrl = _requireEnv('RESGATE_URL');
  final voipgridApiUrl = _requireEnv('VOIPGRID_API_URL');
  final availabilityApiUrl = _requireEnv('AVAILABILITY_API_URL');

  late String clientUuid;
  late String userUuid;
  late ResClient client;

  setUpAll(() async {
    final response = await http.get(
      Uri.parse('$voipgridApiUrl/v2/user/details'),
      headers: apiToken.asTokenHeader,
    );
    if (response.statusCode.isNotSuccessful) {
      throw Exception('Failed to fetch user details: ${response.body}');
    }
    final userDetails = jsonDecode(response.body) as Map<String, dynamic>;
    userUuid = userDetails['uuid'] as String;
    clientUuid =
        (userDetails['client'] as Map<String, dynamic>)['uuid'] as String;
    print('Authenticated as $email (client $clientUuid).');
    client = ResClient();
    client.connect(resgateUrl);
    await client.authenticate('usertoken.login', {'token': apiToken});
  });

  tearDownAll(() async => client.destroy());

  test('receives shared contact information when connecting to Resgate',
      () async {
    final collection = await client.contactBook(clientUuid);
    expect(
      collection.models,
      isNotEmpty,
      reason: 'Expected to receive contacts from Resgate',
    );
    final contacts = collection.models;
    print(
      '- Resgate returned ${contacts.length} contacts from the shared contact'
      ' book, including ${contacts.previewNames((c) => c.contactName)}.',
    );
    await collection.destroy();
  });

  test('receives colleague availability when connecting to Resgate', () async {
    final collection = await client.availabilityCollection(clientUuid);
    expect(
      collection.models,
      isNotEmpty,
      reason: 'Expected to receive availability data from Resgate',
    );
    final colleagues = collection.models;
    final ourModel = colleagues.forUser(userUuid);
    final others = colleagues.where((m) => m.userUuid != userUuid);
    print(
      '- Resgate returned availability for ${colleagues.length} colleagues,'
      ' including ${others.previewNames((m) => m.collegeName)}.',
    );
    print('- Our current availability status is: ${ourModel.availability}.');
    await collection.destroy();
  });

  test('reflects availability changes via Resgate when the API is updated',
      () async {
    final collection = await client.availabilityCollection(clientUuid);
    final ourModel = collection.models.forUser(userUuid);
    final originalStatus = ourModel.availability;
    print('- Our current availability status is: $originalStatus.');

    await _toggleAndVerifyAvailability(
      ourModel,
      originalStatus,
      availabilityApiUrl,
      apiToken,
      clientUuid,
      userUuid,
    );
    await collection.destroy();
  });

  test('receives contact update via Resgate when a contact is changed',
      () async {
    final collection = await client.contactBook(clientUuid);
    expect(
      collection.models,
      isNotEmpty,
      reason: 'Expected to receive contacts from Resgate',
    );
    final contact = collection.models.first;
    final originalGivenName = contact.givenName;
    final modifiedGivenName = originalGivenName?.isNotEmpty == true
        ? '$originalGivenName (test)'
        : '(test)';

    print(
      '- Subscribed to contact book via Resgate.'
      ' Selected "${contact.contactName}" to update.',
    );
    print(
      '- Changing given name from "${originalGivenName ?? "(none)"}"'
      ' to "$modifiedGivenName" via the API'
      ' and waiting for Resgate to confirm the change...',
    );

    final contactUrl = Uri.parse(
      '${availabilityApiUrl.holodeckUrl}'
      '/contactbook/clients/$clientUuid/contacts/${contact.contactId}',
    );
    final contactHeaders = apiToken.asBearerHeader.withJsonContentType;

    final pendingChange = contact.awaitChange<String?>('given_name');
    final changeResponse = await http.put(
      contactUrl,
      headers: contactHeaders,
      body: jsonEncode(contact.asUpdateBody({'given_name': modifiedGivenName})),
    );
    expect(
      changeResponse.statusCode.isSuccessful,
      isTrue,
      reason: 'Contact update API request should succeed',
    );

    final updatedGivenName = await pendingChange;
    print(
      '- Resgate confirmed the contact\'s given name changed'
      ' from "${originalGivenName ?? "(none)"}" to "$updatedGivenName".',
    );
    expect(
      updatedGivenName,
      equals(modifiedGivenName),
      reason: 'Contact update should be reflected via Resgate',
    );

    print('- Restoring given name back to "${originalGivenName ?? "(none)"}".');
    await http.put(
      contactUrl,
      headers: contactHeaders,
      body: jsonEncode(contact.asUpdateBody({'given_name': originalGivenName})),
    );
    await collection.destroy();
  });

  test('receives destination change via Resgate when destination is updated',
      () async {
    final destinationsResponse = await http.get(
      Uri.parse('$voipgridApiUrl/v2/user/details'),
      headers: apiToken.asTokenHeader,
    );
    if (destinationsResponse.statusCode.isNotSuccessful) {
      throw Exception(
        'Failed to fetch destinations'
        ' (${destinationsResponse.statusCode}): ${destinationsResponse.body}',
      );
    }

    final userDetails =
        jsonDecode(destinationsResponse.body) as Map<String, dynamic>;
    final selectedUserDestinationId = userDetails.selectedUserDestinationId;
    final phoneAccounts = userDetails.phoneAccounts;
    final fixedDestinations = userDetails.fixedDestinations;
    final allDestinations = [...phoneAccounts, ...fixedDestinations];

    if (allDestinations.length < 2) {
      markTestSkipped('Account needs at least 2 destinations for this test');
      return;
    }

    print(
      '- Found ${allDestinations.length} available destinations'
      ' for this account.',
    );

    final collection = await client.availabilityCollection(clientUuid);
    final ourModel = collection.models.forUser(userUuid);
    final currentDestinationId = ourModel.destinationPortalId;
    final currentDesc = ourModel.destinationDesc;
    print('- Resgate reports our current destination as: $currentDesc.');

    final newDestination = allDestinations.firstWhere(
      (d) => d['id'].toString() != currentDestinationId?.toString(),
    );
    final isPhoneAccount = phoneAccounts.contains(newDestination);
    final newDesc = newDestination['description'] ?? newDestination['id'];
    print(
      '- Changing destination to "$newDesc" via the API,'
      ' then re-subscribing to Resgate to confirm the change...',
    );

    await collection.destroy();

    final destinationUrl = Uri.parse(
      '$voipgridApiUrl/selecteduserdestination/$selectedUserDestinationId/',
    );
    final changeResponse = await http.put(
      destinationUrl,
      headers: '$email:$apiToken'.asTokenHeader.withJsonContentType,
      body: jsonEncode(_destinationBody(isPhoneAccount, newDestination['id'])),
    );
    expect(
      changeResponse.statusCode.isSuccessful,
      isTrue,
      reason: 'Destination change API request should succeed',
    );

    await _propagationDelay();

    final updatedCollection = await client.availabilityCollection(clientUuid);
    final updatedModel = updatedCollection.models.forUser(userUuid);
    final updatedPortalId = updatedModel.destinationPortalId;
    print(
      '- Resgate returned the following destination data'
      ' after re-subscribing: ${updatedModel.destinationData}',
    );
    print(
      '- Destination confirmed changed from "$currentDesc"'
      ' to "$newDesc" (portal_id: $updatedPortalId).',
    );
    expect(
      updatedPortalId?.toString(),
      equals(newDestination['id'].toString()),
      reason: 'Destination change should be reflected via Resgate',
    );

    await _propagationDelay();
    if (currentDestinationId != null) {
      print('- Restoring destination back to "$currentDesc".');
      final wasPhoneAccount =
          phoneAccounts.any((d) => d['id'] == currentDestinationId);
      await http.put(
        destinationUrl,
        headers: '$email:$apiToken'.asTokenHeader.withJsonContentType,
        body:
            jsonEncode(_destinationBody(wasPhoneAccount, currentDestinationId)),
      );
    }
    await updatedCollection.destroy();
  });

  test(
    'continues to receive availability updates after being connected for 1 minute',
    () async {
      final collection = await client.availabilityCollection(clientUuid);
      expect(
        collection.models,
        isNotEmpty,
        reason: 'Expected to receive availability data from Resgate',
      );
      final ourModel = collection.models.forUser(userUuid);
      final originalStatus = ourModel.availability;
      print('- Our current availability status is: $originalStatus.');

      await _toggleAndVerifyAvailability(
        ourModel,
        originalStatus,
        availabilityApiUrl,
        apiToken,
        clientUuid,
        userUuid,
      );

      print('- Waiting 1 minute before verifying updates still work...');
      await Future.delayed(const Duration(minutes: 1));
      print(
          '- 1 minute elapsed. Verifying Resgate updates are still received...');

      await _toggleAndVerifyAvailability(
        ourModel,
        originalStatus,
        availabilityApiUrl,
        apiToken,
        clientUuid,
        userUuid,
      );
      await collection.destroy();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'maintains an active Resgate connection over extended periods'
    ' (5m, 10m, 30m, 90m, 2hr)',
    () async {
      if (Platform.environment['RUN_LONG_TESTS'] != 'true') {
        markTestSkipped(
          'Long-running test (~4hr 15min) skipped by default.'
          ' Use --run-long-tests flag to run.',
        );
        return;
      }

      final collection = await client.availabilityCollection(clientUuid);
      expect(
        collection.models,
        isNotEmpty,
        reason: 'Expected to receive availability data from Resgate',
      );
      final ourModel = collection.models.forUser(userUuid);
      final originalStatus = ourModel.availability;
      print('- Our current availability status is: $originalStatus.');

      await _toggleAndVerifyAvailability(
        ourModel,
        originalStatus,
        availabilityApiUrl,
        apiToken,
        clientUuid,
        userUuid,
      );

      for (final interval in const [
        Duration(minutes: 5),
        Duration(minutes: 10),
        Duration(minutes: 30),
        Duration(minutes: 90),
        Duration(hours: 2),
      ]) {
        print(
          '- Waiting ${_durationLabel(interval)} before next check...',
        );
        await Future.delayed(interval);
        print(
          '- ${_durationLabel(interval)} elapsed.'
          ' Verifying Resgate connection is still active...',
        );
        await _toggleAndVerifyAvailability(
          ourModel,
          originalStatus,
          availabilityApiUrl,
          apiToken,
          clientUuid,
          userUuid,
        );
      }

      await collection.destroy();
    },
    timeout: const Timeout(Duration(hours: 6)),
  );
}

// --- Helpers ---

String _requireEnv(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    throw Exception('$name environment variable is required.');
  }
  return value;
}

Future<void> _propagationDelay() => Future.delayed(const Duration(seconds: 1));

Future<void> _toggleAndVerifyAvailability(
  _RawModel ourModel,
  String originalStatus,
  String availabilityApiUrl,
  String apiToken,
  String clientUuid,
  String userUuid,
) async {
  final newStatus =
      originalStatus == 'available' ? 'available_for_colleagues' : 'available';
  print(
    '- Changing our availability to "$newStatus" via the API'
    ' and waiting for Resgate to confirm the change...',
  );

  final pendingChange = ourModel.awaitChange<String>('availability');
  final changeResponse = await http.post(
    Uri.parse(
      '$availabilityApiUrl/clients/$clientUuid/users/$userUuid/status',
    ),
    headers: apiToken.asTokenHeader.withJsonContentType,
    body: jsonEncode({'status': newStatus}),
  );
  expect(
    changeResponse.statusCode.isSuccessful,
    isTrue,
    reason: 'Availability status change API request should succeed',
  );

  final updatedAvailability = await pendingChange;
  print(
    '- Resgate confirmed our availability changed'
    ' from "$originalStatus" to "$updatedAvailability".',
  );
  expect(
    updatedAvailability,
    equals(newStatus),
    reason: 'Availability change should be reflected via Resgate',
  );

  print('- Restoring availability back to "$originalStatus".');
  await http.post(
    Uri.parse(
      '$availabilityApiUrl/clients/$clientUuid/users/$userUuid/status',
    ),
    headers: apiToken.asTokenHeader.withJsonContentType,
    body: jsonEncode({'status': originalStatus}),
  );
}

String _durationLabel(Duration d) => d.inHours >= 1
    ? '${d.inHours} hour'
    : '${d.inMinutes} minute${d.inMinutes == 1 ? '' : 's'}';

Map<String, String> _destinationBody(bool isPhoneAccount, dynamic id) => {
      (isPhoneAccount ? 'phoneaccount' : 'fixeddestination'): id.toString(),
    };

// --- Extensions ---

extension on int {
  bool get isSuccessful => this >= 200 && this < 300;
  bool get isNotSuccessful => !isSuccessful;
}

extension on String {
  Map<String, String> get asTokenHeader => {'Authorization': 'Token $this'};
  Map<String, String> get asBearerHeader => {'Authorization': 'Bearer $this'};
  String get holodeckUrl => replaceFirst(RegExp(r'/user-status/?$'), '');
}

extension on Map<String, String> {
  Map<String, String> get withJsonContentType =>
      {...this, 'Content-Type': 'application/json'};
}

extension on ResClient {
  Future<ResCollection<_RawModel>> contactBook(String clientUuid) =>
      getCollection(
        'contactbook.client.$clientUuid?start=0&limit=50',
        _RawModel.new,
      );

  Future<ResCollection<_RawModel>> availabilityCollection(String clientUuid) =>
      getCollection('availability.client.$clientUuid', _RawModel.new);
}

extension on Iterable<_RawModel> {
  _RawModel forUser(String userUuid) => firstWhere(
        (m) => m.userUuid == userUuid,
        orElse: () =>
            throw StateError('Could not find entry for user $userUuid'),
      );

  String previewNames(String Function(_RawModel) nameOf) {
    final list = toList();
    final examples = list.take(2).map(nameOf).join(' and ');
    final remaining = list.length - 2;
    return '$examples and $remaining more';
  }
}

extension on Map<String, dynamic> {
  String get selectedUserDestinationId =>
      (this['selected_destination'] as Map<String, dynamic>)['id'] as String;

  List<Map<String, dynamic>> get phoneAccounts =>
      ((this['destinations'] as Map<String, dynamic>)['voip_accounts'] as List)
          .cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get fixedDestinations =>
      ((this['destinations'] as Map<String, dynamic>)['fixed_destinations']
              as List)
          .cast<Map<String, dynamic>>();
}

extension on _RawModel {
  String get contactName {
    final given = data['given_name'] as String?;
    final family = data['family_name'] as String?;
    final company = data['company_name'] as String?;
    final name = [given, family].whereType<String>().join(' ').trim();
    return name.isNotEmpty ? name : (company ?? '(no name)');
  }

  String get collegeName =>
      data['full_name'] as String? ?? data['user_uuid'] as String;

  String get userUuid => data['user_uuid'] as String;
  String get availability => data['availability'] as String;
  String get contactId => data['id'] as String;
  String? get givenName => data['given_name'] as String?;

  Map<String, dynamic>? get destinationData =>
      (data['destination'] as Map<String, dynamic>?)?['data']
          as Map<String, dynamic>?;

  dynamic get destinationPortalId => destinationData?['portal_id'];

  String get destinationDesc => destinationData?['internal_number'] != null
      ? 'ext ${destinationData!['internal_number']} (${destinationData!['type']})'
      : 'none';

  List<Map<String, dynamic>> get phoneNumbersBody {
    final raw = data['phone_numbers'];
    final list = (raw is Map ? raw['data'] as List : raw as List)
        .cast<Map<String, dynamic>>();
    return list
        .map((p) => {'phone_number_flat': p['phone_number_flat']})
        .toList();
  }

  Map<String, dynamic> asUpdateBody(Map<String, dynamic> overrides) => {
        'given_name': data['given_name'],
        'family_name': data['family_name'],
        'company_name': data['company_name'] ?? '',
        'phone_numbers': phoneNumbersBody,
        ...overrides,
      };

  Future<T> awaitChange<T>(String field) {
    final completer = Completer<T>();
    onChange((values) {
      if (values.containsKey(field) && !completer.isCompleted) {
        print(
          '- Resgate sent a change event with the following updated fields:'
          ' $values',
        );
        completer.complete(values[field] as T);
      }
    });
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException(
        'Timed out waiting for "$field" change via Resgate',
        const Duration(seconds: 10),
      ),
    );
  }
}

/// Simple model that stores raw JSON values without any interpretation.
class _RawModel extends ResModel {
  Map<String, dynamic> data = {};

  @override
  void updateFromJson(Map<String, dynamic> json) {
    data.addAll(json);
  }
}

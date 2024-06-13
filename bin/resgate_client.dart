import 'package:resgate_client/client.dart';

class UserAvailabilityModel {
  String userStatus;

  UserAvailabilityModel({required this.userStatus});

  factory UserAvailabilityModel.fromJson(Map json) {
    return UserAvailabilityModel(
      userStatus: json["user_status"],
    );
  }

  @override
  String toString() {
    return "UserAvailabilityModel: $userStatus";
  }
}

void main() async {
  final client =
      ResClient('wss://frontend-resgate-mocking.stag.holodeck.spindle.dev');

  await client.authenticate("usertoken.login", {"token": "my-vg-api-token"});

  final collection =
      await client.getCollection("availability.client.abc-123", (json) {
    return UserAvailabilityModel.fromJson(json);
  });

  print(collection.getModels());
}

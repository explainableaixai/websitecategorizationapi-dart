import 'dart:io';
import 'package:websitecategorizationapi/websitecategorizationapi.dart';

Future<void> main() async {
  final client = WebsiteCategorizationAPIClient(
      apiKey: Platform.environment['AQ_API_KEY'] ?? '');
  try {
    print(await client.classify('https://example.com/article'));
  } finally {
    client.close();
  }
}

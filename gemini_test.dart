import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('No .env file found');
    return;
  }
  
  final lines = envFile.readAsLinesSync();
  String apiKey = '';
  for (var line in lines) {
    if (line.startsWith('GEMINI_API_KEY=')) {
      apiKey = line.split('=')[1].trim();
      break;
    }
  }

  if (apiKey.isEmpty) {
    print('No GEMINI_API_KEY found in .env');
    return;
  }

  print('Testing API Key ending in ${apiKey.substring(apiKey.length - 4)}');

  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=\$apiKey');
  final response = await http.get(url);
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final models = data['models'] as List;
    print('Available models for this key:');
    for (var m in models) {
      if (m['name'].toString().contains('gemini')) {
        print(" - ${m['name']} (supported methods: ${m['supportedGenerationMethods']})");
      }
    }
  } else {
    print('Error listing models: ${response.body}');
  }
}

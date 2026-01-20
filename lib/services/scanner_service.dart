import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/currency_helper.dart';

class BillItem {
  String name;
  double price;
  String? assignedToId;
  BillItem({required this.name, required this.price, this.assignedToId});
}

class ReceiptData {
  List<BillItem> items;
  double tax;
  double serviceCharge;
  double subtotal;
  
  //why are we initializing receipt data class here inside its own class?
  // this is a concept called constructor with named parameters and default values.
  // in dart, when you define a class, you can create a constructor that allows you to
  // initialize the class's properties when you create an instance of that class.
  // so basically each time we create a class in dart, we can define a constructor
  // that takes named parameters, and we can also provide default values for those parameters.
  ReceiptData({
    required this.items,
    this.tax = 0.0,
    this.serviceCharge = 0.0,
    this.subtotal = 0.0,
  });
  
  // logic to calculate each person's total + tax/service charge, discount is not yet applied
  Map<String, double> calculatePersonTotals() {
    Map<String, double> personSubtotals = {};
    double itemsTotal = 0.0;
    
    // First, get each person's subtotal
    for (var item in items) {
      if (item.assignedToId != null) {
        personSubtotals[item.assignedToId!] = 
            (personSubtotals[item.assignedToId!] ?? 0) + item.price;
        itemsTotal += item.price;
      }
    }
    
    // Then apply tax and service charge proportionally
    Map<String, double> finalTotals = {};
    double totalCharges = tax + serviceCharge;
    
    personSubtotals.forEach((personId, subtotal) {
      double proportion = itemsTotal > 0 ? subtotal / itemsTotal : 0;
      double personCharges = totalCharges * proportion;
      finalTotals[personId] = subtotal + personCharges;
    });
    
    return finalTotals;
  }
}

class ScannerService {
  final _picker = ImagePicker();
  
  // DEBUG: Print the key status when accessed
  String get _apiKey {
    String? key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      print("🚨 CRITICAL ERROR: API Key is MISSING or EMPTY in .env file!");
      return "";
    }
    return key;
  }

  // DEBUG: List all available models
  Future<void> listAvailableModels() async {
    print("🔍 Listing available Gemini models...");
    try {
      if (_apiKey.isEmpty) {
        throw Exception("API Key is empty");
      }
      
      // Try to list models using the API
      final model = GenerativeModel(
        model: 'gemini-pro', // Use basic model for testing
        apiKey: _apiKey,
      );
      
      print("✅ Connection successful! Try these models:");
      print("   - gemini-pro");
      print("   - gemini-pro-vision");
      print("   - gemini-1.5-flash");
      print("   - gemini-1.5-pro");
      print("   - gemini-2.0-flash-exp");
      
    } catch (e) {
      print("❌ Error listing models: $e");
    }
  }

  Future<ReceiptData> scanAndParse({ImageSource source = ImageSource.camera}) async {
    print("🔵 STARTING SCAN...");
    
    try {
      // CHECK 1: Is the key loaded?
      if (_apiKey.isEmpty) {
        throw Exception("API Key is empty. Check .env file.");
      }
      print("✅ API Key found (Length: ${_apiKey.length})");
      
      // CHECK 1.5: List available models
      print("🔍 Fetching available models from API...");
      try {
        final response = await http.get(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey'),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print("📋 Available models:");
          for (var model in data['models'] ?? []) {
            if (model['supportedGenerationMethods']?.contains('generateContent') == true) {
              print("   ✅ ${model['name']}");
            }
          }
        } else {
          print("⚠️ Failed to list models: ${response.statusCode}");
        }
      } catch (e) {
        print("⚠️ Error listing models: $e");
      }

      // CHECK 2: Camera
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 70, 
      );
      
      if (photo == null) {
        print("⚠️ User cancelled the camera.");
        return ReceiptData(items: []);
      }
      print("✅ Image taken: ${photo.path}");
      print("⚖️ Image size: ${await File(photo.path).length()} bytes");

      // CHECK 3: Model Setup
      // 1. DYNAMIC MIME TYPE (Don't assume JPEG)
      // Get the mime type based on extension, or default to jpeg
      final mimeType = photo.path.endsWith('.png') ? 'image/png' : 'image/jpeg';

      print("🤖 Trying model: models/gemini-2.5-flash-lite");

      // 2. SAFETY SETTINGS (Crucial for Receipts)
      final model = GenerativeModel(
        model: 'models/gemini-2.5-flash-lite',
        apiKey: _apiKey,
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        ],
      );

      print("⏳ Sending to Google...");

      final imageBytes = await File(photo.path).readAsBytes();
      final prompt = TextPart("""
System: You are a strict JSON-only API. 
Task: Extract data from this receipt.

Output strict JSON:
{
  "items": [{"name": "Item Name", "price": 12.50}],
  "tax": 1.50,
  "serviceCharge": 2.00,
  "subtotal": 15.00
}

Constraints:
- Return ONLY valid JSON.
- No markdown formatting (no ```json).
- No conversational text.
- If a value is missing, use 0 or "Unknown".
""");

      final response = await model.generateContent([
        Content.multi([prompt, DataPart(mimeType, imageBytes)]) // Use dynamic mime type
      ]);

      print("✅ Google Responded!");
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      print("📝 RAW RESPONSE (Full text):");
      print(response.text ?? "(NULL RESPONSE)");
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      
      // DEBUG: Check candidates and parts
      print("🔍 Response candidates: ${response.candidates.length}");
      if (response.candidates.isNotEmpty) {
        print("🔍 First candidate parts: ${response.candidates[0].content.parts.length}");
      }

      if (response.text == null || response.text!.isEmpty) {
        throw Exception("Response was empty!");
      }

      // CHECK 4: Parsing
      String rawText = response.text!.trim();
      
      print("🔧 Step 1: Removing markdown...");
      // Remove markdown code blocks if present
      String cleanJson = rawText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      
      print("📄 After markdown removal: $cleanJson");
      
      // Try to find JSON object in the response
      int startIdx = cleanJson.indexOf('{');
      int endIdx = cleanJson.lastIndexOf('}');
      
      print("🔍 Found JSON at positions: start=$startIdx, end=$endIdx");
      
      if (startIdx == -1 || endIdx == -1) {
        throw Exception("No JSON object found in response: $cleanJson");
      }
      
      cleanJson = cleanJson.substring(startIdx, endIdx + 1);
      
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      print("🧹 CLEANED JSON:");
      print(cleanJson);
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

      Map<String, dynamic> data = jsonDecode(cleanJson);
      
      print("✅ JSON decoded successfully!");
      print("🔑 Keys found: ${data.keys.join(', ')}");
      
      List<dynamic> itemsData = data['items'] ?? [];
      
      print("📦 Items array length: ${itemsData.length}");
      print("📦 Raw items data: $itemsData");
      
      if (itemsData.isEmpty) {
        print("⚠️ WARNING: Gemini returned EMPTY items array!");
        print("📝 Full response data: $data");
        throw Exception("Gemini returned empty items array - no items detected on receipt");
      }
      
      List<BillItem> items = [];
      
      print("🔄 Processing ${itemsData.length} items...");
      
      for (var item in itemsData) {
        if (item is! Map) {
          print("⚠️ Skipping non-map item: $item");
          continue;
        }
        
        String name = item['name']?.toString() ?? 'Unknown Item';
        double price = 0.0;
        
        print("  📌 Processing: name='$name', price_raw=${item['price']}");
        
        // Handle price as either number or string
        if (item['price'] is num) {
          price = (item['price'] as num).toDouble();
        } else if (item['price'] is String) {
          price = double.tryParse(item['price']) ?? 0.0;
        }
        
        print("  💵 Parsed price: $price");
        
        // Accept items even with 0 price for debugging
        items.add(BillItem(name: name, price: price));
        if (price > 0) {
          print("  ✅ Added: $name - $currencySymbol${price.toStringAsFixed(currencyDecimals)}");
        } else {
          print("  ⚠️ Added with ZERO price: $name - $currencySymbol${price.toStringAsFixed(currencyDecimals)}");
        }
      }
      
      // Extract tax and service charge
      double tax = 0.0;
      double serviceCharge = 0.0;
      double subtotal = 0.0;
      
      if (data['tax'] is num) {
        tax = (data['tax'] as num).toDouble();
      } else if (data['tax'] is String) {
        tax = double.tryParse(data['tax']) ?? 0.0;
      }
      
      if (data['serviceCharge'] is num) {
        serviceCharge = (data['serviceCharge'] as num).toDouble();
      } else if (data['serviceCharge'] is String) {
        serviceCharge = double.tryParse(data['serviceCharge']) ?? 0.0;
      }
      
      if (data['subtotal'] is num) {
        subtotal = (data['subtotal'] as num).toDouble();
      } else if (data['subtotal'] is String) {
        subtotal = double.tryParse(data['subtotal']) ?? 0.0;
      }
      
      // If subtotal is 0, calculate it from items
      if (subtotal == 0.0) {
        subtotal = items.fold(0.0, (sum, item) => sum + item.price);
      }

      print("🎉 SUCCESS! Found ${items.length} items, tax: \$$tax, service: \$$serviceCharge");
      return ReceiptData(
        items: items,
        tax: tax,
        serviceCharge: serviceCharge,
        subtotal: subtotal,
      );

    } catch (e, stackTrace) {
      print("❌ ERROR OCCURRED HERE:");
      print("---------------------------------------------------");
      print(e);
      print("---------------------------------------------------");
      // print(stackTrace); // Uncomment if you really need deep details
      return ReceiptData(items: []);
    }
  }
}
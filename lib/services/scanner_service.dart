import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  
  ReceiptData({
    required this.items,
    this.tax = 0.0,
    this.serviceCharge = 0.0,
    this.subtotal = 0.0,
  });
  
  // Calculate what each person owes including their share of tax/service charge
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

  Future<ReceiptData> scanAndParse({ImageSource source = ImageSource.camera}) async {
    print("🔵 STARTING SCAN...");
    
    try {
      // CHECK 1: Is the key loaded?
      if (_apiKey.isEmpty) {
        throw Exception("API Key is empty. Check .env file.");
      }
      print("✅ API Key found (Length: ${_apiKey.length})");

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
      // Use gemini-pro-vision which supports images for v1beta API
      final model = GenerativeModel(
        model: 'gemini-pro-vision', 
        apiKey: _apiKey,
      );

      print("⏳ Sending to Google... (This might take 2-5 seconds)");

      final imageBytes = await File(photo.path).readAsBytes();
      final prompt = TextPart("""
Analyze this receipt image and extract the line items, tax, and service charges.

Return ONLY a JSON object in this exact format:
{
  "items": [{"name": "Item Name", "price": 12.50}],
  "tax": 1.50,
  "serviceCharge": 2.00,
  "subtotal": 15.00
}

Rules:
- items: array of food/drink items only (not tax/totals)
- tax: total tax amount (or 0 if not found)
- serviceCharge: service charge/tip/gratuity (or 0 if not found)
- subtotal: sum of items before tax/charges (or 0 to auto-calculate)
- Use actual numbers, not strings
- Do NOT wrap in ```json``` or markdown
- Ignore payment method, change, total paid

Example:
{"items": [{"name": "Burger", "price": 15.00}], "tax": 1.50, "serviceCharge": 2.00, "subtotal": 15.00}
""");

      final response = await model.generateContent([
        Content.multi([prompt, DataPart('image/jpeg', imageBytes)])
      ]);

      print("✅ Google Responded!");
      print("📝 Raw Response: ${response.text}");

      if (response.text == null || response.text!.isEmpty) {
        throw Exception("Response was empty!");
      }

      // CHECK 4: Parsing
      String rawText = response.text!.trim();
      
      // Remove markdown code blocks if present
      String cleanJson = rawText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      
      // Try to find JSON object in the response
      int startIdx = cleanJson.indexOf('{');
      int endIdx = cleanJson.lastIndexOf('}');
      
      if (startIdx == -1 || endIdx == -1) {
        throw Exception("No JSON object found in response: $cleanJson");
      }
      
      cleanJson = cleanJson.substring(startIdx, endIdx + 1);
      
      print("🧹 Cleaned JSON: $cleanJson");

      Map<String, dynamic> data = jsonDecode(cleanJson);
      
      List<dynamic> itemsData = data['items'] ?? [];
      
      if (itemsData.isEmpty) {
        throw Exception("Gemini returned empty items array - no items detected on receipt");
      }
      
      List<BillItem> items = [];
      
      for (var item in itemsData) {
        if (item is! Map) continue;
        
        String name = item['name']?.toString() ?? 'Unknown Item';
        double price = 0.0;
        
        // Handle price as either number or string
        if (item['price'] is num) {
          price = (item['price'] as num).toDouble();
        } else if (item['price'] is String) {
          price = double.tryParse(item['price']) ?? 0.0;
        }
        
        if (price > 0) {
          items.add(BillItem(name: name, price: price));
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
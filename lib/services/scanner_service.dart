import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

// Data Model for a Single Line Item
class BillItem {
  String name;
  double price;
  String? assignedToId; // null = unassigned

  BillItem({required this.name, required this.price, this.assignedToId});
}

class ScannerService {
  final _picker = ImagePicker();
  final _recognizer = TextRecognizer();

  // Keywords to filter out (not food items)
  static const _blacklistKeywords = [
    'total', 'subtotal', 'sub-total', 'sub total',
    'tax', 'vat', 'gst', 'service', 'tip', 'gratuity',
    'cash', 'card', 'credit', 'debit', 'payment',
    'change', 'balance', 'amount', 'due',
    'thank you', 'receipt', 'invoice', 'bill',
    'date', 'time', 'cashier', 'server', 'table',
    'tel', 'phone', 'address', 'website', 'email',
  ];

  // Main scan function with source option
  Future<List<BillItem>> scanAndParse({ImageSource source = ImageSource.camera}) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 100, // Max quality for better OCR
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (photo == null) return [];

      final inputImage = InputImage.fromFile(File(photo.path));
      final recognizedText = await _recognizer.processImage(inputImage);

      return _parseReceipt(recognizedText);
    } catch (e) {
      print("Error scanning: $e");
      return [];
    }
  }

  // Parse the recognized text into items
  List<BillItem> _parseReceipt(RecognizedText recognizedText) {
    List<BillItem> items = [];
    
    print("🔍 Starting to parse receipt...");
    print("📝 Total blocks: ${recognizedText.blocks.length}");
    
    // Detect if receipt uses comma as thousands separator (e.g., 27,000)
    // or as decimal separator (e.g., 27,50)
    bool usesCommaThousands = _detectCommaFormat(recognizedText);
    print("💱 Currency format: ${usesCommaThousands ? 'Comma as thousands (27,000)' : 'Comma as decimal (27,50)'}");
    
    // Price patterns for thousands separator format (Indonesian/Asian receipts)
    // Order matters - try more specific patterns first
    final pricePatterns = [
      RegExp(r'(\d{1,3}(?:,\d{3})+)$'), // 27,000 at line end
      RegExp(r'(\d{4,})$'), // 4+ digits at line end
      RegExp(r'(\d{1,3}(?:,\d{3})+)'), // 27,000 anywhere
      RegExp(r'(\d{3,})'), // 3+ digit numbers
    ];

    // Flatten all lines first
    List<String> allLines = [];
    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        allLines.add(line.text.trim());
      }
    }
    
    int lineCount = 0;
    for (int i = 0; i < allLines.length; i++) {
      lineCount++;
      String text = allLines[i];
      
      print("Line $lineCount: '$text'");
      
      // Skip empty lines
      if (text.isEmpty) {
        print("  ⏭️ Skipped: empty");
        continue;
      }
      
      // Check if blacklisted
      bool isBlacklisted = _isBlacklisted(text);
      if (isBlacklisted) {
        print("  🚫 Blacklisted: $text");
        continue;
      }

      // Try current line first
      BillItem? item = _extractItemFromLine(text, pricePatterns);
      
      // If no item found and next line exists, try combining
      if (item == null && i + 1 < allLines.length) {
        String nextLine = allLines[i + 1];
        // If next line looks like a price (mostly digits), combine
        if (RegExp(r'^[\d,\.]+$').hasMatch(nextLine)) {
          String combined = '$text $nextLine';
          print("  🔗 Trying combined: '$combined'");
          item = _extractItemFromLine(combined, pricePatterns);
          if (item != null) {
            i++; // Skip next line since we consumed it
            lineCount++;
          }
        }
      }
      
      if (item != null) {
        print("  ✅ Found item: ${item.name} - \$${item.price}");
        items.add(item);
      } else {
        print("  ❌ No item extracted");
      }
    }

    print("\n📊 Total items found: ${items.length}");
    
    // Remove duplicate items (same name and price)
    items = _removeDuplicates(items);
    
    print("📊 After dedup: ${items.length}");
    
    return items;
  }

  // Detect if receipt uses comma as thousands separator
  bool _detectCommaFormat(RecognizedText text) {
    int commaThousandsCount = 0;
    
    for (var block in text.blocks) {
      for (var line in block.lines) {
        // Look for patterns like 27,000 or 1,234,567 (comma thousands)
        if (RegExp(r'\d{1,3}(?:,\d{3})+').hasMatch(line.text)) {
          commaThousandsCount++;
        }
      }
    }
    
    // If we find multiple comma-thousands patterns, assume that format
    return commaThousandsCount >= 2;
  }

  // Extract item from a single line
  BillItem? _extractItemFromLine(String text, List<RegExp> pricePatterns) {
    BillItem? bestItem;
    double? highestPrice;
    
    for (var pattern in pricePatterns) {
      var matches = pattern.allMatches(text);
      if (matches.isEmpty) continue;

      // Try the RIGHTMOST match (actual price, not item number)
      var lastMatch = matches.last;
      String priceString = lastMatch.group(1) ?? lastMatch.group(0)!;
      
      // Remove commas (they're thousands separators like 27,000 -> 27000)
      priceString = priceString.replaceAll(',', '').replaceAll(r'$', '').trim();
      
      print("    💰 Found price string: '$priceString' at position ${lastMatch.start}");
      
      double? price = double.tryParse(priceString);
      
      if (price == null) {
        print("    ⚠️ Could not parse price");
        continue;
      }
      
      print("    💵 Parsed as: \$$price");
      
      // Very lenient validation - let users fix errors manually
      if (price <= 0) {
        print("    ⚠️ Price zero or negative: $price");
        continue;
      }
      if (price > 10000000) { // 10 million max
        print("    ⚠️ Price unreasonably high: $price");
        continue;
      }

      // Extract item name (before the price)
      String rawName = text.substring(0, lastMatch.start).trim();
      print("    📝 Raw name: '$rawName'");
      
      String cleanName = _cleanItemName(rawName);
      print("    🧹 Clean name: '$cleanName'");
      
      // Accept any name (even single char) - users can fix it
      if (cleanName.isEmpty) {
        cleanName = "Item";
        print("    ℹ️ Using fallback name");
      }

      // Prefer the highest price found (avoids item numbers like "2" in "CHATINE 2")
      if (highestPrice == null || price > highestPrice) {
        highestPrice = price;
        bestItem = BillItem(name: cleanName, price: price);
        print("    ✨ New best candidate: $cleanName - \$$price");
      }
    }
    
    return bestItem;
  }

  // Clean up the item name
  String _cleanItemName(String name) {
    // Remove quantity markers like "1x", "2 x", "3X"
    name = name.replaceAll(RegExp(r'^\d+\s*[xX]\s*'), '');
    
    // Remove leading numbers and dots
    name = name.replaceAll(RegExp(r'^[\d\.\s]+'), '');
    
    // Remove special characters but keep letters, numbers, spaces
    name = name.replaceAll(RegExp(r'[^\w\s\-&]'), '');
    
    // Remove multiple spaces
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    
    // Trim and capitalize first letter
    name = name.trim();
    if (name.isNotEmpty) {
      name = name[0].toUpperCase() + name.substring(1).toLowerCase();
    }
    
    return name;
  }

  // Check if text contains blacklisted keywords
  bool _isBlacklisted(String text) {
    String lowerText = text.toLowerCase();
    
    // Minimal blacklist - only filter obvious non-items
    // Users can delete unwanted items manually
    final blacklist = [
      'total', 'subtotal', 'sub total',
      'thank you', 'thank',
      'receipt',
    ];
    
    for (var keyword in blacklist) {
      if (lowerText.contains(keyword)) {
        return true;
      }
    }
    
    // Filter lines that are too long (likely voucher codes or URLs)
    if (text.length > 40) {
      return true;
    }
    
    return false;
  }

  // Remove duplicate items
  List<BillItem> _removeDuplicates(List<BillItem> items) {
    Map<String, BillItem> uniqueItems = {};
    
    for (var item in items) {
      String key = '${item.name}_${item.price}';
      if (!uniqueItems.containsKey(key)) {
        uniqueItems[key] = item;
      }
    }
    
    return uniqueItems.values.toList();
  }

  void dispose() {
    _recognizer.close();
  }
}
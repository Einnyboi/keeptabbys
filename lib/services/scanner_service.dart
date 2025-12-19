import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

// 1. The Data Model for a Single Line Item
class BillItem {
  String name;
  double price;
  String? assignedToId; // null = unassigned

  BillItem({required this.name, required this.price, this.assignedToId});
}

class ScannerService {
  final _picker = ImagePicker();
  final _recognizer = TextRecognizer();

  // 2. The Smart Scan Function
  Future<List<BillItem>> scanAndParse() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) return [];

      final inputImage = InputImage.fromFile(File(photo.path));
      final recognizedText = await _recognizer.processImage(inputImage);

      List<BillItem> items = [];

      // 3. Regex to find prices (looks for numbers like 12.00 or 12,00 at end of line)
      // This is a simple parser. It looks for the LAST number in a line.
      final priceRegex = RegExp(r'(\d+[.,]\d{2})'); 

      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          String text = line.text;
          
          // Does this line have a price?
          if (priceRegex.hasMatch(text)) {
            // Extract the price
            var matches = priceRegex.allMatches(text);
            var lastMatch = matches.last; // Assume price is at the end
            String priceString = lastMatch.group(0)!.replaceAll(',', '.');
            double? price = double.tryParse(priceString);

            if (price != null) {
              // Extract the name (everything before the price)
              String name = text.substring(0, lastMatch.start).trim();
              if (name.isEmpty) name = "Item"; // Fallback

              items.add(BillItem(name: name, price: price));
            }
          }
        }
      }
      return items;
    } catch (e) {
      print("Error scanning: $e");
      return [];
    }
  }

  void dispose() {
    _recognizer.close();
  }
}
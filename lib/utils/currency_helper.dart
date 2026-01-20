/// Currency configuration for the app
/// Change these constants to switch to different currencies

const String currencySymbol = 'Rp';
const String currencyName = 'IDR';
const int currencyDecimals = 0; // IDR doesn't use decimals

/// Format a price value according to the current currency settings
String formatCurrency(double amount) {
  return '$currencySymbol${amount.toStringAsFixed(currencyDecimals)}';
}

/// Format a price value with thousand separators (e.g., Rp15.000)
String formatCurrencyWithSeparator(double amount) {
  final rounded = amount.toStringAsFixed(currencyDecimals);
  final parts = rounded.split('.');
  final integerPart = parts[0];
  
  // Add thousand separators (dot for IDR, comma for USD)
  final separator = currencyName == 'IDR' ? '.' : ',';
  final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  final formatted = integerPart.replaceAllMapped(
    regex,
    (Match m) => '${m[1]}$separator',
  );
  
  return '$currencySymbol$formatted${parts.length > 1 ? ',${parts[1]}' : ''}';
}

// Common currency configurations for quick switching:
// 
// Indonesian Rupiah (IDR):
// currencySymbol = 'Rp'
// currencyName = 'IDR' 
// currencyDecimals = 0
//
// US Dollar (USD):
// currencySymbol = '\$'
// currencyName = 'USD'
// currencyDecimals = 2
//
// Euro (EUR):
// currencySymbol = '€'
// currencyName = 'EUR'
// currencyDecimals = 2
//
// Malaysian Ringgit (MYR):
// currencySymbol = 'RM'
// currencyName = 'MYR'
// currencyDecimals = 2

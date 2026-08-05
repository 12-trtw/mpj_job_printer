class PrintItem {
  final String text;
  final int x;

  PrintItem(String? text, this.x) : text = text ?? '';
}

class ThaiPrintUtils {
  static int displayLength(String str) {
    final match = RegExp(r'[\u0E31\u0E34-\u0E3A\u0E47-\u0E4E]').allMatches(str);
    return str.length - match.length;
  }

  static String buildLine(List<PrintItem> items) {
    items.sort((a, b) => a.x.compareTo(b.x));
    final StringBuffer lineBuffer = StringBuffer();
    int currentX = 0;

    for (final item in items) {
      if (item.x > currentX) {
        lineBuffer.write(' ' * (item.x - currentX));
        currentX = item.x;
      }
      lineBuffer.write(item.text);
      currentX += displayLength(item.text);
    }
    return lineBuffer.toString();
  }
}

class Lq310Commands {
  static const String escInit = '\x1B\x40';
  static const String escLeftMargin0 = '\x1B\x6C\x00';
  static const String escPageLen = '\x1B\x43\x21';
  static const String font12Cpi = '\x1B\x4D';
  static const String font10Cpi = '\x1B\x50';
  static const String escCancelSkip = '\x1B\x4F';
  static const String forceTIS620 = '\x1B\x28\x43\x03\x00\x01\x00\x00';
  static const String forceITP = '\x1B\x54\x33';
  static const String formFeed = '\x0C';
}

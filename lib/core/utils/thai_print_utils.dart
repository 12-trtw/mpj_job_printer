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

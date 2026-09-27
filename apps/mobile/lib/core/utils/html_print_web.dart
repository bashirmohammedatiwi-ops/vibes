import 'dart:html' as html;

class PrintHandle {
  const PrintHandle(this.window);

  final html.WindowBase window;
}

PrintHandle? preparePrintWindow() {
  try {
    return PrintHandle(html.window.open('', '_blank'));
  } catch (_) {
    return null;
  }
}

void abandonPrintWindow(PrintHandle? handle) {
  handle?.window.close();
}

bool completePrintWindow(PrintHandle? handle, String source) {
  final window = handle?.window;
  if (window == null) return false;
  final blob = html.Blob([source], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  window.location.href = url;
  return true;
}

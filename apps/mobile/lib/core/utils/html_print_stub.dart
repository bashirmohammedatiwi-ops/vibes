class PrintHandle {
  const PrintHandle();
}

PrintHandle? preparePrintWindow() => null;

void abandonPrintWindow(PrintHandle? handle) {}

bool completePrintWindow(PrintHandle? handle, String source) => false;

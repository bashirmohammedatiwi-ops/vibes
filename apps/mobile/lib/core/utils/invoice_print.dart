import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../network/api_client.dart';
import 'html_print.dart';

Future<void> printInvoiceHtml(
  BuildContext context,
  ApiClient client, {
  required String path,
  required String fallbackText,
  String subject = 'فاتورة VIBEES',
}) async {
  final handle = preparePrintWindow();
  try {
    final html = await client.getText(path);
    if (html.trim().isEmpty) {
      throw const ApiException('تعذر تحميل الفاتورة');
    }
    if (completePrintWindow(handle, html)) return;
    abandonPrintWindow(handle);
    await Share.share(fallbackText, subject: subject);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تجهيز نص الفاتورة — احفظها PDF من الطباعة في المتصفح إن أمكن'),
      ),
    );
  } catch (e) {
    abandonPrintWindow(handle);
    await Share.share(fallbackText, subject: subject);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

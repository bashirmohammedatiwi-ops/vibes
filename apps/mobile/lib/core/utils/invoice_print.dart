import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../network/api_client.dart';
import '../i18n/i18n.dart';
import 'html_print.dart';

Future<void> printInvoiceHtml(
  BuildContext context,
  ApiClient client, {
  required String path,
  required String fallbackText,
  String? subject,
}) async {
  final shareSubject = subject ?? 'فاتورة أجواء'.tr;
  final handle = preparePrintWindow();
  try {
    final html = await client.getText(path);
    if (html.trim().isEmpty) {
      throw ApiException('تعذر تحميل الفاتورة'.tr);
    }
    if (completePrintWindow(handle, html)) return;
    abandonPrintWindow(handle);
    await Share.share(fallbackText, subject: shareSubject);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تجهيز نص الفاتورة — احفظها PDF من الطباعة في المتصفح إن أمكن'.tr,
        ),
      ),
    );
  } catch (e) {
    abandonPrintWindow(handle);
    await Share.share(fallbackText, subject: shareSubject);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

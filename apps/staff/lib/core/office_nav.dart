import 'session.dart';
import 'staff_capabilities.dart';

enum StaffTab { now, chats, bookings, ops, requests, account }

List<StaffTab> visibleStaffTabs() {
  return [
    StaffTab.now,
    if (Session.can('inbox.read')) StaffTab.chats,
    if (Session.can('bookings.read') || Session.can('bookings.write')) StaffTab.bookings,
    if (hasOpsAccess) StaffTab.ops,
    // الطلبات صارت ضمن «اليوم» و«الإدارة» — خمسة تبويبات واضحة فقط
    StaffTab.account,
  ];
}

int staffTabIndex(StaffTab tab) {
  final tabs = visibleStaffTabs();
  final i = tabs.indexOf(tab);
  return i < 0 ? 0 : i;
}

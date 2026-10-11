import 'session.dart';
import 'staff_capabilities.dart';

enum StaffTab { now, chats, bookings, ops, requests, account }

List<StaffTab> visibleStaffTabs() {
  return [
    StaffTab.now,
    if (Session.can('inbox.read')) StaffTab.chats,
    if (Session.can('bookings.read')) StaffTab.bookings,
    if (hasOpsAccess) StaffTab.ops,
    if (Session.can('cancellations.review') || Session.can('refunds.review')) StaffTab.requests,
    StaffTab.account,
  ];
}

int staffTabIndex(StaffTab tab) {
  final tabs = visibleStaffTabs();
  final i = tabs.indexOf(tab);
  return i < 0 ? 0 : i;
}

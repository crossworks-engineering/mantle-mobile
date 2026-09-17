/// Where the day dividers and time stamps fall in a thread. Pure functions
/// over the oldest-first message list, so the screen asks per index inside
/// its item builder and nothing about paging or the queued bubbles has to
/// know that dividers exist.
library;

import '../../data/chat/chat_message.dart';

/// Neighbours further apart than this get a time stamp between them.
const timeStampGap = Duration(minutes: 5);

bool _sameDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// True when the message at [index] (oldest-first) is the first of its
/// calendar day among the loaded messages, so a day divider belongs above it.
/// The oldest loaded message always starts a day: it is the first we know of,
/// and paging in older history re-answers the question.
bool startsDay(List<ChatMessage> messages, int index) {
  if (index == 0) return true;
  return !_sameDay(messages[index - 1].createdAt, messages[index].createdAt);
}

/// True when the message at [index] should show its clock time: it starts a
/// day, or the gap from the older neighbour is more than [gap]. A burst of
/// back-and-forth carries one stamp at its head, not one per bubble.
bool showsTime(
  List<ChatMessage> messages,
  int index, {
  Duration gap = timeStampGap,
}) {
  if (startsDay(messages, index)) return true;
  final since = messages[index].createdAt.difference(
    messages[index - 1].createdAt,
  );
  return since > gap;
}

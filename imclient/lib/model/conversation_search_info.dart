
import '../message/message.dart';
import 'conversation.dart';

class ConversationSearchInfo {
  ConversationSearchInfo({this.marchedCount = 0, this.timestamp = 0});
  late Conversation conversation;
  Message? marchedMessage;
  int marchedCount;
  int timestamp;
}

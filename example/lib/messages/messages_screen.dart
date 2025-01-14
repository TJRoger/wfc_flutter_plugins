import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:rtckit/rtckit.dart';

import 'message_cell.dart';
import 'message_model.dart';


class MessagesScreen extends StatefulWidget {
  final Conversation conversation;

  MessagesScreen(this.conversation);

  @override
  _State createState() => _State();
}

class _State extends State<MessagesScreen> {
  List<MessageModel> models = <MessageModel>[];
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<ReceiveMessagesEvent> _receiveMessageSubscription;

  bool isLoading = false;

  bool noMoreLocalHistoryMsg = false;
  bool noMoreRemoteHistoryMsg = false;

  TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    Imclient.getMessages(widget.conversation, 0, 10).then((value) {
      if(value != null && value.isNotEmpty) {
        _appendMessage(value);
      }
    });


    _receiveMessageSubscription = _eventBus.on<ReceiveMessagesEvent>().listen((event) {
      if(!event.hasMore) {
        _appendMessage(event.messages, front: true);
      }
    });

    Imclient.clearConversationUnreadStatus(widget.conversation);
  }

  @override
  void dispose() {
    super.dispose();
    _receiveMessageSubscription?.cancel();
  }

  void _appendMessage(List<Message> messages, {bool front = false}) {
    setState(() {
      bool haveNewMsg = false;
      messages.forEach((element) {
        if(element.conversation != widget.conversation) {
          return;
        }
        if(element.messageId == 0) {
          return;
        }

        haveNewMsg = true;
        MessageModel model = MessageModel(element, showTimeLabel: true);
        if(front)
          models.insert(0, model);
        else
          models.add(model);
      });
      if(haveNewMsg)
        Imclient.clearConversationUnreadStatus(widget.conversation);
    });
  }

  void loadHistoryMessage() {
    if(isLoading)
      return;

    isLoading = true;
    int? fromIndex = 0;
    if(models.isNotEmpty) {
      fromIndex = models.last.message.messageId;
    } else {
      isLoading = false;
      return;
    }
    bool noMoreLocalHistoryMsg = false;
    bool noMoreRemoteHistoryMsg = false;

    if(noMoreLocalHistoryMsg) {
      if(noMoreRemoteHistoryMsg) {
        isLoading = false;
        return;
      } else {
        fromIndex = models.last.message.messageUid;
        Imclient.getRemoteMessages(widget.conversation, fromIndex!, 20, (messages) {
          if(messages == null || messages.isEmpty) {
            noMoreRemoteHistoryMsg = true;
          }
          isLoading = false;
          _appendMessage(messages);
        }, (errorCode) {
          isLoading = false;
          noMoreRemoteHistoryMsg = true;
        });
      }
    } else {
      Imclient.getMessages(widget.conversation, fromIndex!, 20).then((
          value) {
        _appendMessage(value);
        isLoading = false;
        if(value == null || value.isEmpty)
          noMoreLocalHistoryMsg = true;
      });
    }
  }

  bool notificationFunction(Notification notification) {
    switch (notification.runtimeType) {
      case ScrollEndNotification:
        var noti = notification as ScrollEndNotification;
        if(noti.metrics.pixels >= noti.metrics.maxScrollExtent) {
          loadHistoryMessage();
        }
        break;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Message'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: NotificationListener(
              child: ListView.builder(
                reverse: true,
                itemBuilder: (BuildContext context, int index) => MessageCell(models[index]),
                itemCount: models.length,),
              onNotification: notificationFunction,
            )),
            Container(
              height: 100,
              child: Row(
                children: [
                  IconButton(icon: Icon(Icons.record_voice_over), onPressed: null),
                  Expanded(child: TextField(controller: textEditingController,onSubmitted: (text){
                    TextMessageContent txt = TextMessageContent(text);
                    Imclient.sendMessage(widget.conversation, txt, successCallback: (int messageUid, int timestamp){
                      print("scuccess");
                    }, errorCallback: (int errorCode) {
                      print("send failure!");
                    }).then((value) {
                      if(value != null) {
                        _appendMessage([value], front: true);
                      }
                      textEditingController.clear();
                    });
                  }, onChanged: (text) {
                    print(text);
                  },), ),
                  IconButton(icon: Icon(Icons.emoji_emotions), onPressed: null),
                  IconButton(icon: Icon(Icons.add_circle_outline_rounded), onPressed: null),
                  IconButton(icon: Icon(Icons.camera_enhance_rounded), onPressed: (){
                    if(widget.conversation.conversationType == ConversationType.Single) {
                      Rtckit.startSingleCall(widget.conversation.target, true);
                    } else if(widget.conversation.conversationType == ConversationType.Group) {
                      //Select participants first;
                      // List<String> participants = List();
                      // Future<List<GroupMember>> members = Imclient.getGroupMembers(widget.conversation.target);
                      // Rtckit.startMultiCall(widget.conversation.target, participants, true);
                    }
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

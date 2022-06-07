import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ichat_app/allConstants/constants.dart';
import 'package:ichat_app/allModel/message_chat.dart';
import 'package:ichat_app/allProvider/auth_provider.dart';
import 'package:ichat_app/allProvider/chat_provider.dart';
import 'package:ichat_app/allProvider/setting_provider.dart';
import 'package:ichat_app/allWidgets/loading_view.dart';
import 'package:ichat_app/main.dart';
import 'package:ichat_app/screen/full_image.dart';
import 'package:ichat_app/screen/login_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ChatPage extends StatefulWidget {
  final String peerId;
  final String peerAvatar;
  final String peerNickname;
  const ChatPage({
    Key? key,
    required this.peerId,
    required this.peerAvatar,
    required this.peerNickname,
  }) : super(key: key);

  @override
  // ignore: no_logic_in_create_state
  State createState() => ChatPageState(
        peerId: peerId,
        peerAvatar: peerAvatar,
        peerNickname: peerNickname,
      );
}

class ChatPageState extends State<ChatPage> {
  ChatPageState({
    Key? key,
    required this.peerId,
    required this.peerAvatar,
    required this.peerNickname,
  });

  String peerId;
  String peerAvatar;
  String peerNickname;
  late String currentUserId;

  List<QueryDocumentSnapshot> listMessage = List.from([]);

  int _limit = 20;
  final int _limitIncrement = 20;
  String groupChatId = "";

  File? imageFile;
  bool isLoading = false;
  bool isShowSticker = false;
  String imageUrl = "";

  final ScrollController listScrollController = ScrollController();
  final TextEditingController controller = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode focusNode = FocusNode();

  late ChatProvider chatProvider;
  late AuthProvider authProvider;

  @override
  void initState() {
    super.initState();
    chatProvider = context.read<ChatProvider>();
    authProvider = context.read<AuthProvider>();

    focusNode.addListener(onFocusChange);
    listScrollController.addListener(_scrollListener);
    readLocal();
  }

  _scrollListener() {
    if (listScrollController.offset >=
            listScrollController.position.maxScrollExtent &&
        !listScrollController.position.outOfRange) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  void onFocusChange() {
    if (focusNode.hasFocus) {
      setState(() {
        isShowSticker = false;
      });
    }
  }

  void readLocal() {
    if (authProvider.getUserFirebaseId()!.isNotEmpty) {
      currentUserId = authProvider.getUserFirebaseId()!;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false);
    }
    if (currentUserId.hashCode <= peerId.hashCode) {
      groupChatId = '$currentUserId-$peerId';
    } else {
      groupChatId = '$peerId-$currentUserId';
    }

    chatProvider.updateDataFireStore(
      FirestoreConstants.pathUserCollection,
      currentUserId,
      {FirestoreConstants.chattingWith: peerId},
    );
  }

  Future getImage() async {
    ImagePicker imagePicker = ImagePicker();
    XFile? getImage = await imagePicker.pickImage(source: ImageSource.gallery);
    if (getImage != null) {
      imageFile = File(getImage.path);
      if (imageFile != null) {
        setState(() {
          isLoading = true;
        });
        uploadFile();
      }
    }
  }

  void getStickers() {
    focusNode.unfocus();
    setState(() {
      isShowSticker = !isShowSticker;
    });
  }

  Future uploadFile() async {
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    UploadTask uploadTask = chatProvider.uploadFile(imageFile!, fileName);
    try {
      TaskSnapshot snapshot = await uploadTask;
      imageUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        isLoading = false;
        onSendMessage(imageUrl, TypeMessage.image);
      });
    } on FirebaseException catch (e) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: e.message ?? e.toString());
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: e.toString());
    }
  }

  void onSendMessage(String content, int type) {
    if (content.trim().isNotEmpty) {
      controller.clear();
      chatProvider.sendMessage(
        content.trim(),
        type,
        groupChatId,
        currentUserId,
        peerId,
      );
      listScrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      Fluttertoast.showToast(
          msg: "Nothing to send", backgroundColor: ColorConstants.greyColor);
    }
  }

  bool isLastMessageLeft(int index) {
    if ((index > 0 &&
            listMessage[index - 1].get(FirestoreConstants.idFrom) ==
                currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  bool isFirstMessageDaily(
      DocumentSnapshot? prevDocument, DocumentSnapshot? currentDocument) {
    if (prevDocument != null) {
      var message2 = MessageChat.fromdocument(prevDocument);

      print('Prev message ==> ${message2.content}');
    }
    if (currentDocument != null) {
      var message = MessageChat.fromdocument(currentDocument);
      print("cur message ==> ${message.content}");
      print("------------------------------------------------");
      if (prevDocument == null) {
        return true;
      } else {
        if (_getDate(prevDocument) == _getDate(currentDocument)) {
          return false;
        } else {
          return true;
        }
      }
    } else {
      return false;
    }
  }

  bool isLastMessageRight(int index) {
    if ((index > 0 &&
            listMessage[index - 1].get(FirestoreConstants.idFrom) !=
                currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> onBackPress() {
    if (isShowSticker) {
      setState(() {
        isShowSticker = false;
      });
    } else {
      chatProvider.updateDataFireStore(
        FirestoreConstants.pathUserCollection,
        currentUserId,
        {FirestoreConstants.chattingWith: null},
      );
      Navigator.pop(context);
    }
    return Future.value(false);
  }

  void _callPhoneNumber(String callPhoneNumber) async {
    var url = 'tel://$callPhoneNumber';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      throw "Error occured";
    }
  }

  String _getDate(DocumentSnapshot? document) {
    if (document != null) {
      MessageChat messageChat = MessageChat.fromdocument(document);
      DateTime chatTime = DateTime.fromMillisecondsSinceEpoch(
        int.parse(messageChat.timestamp),
      );
      int chatDay = chatTime.day;
      int currentDay = DateTime.now().day;
      if (currentDay == chatDay) {
        return "Today";
      } else if (currentDay - 1 == chatDay) {
        return "Yesterday";
      } else {
        return DateFormat.MEd().format(DateTime.now()).split(", ")[1];
      }
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isWhite ? Colors.white : Colors.grey,
      key: _scaffoldKey,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: ColorConstants.primaryColor,
          statusBarIconBrightness: Brightness.light,
        ),
        backgroundColor: ColorConstants.primaryColor,
        iconTheme: const IconThemeData(
          color: ColorConstants.greyColor2,
        ),
        title: Text(
          peerNickname,
          style: const TextStyle(
            color: ColorConstants.greyColor2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              SettingProvider settingProvider;
              settingProvider = context.read<SettingProvider>();
              String callPhoneNumber =
                  settingProvider.getPref(FirestoreConstants.phoneNumber) ?? "";
              _callPhoneNumber(callPhoneNumber);
            },
            icon: const Icon(
              Icons.call,
              size: 30,
              color: ColorConstants.greyColor2,
            ),
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: onBackPress,
        child: Stack(
          children: [
            Column(
              children: [
                buildListMessage(),
                isShowSticker ? buildSticker() : const SizedBox.shrink(),
                buildInput(),
              ],
            ),
            buildLoading(),
          ],
        ),
      ),
    );
  }

  Widget buildSticker() {
    return Expanded(
      child: Container(
        child: Column(
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () => onSendMessage('mimi1', TypeMessage.sticker),
                  child: Image.asset(
                    'images/mimi1.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: () => onSendMessage('mimi2', TypeMessage.sticker),
                  child: Image.asset(
                    'images/mimi2.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: () => onSendMessage('mimi3', TypeMessage.sticker),
                  child: Image.asset(
                    'images/mimi3.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => onSendMessage('mimi4', TypeMessage.sticker),
                  child: Image.asset(
                    'images/mimi4.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: () => onSendMessage('mimi5', TypeMessage.sticker),
                  child: Image.asset(
                    'images/mimi5.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: () => onSendMessage('mimi6', TypeMessage.sticker),
                  child: Image.asset(
                    'images/mimi6.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => onSendMessage('mimi7', TypeMessage.sticker),
                  child: Image.asset(
                    'images/mimi7.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: () => onSendMessage('mimi8', TypeMessage.sticker),
                  child: Image.asset(
                    'images/mimi8.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: () => onSendMessage('mimi9', TypeMessage.sticker),
                  child: Image.asset(
                    'images/mimi9.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            ),
          ],
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        ),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: ColorConstants.greyColor2,
              width: .5,
            ),
          ),
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(5),
        height: 100,
      ),
    );
  }

  Widget buildLoading() {
    return Positioned(
        child: isLoading ? const LoadingView() : const SizedBox.shrink());
  }

  Widget buildInput() {
    return Container(
      child: Row(
        children: [
          Material(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: IconButton(
                onPressed: getImage,
                icon: const Icon(
                  Icons.camera_enhance,
                ),
                color: ColorConstants.primaryColor,
              ),
            ),
            color: Colors.white,
          ),
          Material(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: IconButton(
                onPressed: getStickers,
                icon: const Icon(
                  Icons.face_retouching_natural,
                ),
                color: ColorConstants.primaryColor,
              ),
            ),
            color: Colors.white,
          ),
          Flexible(
            child: SizedBox(
              child: TextField(
                keyboardType: TextInputType.multiline,
                maxLines: null,
                onSubmitted: (value) {
                  onSendMessage(controller.text, TypeMessage.text);
                },
                style: const TextStyle(
                  color: ColorConstants.primaryColor,
                  fontSize: 15,
                ),
                controller: controller,
                decoration: const InputDecoration.collapsed(
                  hintText: "Type your message...",
                  hintStyle: TextStyle(
                    color: ColorConstants.greyColor,
                  ),
                ),
                focusNode: focusNode,
              ),
            ),
          ),
          Material(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: IconButton(
                onPressed: () =>
                    onSendMessage(controller.text, TypeMessage.text),
                icon: const Icon(
                  Icons.send,
                ),
                color: ColorConstants.primaryColor,
              ),
            ),
            color: Colors.white,
          ),
        ],
      ),
      width: double.infinity,
      height: 50,
      decoration: const BoxDecoration(
        border: Border(
            top: BorderSide(color: ColorConstants.greyColor2, width: .5)),
        color: Colors.white,
      ),
    );
  }

  Widget buildListMessage() {
    return Flexible(
      child: groupChatId.isNotEmpty
          ? StreamBuilder(
              stream: chatProvider.getStreamChat(groupChatId, _limit),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasData) {
                  listMessage.addAll(snapshot.data!.docs);
                  return ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: snapshot.data?.docs.length,
                      controller: listScrollController,
                      reverse: true,
                      itemBuilder: (context, index) {
                        return Column(
                          children: [
                            // isFirstMessageDaily(
                            //         index == 0
                            //             ? null
                            //             : snapshot.data?.docs[count - index],
                            //         snapshot.data?.docs[count - index - 1])
                            //     ? Padding(
                            //         padding: const EdgeInsets.only(
                            //           bottom: 12,
                            //           top: 5,
                            //         ),
                            //         child: Row(
                            //           children: [
                            //             const Expanded(
                            //               child: Divider(
                            //                 color: ColorConstants.primaryColor,
                            //                 thickness: 1,
                            //               ),
                            //             ),
                            //             Container(
                            //               padding: const EdgeInsets.symmetric(
                            //                   horizontal: 5),
                            //               child: Text(
                            //                 _getDate(
                            //                     snapshot.data?.docs[index]),
                            //                 style: const TextStyle(
                            //                   color:
                            //                       ColorConstants.primaryColor,
                            //                   fontSize: 14,
                            //                   fontWeight: FontWeight.w500,
                            //                 ),
                            //               ),
                            //             ),
                            //             const Expanded(
                            //               child: Divider(
                            //                 color: ColorConstants.primaryColor,
                            //                 thickness: 1,
                            //               ),
                            //             ),
                            //           ],
                            //         ),
                            //       )
                            //     : const SizedBox.shrink(),
                            buildItem(index, snapshot.data?.docs[index]),
                          ],
                        );
                      });
                } else {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ColorConstants.themeColor,
                    ),
                  );
                }
              },
            )
          : const Center(
              child: CircularProgressIndicator(
                color: ColorConstants.themeColor,
              ),
            ),
    );
  }

  Widget buildItem(int index, DocumentSnapshot? document) {
    if (document != null) {
      MessageChat messageChat = MessageChat.fromdocument(document);
      if (messageChat.idFrom == currentUserId) {
        return Row(
          children: [
            messageChat.type == TypeMessage.text
                ? Container(
                    padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                    width: messageChat.content.length > 27 ? 210 : null,
                    decoration: const BoxDecoration(
                      color: ColorConstants.greyColor2,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    margin: EdgeInsets.only(
                      bottom: isLastMessageRight(index) ? 20 : 10,
                      right: 10,
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            right: 25,
                            bottom: 12,
                          ),
                          child: Text(
                            messageChat.content,
                            style: const TextStyle(
                              color: ColorConstants.primaryColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Text(
                            DateFormat("d MMM,").add_Hm().format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    int.parse(messageChat.timestamp),
                                  ),
                                ),
                            style: const TextStyle(
                              color: ColorConstants.primaryColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : messageChat.type == TypeMessage.image
                    ? Container(
                        margin: EdgeInsets.only(
                            bottom: isLastMessageRight(index) ? 20 : 10,
                            right: 10),
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullPhotoPage(
                                  imageUrl: messageChat.content,
                                ),
                              ),
                            );
                          },
                          style: ButtonStyle(
                              padding: MaterialStateProperty.all<EdgeInsets>(
                            const EdgeInsets.all(0),
                          )),
                          child: Material(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(8),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Image.network(
                              messageChat.content,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                              loadingBuilder: (BuildContext context,
                                  Widget child,
                                  ImageChunkEvent? loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 200,
                                  height: 200,
                                  decoration: const BoxDecoration(
                                      color: ColorConstants.greyColor2,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8),
                                      )),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: ColorConstants.themeColor,
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                      null &&
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, object, stackTrace) {
                                return Material(
                                  child: Image.asset(
                                    'images/img_not_available.jpeg',
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                );
                              },
                            ),
                          ),
                        ),
                      )
                    : Container(
                        margin: EdgeInsets.only(
                            bottom: isLastMessageRight(index) ? 20 : 10,
                            right: 10),
                        child: Image.asset(
                          'images/${messageChat.content}.gif',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
          ],
          mainAxisAlignment: MainAxisAlignment.end,
        );
      } else {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              Row(
                children: [
                  // isLastMessageLeft(index)
                  //     ? Material(
                  //         borderRadius: const BorderRadius.all(
                  //           Radius.circular(10),
                  //         ),
                  //         clipBehavior: Clip.hardEdge,
                  //         child: Image.network(
                  //           peerAvatar,
                  //           width: 35,
                  //           height: 35,
                  //           fit: BoxFit.cover,
                  //           loadingBuilder: (BuildContext context, Widget child,
                  //               ImageChunkEvent? loadingProgress) {
                  //             if (loadingProgress == null) return child;
                  //             return Center(
                  //               child: CircularProgressIndicator(
                  //                 color: ColorConstants.themeColor,
                  //                 value: loadingProgress.expectedTotalBytes !=
                  //                             null &&
                  //                         loadingProgress.expectedTotalBytes !=
                  //                             null
                  //                     ? loadingProgress.cumulativeBytesLoaded /
                  //                         loadingProgress.expectedTotalBytes!
                  //                     : null,
                  //               ),
                  //             );
                  //           },
                  //           errorBuilder: (context, object, stackTrace) {
                  //             return const Icon(
                  //               Icons.account_circle,
                  //               size: 35,
                  //               color: ColorConstants.greyColor,
                  //             );
                  //           },
                  //         ),
                  //       )
                  //     : Container(width: 35),
                  messageChat.type == TypeMessage.text
                      ? Container(
                          padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                          width: messageChat.content.length > 26 ? 210 : null,
                          decoration: const BoxDecoration(
                            color: ColorConstants.primaryColor,
                            borderRadius: BorderRadius.all(
                              Radius.circular(8),
                            ),
                          ),
                          margin: const EdgeInsets.only(left: 10),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 25,
                                  bottom: 12,
                                ),
                                child: Text(
                                  messageChat.content,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Text(
                                  DateFormat("d MMM,").add_Hm().format(
                                        DateTime.fromMillisecondsSinceEpoch(
                                          int.parse(messageChat.timestamp),
                                        ),
                                      ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : messageChat.type == TypeMessage.image
                          ? Container(
                              margin: const EdgeInsets.only(left: 10),
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullPhotoPage(
                                        imageUrl: messageChat.content,
                                      ),
                                    ),
                                  );
                                },
                                style: ButtonStyle(
                                    padding:
                                        MaterialStateProperty.all<EdgeInsets>(
                                  const EdgeInsets.all(0),
                                )),
                                child: Material(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: Image.network(
                                    messageChat.content,
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (BuildContext context,
                                        Widget child,
                                        ImageChunkEvent? loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 200,
                                        height: 200,
                                        decoration: const BoxDecoration(
                                            color: ColorConstants.greyColor2,
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(8),
                                            )),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: ColorConstants.themeColor,
                                            value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null &&
                                                    loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder:
                                        (context, object, stackTrace) =>
                                            Material(
                                      child: Image.asset(
                                        'images/img_not_available.jpeg',
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      ),
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              margin: EdgeInsets.only(
                                  bottom: isLastMessageRight(index) ? 20 : 10,
                                  right: 10),
                              child: Image.asset(
                                'images/${messageChat.content}.gif',
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                ],
              ),
              // isLastMessageLeft(index)
              //     ? Container(
              //         margin:
              //             const EdgeInsets.only(left: 15, top: 5, bottom: 5),
              //         child: Text(
              //           DateFormat("dd MMM yyyy, hh:mm a").format(
              //             DateTime.fromMillisecondsSinceEpoch(
              //               int.parse(messageChat.timestamp),
              //             ),
              //           ),
              //           style: const TextStyle(
              //             color: ColorConstants.greyColor,
              //             fontSize: 12,
              //             fontStyle: FontStyle.italic,
              //           ),
              //         ),
              //       )
              //     : const SizedBox.shrink(),
            ],
            crossAxisAlignment: CrossAxisAlignment.start,
          ),
        );
      }
    } else {
      return const SizedBox.shrink();
    }
  }
}

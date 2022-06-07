import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ichat_app/Utilities/debouncer.dart';
import 'package:ichat_app/Utilities/utilities.dart';
import 'package:ichat_app/allConstants/constants.dart';
import 'package:ichat_app/allModel/message_chat.dart';
import 'package:ichat_app/allModel/popup_choices.dart';
import 'package:ichat_app/allModel/user_chat.dart';
import 'package:ichat_app/allProvider/auth_provider.dart';
import 'package:ichat_app/allProvider/chat_provider.dart';
import 'package:ichat_app/allProvider/home_provider.dart';
import 'package:ichat_app/allWidgets/loading_view.dart';
import 'package:ichat_app/screen/chat_page.dart';
import 'package:ichat_app/screen/login_page.dart';
import 'package:ichat_app/screen/new_user.dart';
import 'package:ichat_app/screen/setting_page.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final GoogleSignIn googleSignIn = GoogleSignIn();
  final ScrollController listScrollController = ScrollController();
  Debouncer searchDebouncer = Debouncer(milliseconds: 300);
  StreamController<bool> btnClearController = StreamController<bool>();
  TextEditingController searchBarController = TextEditingController();

  late String currentUserId;
  late AuthProvider authProvider;
  late HomeProvider homeProvider;
  late ChatProvider chatProvider;

  @override
  void initState() {
    super.initState();
    authProvider = context.read<AuthProvider>();
    homeProvider = context.read<HomeProvider>();
    chatProvider = context.read<ChatProvider>();

    if (authProvider.getUserFirebaseId()!.isNotEmpty) {
      currentUserId = authProvider.getUserFirebaseId()!;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false);
    }

    registerNotification();
    configureLocalnotification();
    listScrollController.addListener(scrollListener);
  }

  @override
  void dispose() {
    super.dispose();
    btnClearController.close();
  }

  void scrollListener() {
    if (listScrollController.offset >=
            listScrollController.position.maxScrollExtent &&
        !listScrollController.position.outOfRange) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  int _limit = 20;
  final int _limitIncrement = 20;
  String _textSearch = '';
  bool isLoading = false;

  List<PopupChoices> choices = [
    PopupChoices(title: 'Settings', icon: Icons.settings),
    PopupChoices(title: 'Sign out', icon: Icons.exit_to_app),
  ];

  Future<void> handleSignOut() async {
    await authProvider.handleSignOut();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    );
  }

  void onItemMenuPress(PopupChoices choice) {
    if (choice.title == 'Sign out') {
      handleSignOut();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingPage(),
        ),
      );
    }
  }

  Future<bool> onbackPress() {
    openDialog();
    return Future.value(false);
  }

  Future<void> openDialog() async {
    switch (await showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            clipBehavior: Clip.hardEdge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            contentPadding: EdgeInsets.zero,
            children: [
              Container(
                color: ColorConstants.themeColor,
                padding: const EdgeInsets.only(bottom: 10, top: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      child: const Icon(
                        Icons.exit_to_app,
                        size: 30,
                        color: Colors.white,
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                    ),
                    const Text(
                      'Exit app',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Are you sure to exit app?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, 0);
                },
                child: Row(
                  children: [
                    Container(
                      child: const Icon(
                        Icons.cancel,
                        color: ColorConstants.primaryColor,
                      ),
                      margin: const EdgeInsets.only(right: 10),
                    ),
                    const Text(
                      'Cancel',
                      style: TextStyle(
                        color: ColorConstants.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  ],
                ),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, 1);
                },
                child: Row(
                  children: [
                    Container(
                      child: const Icon(
                        Icons.check_circle,
                        color: ColorConstants.primaryColor,
                      ),
                      margin: const EdgeInsets.only(right: 10),
                    ),
                    const Text(
                      'Yes',
                      style: TextStyle(
                        color: ColorConstants.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  ],
                ),
              ),
            ],
          );
        })) {
      case 0:
        break;
      case 1:
        exit(0);
    }
  }

  void registerNotification() {
    firebaseMessaging.requestPermission();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        //show notification
        showNotification(message.notification!);
      }
      return;
    });
    firebaseMessaging.getToken().then((token) {
      if (token != null) {
        homeProvider.updateDataFireStore(
          FirestoreConstants.pathUserCollection,
          currentUserId,
          {"pushToken": token},
        );
      }
    }).catchError((error) {
      Fluttertoast.showToast(msg: error.message.toString());
    });
  }

  void configureLocalnotification() {
    AndroidInitializationSettings initializationAndroidSettings =
        AndroidInitializationSettings("app_icon");
    IOSInitializationSettings initializationIOSSettings =
        IOSInitializationSettings();
    InitializationSettings initializationSettings = InitializationSettings(
      android: initializationAndroidSettings,
      iOS: initializationIOSSettings,
    );
    localNotificationsPlugin.initialize(initializationSettings);
  }

  void showNotification(RemoteNotification remoteNotification) async {
    AndroidNotificationDetails androidNotificationDetails =
        const AndroidNotificationDetails(
      "com.example.ichat_app",
      "Just Chat",
      playSound: true,
      enableLights: true,
      enableVibration: true,
      importance: Importance.max,
      priority: Priority.high,
    );

    IOSNotificationDetails iosNotificationDetails =
        const IOSNotificationDetails();
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await localNotificationsPlugin.show(
      0,
      remoteNotification.title,
      remoteNotification.body,
      notificationDetails,
      payload: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: ColorConstants.primaryColor,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: ColorConstants.grey,
        body: WillPopScope(
          onWillPop: onbackPress,
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: ColorConstants.primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 2.0,
                      spreadRadius: 0.0,
                      offset:
                          Offset(2.0, 2.0), // shadow direction: bottom right
                    )
                  ],
                ),
                width: double.infinity,
                height: size.height * .15,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Just Chat",
                            style: TextStyle(
                              //fontFamily: "Helvetica",
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: ColorConstants.headerColor,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.search,
                                color: ColorConstants.headerColor,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              PopupMenuButton<PopupChoices>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: ColorConstants.headerColor,
                                ),
                                onSelected: onItemMenuPress,
                                color: ColorConstants.tealGreenDark,
                                elevation: 10,
                                itemBuilder: (BuildContext context) {
                                  return choices.map((PopupChoices choice) {
                                    return PopupMenuItem<PopupChoices>(
                                      value: choice,
                                      child: Row(
                                        children: [
                                          Icon(
                                            choice.icon,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            choice.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  }).toList();
                                },
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: size.height * .85,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: homeProvider.getStreamFireStore(
                              FirestoreConstants.pathUserCollection,
                              _limit,
                              _textSearch,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                if ((snapshot.data?.docs.length ?? 0) > 0) {
                                  return ListView.builder(
                                    padding: const EdgeInsets.only(
                                      top: 5,
                                      bottom: 10,
                                    ),
                                    itemCount: snapshot.data?.docs.length,
                                    itemBuilder: (context, index) => buildItem(
                                        context, snapshot.data?.docs[index]),
                                    controller: listScrollController,
                                  );
                                } else {
                                  return const Center(
                                    child: Text(
                                      'No user found...',
                                      style: TextStyle(
                                        color: ColorConstants.primaryColor,
                                        fontSize: 20,
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: ColorConstants.primaryColor,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      child: isLoading
                          ? const LoadingView()
                          : const SizedBox.shrink(),
                    ),
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NewUser(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: const BoxDecoration(
                            color: ColorConstants.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.message,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSearchBar() {
    return Container(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.search,
            color: ColorConstants.greyColor,
            size: 20,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: TextFormField(
              textInputAction: TextInputAction.search,
              controller: searchBarController,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  btnClearController.add(true);
                  setState(() {
                    _textSearch = value;
                  });
                } else {
                  btnClearController.add(false);
                  setState(() {
                    _textSearch = "";
                  });
                }
              },
              decoration: const InputDecoration.collapsed(
                hintText: 'Search here...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: ColorConstants.greyColor,
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          StreamBuilder(
            stream: btnClearController.stream,
            builder: (context, snapshot) {
              return snapshot.data == true
                  ? GestureDetector(
                      onTap: () {
                        searchBarController.clear();
                        btnClearController.add(false);
                        setState(() {
                          _textSearch = "";
                        });
                      },
                      child: const Icon(
                        Icons.clear_rounded,
                        color: ColorConstants.greyColor,
                        size: 20,
                      ),
                    )
                  : const SizedBox.shrink();
            },
          )
        ],
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: ColorConstants.greyColor2,
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    );
  }

  Widget buildItem(BuildContext context, DocumentSnapshot? document) {
    Size size = MediaQuery.of(context).size;
    String groupChatId = "";
    if (document != null) {
      UserChat userChat = UserChat.fromDocument(document);
      if (userChat.id == currentUserId) {
        return const SizedBox.shrink();
      } else {
        if (currentUserId.hashCode <= userChat.id.hashCode) {
          groupChatId = '$currentUserId-${userChat.id}';
        } else {
          groupChatId = '${userChat.id}-$currentUserId';
        }
        return StreamBuilder(
            stream: chatProvider.getStreamChat(groupChatId, 2),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.hasData) {
                var docum = snapshot.data?.docs;
                MessageChat lastMessage = MessageChat(
                  idFrom: "",
                  idTo: "",
                  timestamp: "",
                  content: "",
                  type: 0,
                );
                if (docum != null && docum.isNotEmpty) {
                  lastMessage = MessageChat.fromdocument(docum[0]);
                  return SizedBox(
                    height: size.height * .11,
                    child: InkWell(
                      onTap: () {
                        if (Utilities.isKeyboardShowing()) {
                          Utilities.closeKeyboard(context);
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              peerId: userChat.id,
                              peerAvatar: userChat.photoUrl,
                              peerNickname: userChat.nickname,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          SizedBox(
                            width: size.width * .22,
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 13),
                              child: userChat.photoUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(30)),
                                      child: Image.network(
                                        userChat.photoUrl,
                                        fit: BoxFit.cover,
                                        width: 52,
                                        height: 52,
                                        loadingBuilder: (BuildContext context,
                                            Widget child,
                                            ImageChunkEvent? loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return SizedBox(
                                            width: 52,
                                            height: 52,
                                            child: CircularProgressIndicator(
                                              color: Colors.grey,
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
                                          );
                                        },
                                        errorBuilder:
                                            (context, object, stackTrace) {
                                          return const Icon(
                                            Icons.account_circle,
                                            size: 52,
                                            color: ColorConstants.greyColor,
                                          );
                                        },
                                      ),
                                    )
                                  : const Icon(
                                      Icons.account_circle,
                                      size: 52,
                                      color: ColorConstants.greyColor,
                                    ),
                            ),
                          ),
                          Container(
                            width: size.width * .78,
                            padding: const EdgeInsets.only(right: 15),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      userChat.nickname,
                                      style: const TextStyle(
                                        fontFamily: 'Helvetica',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: ColorConstants.tealGreenDark,
                                      ),
                                    ),
                                    Text(
                                      _getDate(lastMessage.timestamp),
                                      style: const TextStyle(
                                        fontFamily: 'Helvetica',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: ColorConstants.tealGreenDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      width: size.width * .7,
                                      child: lastMessage.type ==
                                              TypeMessage.text
                                          ? Text(
                                              lastMessage.content,
                                              maxLines: 1,
                                              style: const TextStyle(
                                                fontFamily: 'Helvetica',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    ColorConstants.primaryColor,
                                              ),
                                              softWrap: true,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          : lastMessage.type ==
                                                  TypeMessage.image
                                              ? Row(
                                                  children: const [
                                                    Icon(
                                                      Icons
                                                          .insert_photo_rounded,
                                                      size: 17,
                                                    ),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      "Photo",
                                                      style: TextStyle(
                                                        fontFamily: 'Helvetica',
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: ColorConstants
                                                            .primaryColor,
                                                      ),
                                                    )
                                                  ],
                                                )
                                              : Row(
                                                  children: const [
                                                    Icon(
                                                      Icons.terminal_rounded,
                                                      size: 17,
                                                    ),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      "Sticker",
                                                      style: TextStyle(
                                                        fontFamily: 'Helvetica',
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: ColorConstants
                                                            .primaryColor,
                                                      ),
                                                    )
                                                  ],
                                                ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              } else {
                return const SizedBox.shrink();
              }
            });
      }
    } else {
      return const SizedBox.shrink();
    }
  }
}

String _getDate(String timestamp) {
  if (timestamp.isNotEmpty) {
    DateTime chatTime = DateTime.fromMillisecondsSinceEpoch(
      int.parse(timestamp),
    );
    int chatDay = chatTime.day;
    int currentDay = DateTime.now().day;
    if (currentDay == chatDay) {
      return DateFormat("hh:mm a").format(chatTime);
    } else if (currentDay - 1 == chatDay) {
      return "Yesterday";
    } else {
      return DateFormat.MEd().format(chatTime);
    }
  }
  return "";
}

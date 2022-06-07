import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ichat_app/Utilities/utilities.dart';
import 'package:ichat_app/allConstants/constants.dart';
import 'package:ichat_app/allModel/user_chat.dart';
import 'package:ichat_app/allProvider/auth_provider.dart';
import 'package:ichat_app/allProvider/home_provider.dart';
import 'package:ichat_app/allWidgets/widgets.dart';
import 'package:ichat_app/screen/chat_page.dart';
import 'package:ichat_app/screen/login_page.dart';
import 'package:provider/provider.dart';

class NewUser extends StatefulWidget {
  const NewUser({Key? key}) : super(key: key);

  @override
  State<NewUser> createState() => _NewUserState();
}

class _NewUserState extends State<NewUser> {
  final ScrollController listScrollController = ScrollController();
  StreamController<bool> btnClearController = StreamController<bool>();
  TextEditingController searchBarController = TextEditingController();

  late String currentUserId;
  late HomeProvider homeProvider;
  late AuthProvider authProvider;
  bool isLoading = false;
  String _textSearch = '';

  @override
  void initState() {
    super.initState();
    homeProvider = context.read<HomeProvider>();
    authProvider = context.read<AuthProvider>();
    if (authProvider.getUserFirebaseId()!.isNotEmpty) {
      currentUserId = authProvider.getUserFirebaseId()!;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false);
    }
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
        !listScrollController.position.outOfRange) {}
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: ColorConstants.grey,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: ColorConstants.primaryColor,
          statusBarIconBrightness: Brightness.light,
        ),
        backgroundColor: ColorConstants.primaryColor,
        iconTheme: const IconThemeData(
          color: ColorConstants.greyColor2,
        ),
        actions: [
          buildSearchBar(),
        ],
      ),
      body: SizedBox(
        height: size.height * .86,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: homeProvider.getStreamFireStore(
                      FirestoreConstants.pathUserCollection,
                      20,
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
                              context,
                              snapshot.data?.docs[index],
                            ),
                            controller: listScrollController,
                          );
                        } else {
                          return const Center(
                            child: Text(
                              'No user found...',
                              style: TextStyle(
                                fontSize: 20,
                                color: ColorConstants.primaryColor,
                              ),
                            ),
                          );
                        }
                      } else {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.grey,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              child: isLoading ? const LoadingView() : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildItem(BuildContext context, DocumentSnapshot? document) {
    Size size = MediaQuery.of(context).size;
    if (document != null) {
      UserChat userChat = UserChat.fromDocument(document);
      if (userChat.id == currentUserId) {
        return const SizedBox.shrink();
      } else {
        return Column(
          children: [
            SizedBox(
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: size.width * .22,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 13),
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
                                        if (loadingProgress == null) {
                                          return child;
                                        }
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
                          padding: const EdgeInsets.only(right: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                    const SizedBox(height: 5),
                                    Text(
                                      userChat.aboutMe,
                                      style: const TextStyle(
                                        fontFamily: 'Helvetica',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: ColorConstants.primaryColor,
                                      ),
                                      softWrap: true,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget buildSearchBar() {
    Size size = MediaQuery.of(context).size;
    return Container(
      width: size.width * .78,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                  fontSize: 14,
                  color: ColorConstants.greyColor,
                ),
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: ColorConstants.greyColor,
              ),
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
      decoration: const BoxDecoration(
        color: ColorConstants.primaryColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    );
  }
}

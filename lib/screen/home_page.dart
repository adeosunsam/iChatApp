import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ichat_app/allConstants/color_constants.dart';
import 'package:ichat_app/allModel/popup_choices.dart';
import 'package:ichat_app/allProvider/auth_provider.dart';
import 'package:ichat_app/main.dart';
import 'package:ichat_app/screen/login_page.dart';
import 'package:ichat_app/screen/setting_page.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final ScrollController listScrollController = ScrollController();

  late String currentUserId;
  late AuthProvider authProvider;

  @override
  void initState() {
    super.initState();
    authProvider = context.read<AuthProvider>();
    //homeProvider = context.read<HomeProvider>();

    if (authProvider.getUserFirebaseId()!.isNotEmpty) {
      currentUserId = authProvider.getUserFirebaseId()!;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false);
    }
    listScrollController.addListener(scrollListener);
  }

  void scrollListener() {
    print(listScrollController.offset);
    print(listScrollController.position);
    if (listScrollController.offset >=
            listScrollController.position.maxScrollExtent &&
        !listScrollController.position.outOfRange) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  int _limit = 20;
  int _limitIncrement = 20;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isWhite ? Colors.white : Colors.black,
      appBar: AppBar(
        backgroundColor: isWhite ? Colors.white : Colors.black,
        leading: IconButton(
          icon: Switch(
            value: isWhite,
            onChanged: (value) {
              setState(() {
                isWhite = value;
              });
            },
            activeColor: Colors.white,
            activeTrackColor: Colors.grey,
            inactiveThumbColor: Colors.black45,
            inactiveTrackColor: Colors.grey,
          ),
          onPressed: () {},
        ),
        actions: [
          PopupMenuButton<PopupChoices>(
            icon: const Icon(
              Icons.more_vert,
              color: Colors.grey,
            ),
            onSelected: onItemMenuPress,
            itemBuilder: (BuildContext context) {
              return choices.map((PopupChoices choice) {
                return PopupMenuItem<PopupChoices>(
                  value: choice,
                  child: Row(
                    children: [
                      Icon(
                        choice.icon,
                        color: ColorConstants.primaryColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        choice.title,
                        style: const TextStyle(
                          color: ColorConstants.primaryColor,
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
    );
  }
}

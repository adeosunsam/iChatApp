import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ichat_app/allConstants/app_constants.dart';
import 'package:ichat_app/allProvider/auth_provider.dart';
import 'package:ichat_app/allProvider/chat_provider.dart';
import 'package:ichat_app/allProvider/home_provider.dart';
import 'package:ichat_app/allProvider/setting_provider.dart';
import 'package:ichat_app/screen/splash_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool isWhite = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseStorage firebaseStorage = FirebaseStorage.instance;

  MyApp({
    Key? key,
    required this.prefs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            googleSignIn: GoogleSignIn(),
            firebaseAuth: FirebaseAuth.instance,
            firebaseFirestore: firebaseFirestore,
            prefs: prefs,
          ),
        ),
        Provider<SettingProvider>(
          create: (_) => SettingProvider(
            firebaseStorage: firebaseStorage,
            firebaseFirestore: firebaseFirestore,
            prefs: prefs,
          ),
        ),
        Provider<HomeProvider>(
          create: (_) => HomeProvider(
            firebaseFirestore: firebaseFirestore,
          ),
        ),
        Provider<ChatProvider>(
          create: (_) => ChatProvider(
            firebaseStorage: firebaseStorage,
            firebaseFirestore: firebaseFirestore,
            prefs: prefs,
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: Colors.black,
        ),
        //home: const SplashPage(),
        home: const Home(),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  double ratio = 1.0;

  @override
  void initState() {
    animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            ratio = 0.9;
          });
          animationController.repeat();
        }
      });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      body: Center(
        child: Stack(
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                  CurvedAnimation(
                      parent: animationController,
                      curve: Curves.fastLinearToSlowEaseIn)),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0.0, 0.0),
                        end: const Offset(.5, -1.0))
                    .animate(CurvedAnimation(
                  curve: Curves.fastLinearToSlowEaseIn,
                  parent: animationController,
                )),
                child: Container(
                  width: 100,
                  height: 100,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 100 * ratio,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTapDown: (d) {
                setState(() {
                  ratio = 0.9;
                });
              },
              onTapUp: (d) {
                setState(() {
                  ratio = 1.0;
                });
                animationController.forward();
              },
              child: Container(
                width: 100,
                height: 100,
                alignment: Alignment.center,
                child: Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 100 * ratio,
                ),
              ),
            )
          ],
        ),
      ),
    ));
  }
}

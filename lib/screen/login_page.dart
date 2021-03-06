import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ichat_app/allConstants/color_constants.dart';
import 'package:ichat_app/allProvider/auth_provider.dart';
import 'package:ichat_app/allWidgets/loading_view.dart';
import 'package:ichat_app/screen/home_page.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    AuthProvider authProvider = Provider.of<AuthProvider>(context);
    switch (authProvider.status) {
      case Status.authenticated:
        Fluttertoast.showToast(
          msg: 'Sign in success',
          backgroundColor: Colors.grey,
        );
        break;
      case Status.authenticateError:
        Fluttertoast.showToast(
          msg: 'Sign in fail',
          backgroundColor: Colors.grey,
        );
        break;
      case Status.authenticateCancelled:
        Fluttertoast.showToast(
          msg: 'Sign in cancelled',
          backgroundColor: Colors.grey,
        );
        break;
      default:
        break;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: ColorConstants.primaryColor,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: ColorConstants.primaryColor,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Image.asset('images/back.png'),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: GestureDetector(
                onTap: () async {
                  bool isSuccess = await authProvider.handleSignIn();
                  if (isSuccess) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomePage(),
                      ),
                    );
                  }
                },
                child: Image.asset(
                  'images/google_login.jpg',
                ),
              ),
            ),
            SizedBox(
              child: authProvider.status == Status.authenticating
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: ColorConstants.grey,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

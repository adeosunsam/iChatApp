import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ichat_app/allConstants/app_constants.dart';
import 'package:ichat_app/allConstants/color_constants.dart';
import 'package:ichat_app/allConstants/constants.dart';
import 'package:ichat_app/allModel/user_chat.dart';
import 'package:ichat_app/allProvider/setting_provider.dart';
import 'package:ichat_app/main.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isWhite ? Colors.white : Colors.black,
      appBar: AppBar(
        backgroundColor: isWhite ? Colors.white : Colors.black,
        iconTheme: const IconThemeData(
          color: ColorConstants.primaryColor,
        ),
        title: const Text(
          AppConstants.settingsTitle,
          style: TextStyle(
            color: ColorConstants.primaryColor,
          ),
        ),
        centerTitle: true,
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController? controllerNickName;
  TextEditingController? controllerAboutMe;

  String dialCodeDigits = '+00';

  String id = '';
  String nickName = '';
  String aboutMe = '';
  String photoUrl = '';
  String phoneNumber = '';

  bool isLoading = false;
  File? avaterImageFile;
  late SettingProvider settingProvider;

  final TextEditingController _controller = TextEditingController();

  final FocusNode focusNodeNickName = FocusNode();
  final FocusNode focusNodeAboutMe = FocusNode();

  @override
  void initState() {
    super.initState();
    settingProvider = context.read<SettingProvider>();
    readLocal();
    controllerAboutMe = TextEditingController(text: aboutMe);
    controllerNickName = TextEditingController(text: nickName);
  }

  void readLocal() {
    setState(() {
      id = settingProvider.getPref(FirestoreConstants.id) ?? "";
      nickName = settingProvider.getPref(FirestoreConstants.nickname) ?? "";
      aboutMe = settingProvider.getPref(FirestoreConstants.aboutMe) ?? "";
      photoUrl = settingProvider.getPref(FirestoreConstants.photoUrl) ?? "";
      phoneNumber =
          settingProvider.getPref(FirestoreConstants.phoneNumber) ?? "";
    });
  }

  Future getImage() async {
    ImagePicker imagePicker = ImagePicker();
    XFile? getImage = await imagePicker
        .pickImage(source: ImageSource.gallery)
        .catchError((e) {
      Fluttertoast.showToast(msg: e.toString());
    });
    File? image;
    if (getImage != null) {
      image = File(getImage.path);
    }
    if (image != null) {
      setState(() {
        avaterImageFile = image;
        isLoading = true;
      });
      uploadFile();
    }
  }

  Future uploadFile() async {
    String fileName = id;
    UploadTask uploadFile =
        settingProvider.uploadFile(avaterImageFile!, fileName);
    try {
      TaskSnapshot snapshot = await uploadFile;
      photoUrl = await snapshot.ref.getDownloadURL();

      UserChat updateInfo = UserChat(
        id: id,
        photoUrl: photoUrl,
        nickname: nickName,
        aboutMe: aboutMe,
        phoneNumber: phoneNumber,
      );
      settingProvider
          .updateDataFirestore(
              FirestoreConstants.pathUserCollection, id, updateInfo.toJson())
          .then((value) async {
        await settingProvider.setPref(FirestoreConstants.photoUrl, photoUrl);
        setState(() {
          isLoading = false;
        });
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

  void handleUpdateData() {
    focusNodeAboutMe.unfocus();
    focusNodeNickName.unfocus();

    setState(() {
      isLoading = true;
      if (dialCodeDigits != '+00' && _controller.text != '') {
        phoneNumber = dialCodeDigits + _controller.text.toString();
      }
    });
    UserChat updateInfo = UserChat(
      id: id,
      photoUrl: photoUrl,
      nickname: nickName,
      aboutMe: aboutMe,
      phoneNumber: phoneNumber,
    );
    settingProvider
        .updateDataFirestore(
      FirestoreConstants.pathUserCollection,
      id,
      updateInfo.toJson(),
    )
        .then((value) async {
      await settingProvider.setPref(FirestoreConstants.photoUrl, photoUrl);
      await settingProvider.setPref(FirestoreConstants.nickname, nickName);
      await settingProvider.setPref(FirestoreConstants.aboutMe, aboutMe);
      await settingProvider.setPref(
          FirestoreConstants.phoneNumber, phoneNumber);
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: 'Update Success');
    }).catchError((err) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: err.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

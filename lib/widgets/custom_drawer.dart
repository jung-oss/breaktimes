import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../core/localization/app_localizations.dart';
import '../routes/app_router.dart'; // 라우터 import
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomDrawer extends StatefulWidget {
  final int currentIndex;
  final Function(int) onItemSelected;
  final VoidCallback onSignOut;
  final Function(String) onNavigateToRoute;

  const CustomDrawer({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.onSignOut,
    required this.onNavigateToRoute,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _heartCount = 0;
  bool _hasGivenHeartToday = false;

  @override
  void initState() {
    super.initState();
    _loadHeartCount();
  }

  Future<void> _loadHeartCount() async {
    final count = await _authService.getHeartCount();
    final hasGiven = await _authService.hasGivenHeartToday();
    if (mounted) {
      setState(() {
        _heartCount = count;
        _hasGivenHeartToday = hasGiven;
      });
    }
  }

  // Get user provider from Firestore
  Future<String?> _getUserProvider(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['provider'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Provider check error: $e');
      return null;
    }
  }

  // Edit display name for Google/Kakao users
  void _editDisplayName() async {
    if (!await _canEditDisplayName()) return;

    final TextEditingController nameController = TextEditingController();
    nameController.text = _authService.currentUser?.displayName ?? '';

    final localizations = AppLocalizations.of(context);
    final isKorean = localizations.localeName.startsWith('ko');

    // Show dialog to edit name
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '이름 수정' : 'Edit Name'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: isKorean ? '이름' : 'Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: Text(localizations.cancel),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
          TextButton(
            child: Text(localizations.save),
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  // Update the user's display name
                  await _authService.currentUser!
                      .updateDisplayName(nameController.text.trim());

                  // Also update in Firestore
                  await _firestore
                      .collection('users')
                      .doc(_authService.currentUser!.uid)
                      .update({'displayName': nameController.text.trim()});

                  // Force UI update
                  setState(() {});

                  Navigator.of(ctx).pop();

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isKorean
                          ? '이름이 업데이트되었습니다.'
                          : 'Name has been updated.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  // Show error message
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isKorean
                          ? '이름 업데이트 실패: $e'
                          : 'Failed to update name: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  // Check if user can edit display name (Google or Kakao user)
  Future<bool> _canEditDisplayName() async {
    final user = _authService.currentUser;
    if (user == null) return false;

    // Check for Google provider
    for (var info in user.providerData) {
      if (info.providerId == 'google.com') {
        return true;
      }
    }

    // Check for Kakao provider in Firestore
    final provider = await _getUserProvider(user.uid);
    return provider == 'kakao';
  }

  Future<void> _pickImage() async {
    final localizations = AppLocalizations.of(context);
    try {
      final picker = ImagePicker();
      // imageQuality 매개변수를 추가하고, maxWidth와 maxHeight 설정
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // 0-100 사이의 값, 낮을수록 파일 크기 감소
        maxWidth: 1000, // 최대 너비 제한
        maxHeight: 1000, // 최대 높이 제한
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);

        // 파일 크기 확인 (3MB = 3 * 1024 * 1024 bytes)
        final fileSize = await imageFile.length();
        if (fileSize > 3 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.localeName.startsWith('ko')
                    ? '이미지 크기는 3MB 이하여야 합니다.'
                    : 'Image size must be less than 3MB.'),
              ),
            );
          }
          return;
        }

        await _authService.uploadProfileImage(imageFile);
        // 상태 갱신을 위해 setState 호출
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(localizations.localeName.startsWith('ko')
                  ? '이미지 업로드 실패: $e'
                  : 'Image upload failed: $e')),
        );
      }
    }
  }

  Future<void> _incrementHeart() async {
    if (_hasGivenHeartToday) return;
    final localizations = AppLocalizations.of(context);

    try {
      await _authService.incrementHeartCount();
      await _loadHeartCount();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/hug.gif',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 16),
                Text(
                  localizations.localeName.startsWith('ko')
                      ? '자신을 사랑하세요'
                      : 'Love Yourself',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );

        // 3초 후에 다이얼로그 닫기
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(localizations.localeName.startsWith('ko')
                  ? '하트 추가에 실패했습니다.'
                  : 'Failed to add heart.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          FutureBuilder<bool>(
              future: _canEditDisplayName(),
              builder: (context, snapshot) {
                final canEditName = snapshot.data ?? false;

                return DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Colors.deepOrangeAccent,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.appName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          FutureBuilder<String>(
                            future:
                                _authService.getCurrentUserProfileImageUrl(),
                            builder: (context, snapshot) {
                              final hasImage =
                                  snapshot.hasData && snapshot.data!.isNotEmpty;

                              return GestureDetector(
                                onTap: _pickImage,
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: hasImage
                                      ? NetworkImage(snapshot.data!)
                                      : null,
                                  child: hasImage
                                      ? null
                                      : const Icon(Icons.person,
                                          size: 30, color: Colors.grey),
                                  onBackgroundImageError: hasImage
                                      ? (_, __) => const Icon(Icons.person,
                                          size: 30, color: Colors.grey)
                                      : null,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Display name (only for Google/Kakao users)
                                if (canEditName &&
                                    _authService.currentUser?.displayName !=
                                        null)
                                  GestureDetector(
                                    onTap: _editDisplayName,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _authService
                                                    .currentUser?.displayName ??
                                                '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                // Email address for all users
                                Text(
                                  _authService.currentUser?.email ?? 'Guest',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          // 순서에 맞게 정렬된 메뉴 아이템들
          ListTile(
            leading: Image.asset(
              'assets/icons/1.png',
              width: 39,
              height: 39,
            ),
            title: Text(localizations.todayTasks),
            selected: widget.currentIndex == 0,
            onTap: () => widget.onItemSelected(0),
          ),
          ListTile(
            leading: Image.asset(
              'assets/icons/2.png',
              width: 39,
              height: 39,
            ),
            title: Text(
              localizations.localeName.startsWith('ko') ? '행복-함' : 'Happy Box',
            ),
            selected: widget.currentIndex == 1,
            onTap: () => widget.onItemSelected(1),
          ),
          ListTile(
            leading: Image.asset(
              'assets/icons/3.png',
              width: 39,
              height: 39,
            ),
            title: Text(localizations.localeName.startsWith('ko')
                ? '행복-담'
                : 'Happiness Chat'),
            selected: widget.currentIndex == 2,
            onTap: () => widget.onItemSelected(2),
          ),
          ListTile(
            leading: Image.asset(
              'assets/icons/4.png',
              width: 39,
              height: 39,
            ),
            title: Text(localizations.localeName.startsWith('ko')
                ? '행복-가게(준비중)'
                : 'Happiness Shop(Coming Soon)'),
            selected: widget.currentIndex == 3,
            onTap: () => widget.onItemSelected(3),
          ),

          ListTile(
            leading: Image.asset(
              'assets/icons/5.png',
              width: 39,
              height: 39,
            ),
            title: Text(localizations.settings),
            selected: widget.currentIndex == 4,
            onTap: () => widget.onItemSelected(4),
          ),
          ListTile(
            leading: Image.asset(
              'assets/icons/6.png',
              width: 39,
              height: 39,
            ),
            title: Text(localizations.localeName.startsWith('ko')
                ? '기획의도 & 블로그'
                : 'Planning Intent & Blog'),
            onTap: () async {
              context.pop();
              final url = Uri.parse(
                  'https://blog.naver.com/PostList.naver?blogId=2enjoybreaktime');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
          ),

          ListTile(
            leading: Image.asset(
              'assets/icons/7.png',
              width: 39,
              height: 39,
            ),
            title: Text(localizations.Homepage),
            onTap: () async {
              context.pop();
              final url = Uri.parse('https://enjoybreaktime.netlify.app');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(localizations.logout),
            onTap: () {
              context.pop();
              widget.onSignOut();
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.favorite,
              color: _hasGivenHeartToday ? Colors.red : Colors.grey,
            ),
            title: Text(localizations.localeName.startsWith('ko')
                ? '사랑하기 $_heartCount'
                : 'Love $_heartCount'),
            onTap: _incrementHeart,
            trailing: Chip(
              label: Text(
                _heartCount.toString(),
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: _hasGivenHeartToday
                  ? Colors.red.shade400
                  : Colors.grey.shade400,
              padding: const EdgeInsets.all(4),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'main_screen.dart';
import '../core/localization/app_localizations.dart';
import 'package:go_router/go_router.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        if (_passwordController.text != _confirmPasswordController.text) {
          throw AppLocalizations.of(context).confirmPassword;
        }
        await _authService.createUserWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      if (!mounted) return;

      // 로그인 성공 시 메인 화면으로 이동
      // GoRouter 사용
      context.go('/main');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // 약간의 지연 후 오류 다이얼로그 표시
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _showErrorDialog(e.toString());
          }
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    // 이메일 입력 다이얼로그 표시
    final TextEditingController emailController = TextEditingController();
    // 기존 이메일 필드에 값이 있다면 초기값으로 설정
    emailController.text = _emailController.text.trim();

    final localizations = AppLocalizations.of(context);

    // 다이얼로그 결과를 저장할 변수
    // 다이얼로그 결과를 저장할 변수
    String? inputEmail;

    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(localizations.forgotPassword),
        content: Column(
          children: [
            Text(localizations.enterEmailForPasswordReset),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: emailController,
              placeholder: localizations.email,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(localizations.cancel),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(localizations.send),
            onPressed: () {
              final email = emailController.text.trim();
              if (email.isNotEmpty && email.contains('@')) {
                inputEmail = email;
                Navigator.of(ctx).pop();
              } else {
                // 이메일 형식이 올바르지 않을 경우 에러 메시지
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.invalidEmailFormat),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );

    // 다이얼로그에서 이메일을 입력받았으면 비밀번호 재설정 메일 발송
    if (inputEmail != null) {
      try {
        setState(() {
          _isLoading = true;
        });

        await _authService.sendPasswordResetEmail(inputEmail!);

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showSuccessDialog(
            localizations.passwordResetEmailSent,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showErrorDialog(e.toString());
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    // Future.microtask를 사용하여 현재 빌드 사이클이 완료된 후 다이얼로그 표시
    Future.microtask(() {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(AppLocalizations.of(context).error),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                child: Text(AppLocalizations.of(context).confirm),
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      }
    });
  }

  void _showSuccessDialog(String message) {
    if (!mounted) return;

    // Future.microtask를 사용하여 현재 빌드 사이클이 완료된 후 다이얼로그 표시
    Future.microtask(() {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(AppLocalizations.of(context).success),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                child: Text(AppLocalizations.of(context).confirm),
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      }
    });
  }

// 구글 로그인
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signInWithGoogle();

      if (!mounted) return;

      // 로그인 성공 시 메인 화면으로 이동
      // GoRouter 사용
      context.go('/main');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // 약간의 지연 후 오류 다이얼로그 표시
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _showErrorDialog('로그인 중 오류가 발생했습니다: $e');
          }
        });
      }
    }
  }

// 카카오 로그인
  Future<void> _signInWithKakao() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signInWithKakao();

      if (!mounted) return;

      // 로그인 성공 시 메인 화면으로 이동
      // GoRouter 사용
      context.go('/main');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // 약간의 지연 후 오류 다이얼로그 표시
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _showErrorDialog('로그인 중 오류가 발생했습니다: $e');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: CupertinoColors.systemBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/welcome.jpg',
                      width: double.infinity,
                      height: 320,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? localizations.welcome
                        : localizations.createAccount,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: _emailController,
                    placeholder: localizations.email,
                    keyboardType: TextInputType.emailAddress,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(
                        CupertinoIcons.mail,
                        color: CupertinoColors.systemGrey,
                        size: 20,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _passwordController,
                    placeholder: localizations.password,
                    obscureText: _obscurePassword,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(
                        CupertinoIcons.lock,
                        color: CupertinoColors.systemGrey,
                        size: 20,
                      ),
                    ),
                    suffix: CupertinoButton(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        _obscurePassword
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        color: CupertinoColors.systemGrey,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  if (!_isLogin) ...[
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _confirmPasswordController,
                      placeholder: localizations.confirmPassword,
                      obscureText: _obscureConfirmPassword,
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(
                          CupertinoIcons.lock,
                          color: CupertinoColors.systemGrey,
                          size: 20,
                        ),
                      ),
                      suffix: CupertinoButton(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          _obscureConfirmPassword
                              ? CupertinoIcons.eye
                              : CupertinoIcons.eye_slash,
                          color: CupertinoColors.systemGrey,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirmPassword =
                              !_obscureConfirmPassword);
                        },
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const CupertinoActivityIndicator()
                  else ...[
                    CupertinoButton.filled(
                      onPressed: _submit,
                      borderRadius: BorderRadius.circular(8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _isLogin ? localizations.signIn : localizations.signUp,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton(
                      onPressed: _signInWithGoogle,
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/google_logo.png',
                            height: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            localizations.continue_with_google,
                            style: TextStyle(
                              color: CupertinoColors.black.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton(
                      onPressed: _signInWithKakao,
                      color: const Color(0xFFFEE500),
                      borderRadius: BorderRadius.circular(8),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/kakao_login_medium_narrow.png',
                            height: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            localizations.continue_with_kakao,
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isLogin) ...[
                      const SizedBox(height: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _resetPassword,
                        child: Text(
                          localizations.forgotPassword,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.systemBlue,
                          ),
                        ),
                      ),
                    ],
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _passwordController.clear();
                          _confirmPasswordController.clear();
                        });
                      },
                      child: Text(
                        _isLogin
                            ? localizations.createAccount
                            : localizations.haveAccount,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemBlue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

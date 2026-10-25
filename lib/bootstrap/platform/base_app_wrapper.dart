import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'package:newcalflix/background/update_notifications_worker.dart' as update_worker;
import 'package:newcalflix/models/account_model.dart';
import 'package:newcalflix/providers/arguments_provider.dart';
import 'package:newcalflix/providers/connectivity_provider.dart';
import 'package:newcalflix/providers/deep_link_provider.dart';
import 'package:newcalflix/providers/settings/client_settings_provider.dart';
import 'package:newcalflix/providers/shared_provider.dart';
import 'package:newcalflix/providers/update_notifications_provider.dart';
import 'package:newcalflix/providers/user_provider.dart';
import 'package:newcalflix/providers/video_player_provider.dart';
import 'package:newcalflix/routes/auto_router.dart';
import 'package:newcalflix/routes/auto_router.gr.dart';
import 'package:newcalflix/screens/login/lock_screen.dart';
import 'package:newcalflix/services/notification_service.dart';
import 'package:newcalflix/wrappers/players/native_player.dart';

typedef PlatformAppBuilder = Widget Function(
  BuildContext context,
  AutoRouter autoRouter,
);

abstract class BaseAppWrapper extends ConsumerStatefulWidget {
  const BaseAppWrapper({super.key, required this.builder});

  final PlatformAppBuilder builder;
}

abstract class BaseAppWrapperState<T extends BaseAppWrapper> extends ConsumerState<T> with WidgetsBindingObserver {
  late final AutoRouter autoRouter = AutoRouter(ref: ref);

  DateTime _lastPaused = DateTime.now();
  bool _hidden = false;

  StreamSubscription<String?>? _notificationSub;
  StreamSubscription<Uri>? _appLinkSub;
  bool get enableNotifications => true;

  bool get enableAppLinks => true;

  late final DeepLinkNotifier _deepLinks = ref.read(deepLinkProvider.notifier);
  bool _platformReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deepLinks.attach(autoRouter, ref);
    _initializeAppLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(sharedUtilityProvider).loadSettings();
      await platformInit();
      _platformReady = true;
      await _initializeNotifications();
    });
  }

  Future<void> platformInit() async {}

  Future<void> onAppLinkReceived() async {}

  void _initializeAppLinks() {
    if (!enableAppLinks) return;
    try {
      _appLinkSub = AppLinks().uriLinkStream.listen(
        (uri) {
          if (_platformReady) onAppLinkReceived();
          _deepLinks.handle(uri);
        },
        onError: (Object e) => log('App link error: $e'),
      );
      final launchLink = ref.read(argumentsStateProvider).launchLink;
      if (!kIsWeb && Platform.isLinux && launchLink != null) {
        _deepLinks.handleLink(launchLink);
      }
    } catch (e) {
      log('Failed to initialize app links: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    if (!enableNotifications) return;

    if (ref.read(argumentsStateProvider).skipNotifications) return;

    await NotificationService.init();

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Workmanager().initialize(update_worker.callbackDispatcher);
      } catch (e) {
        log('Failed to initialize Workmanager for background tasks: $e');
      }
    }

    _notificationSub = NotificationService.notificationTapStream.listen(_deepLinks.handleLink);

    NotificationService.getInitialNotificationPayload().then(_deepLinks.handleLink);

    try {
      await ref.read(updateNotificationsProvider).registerBackgroundTask();
    } catch (e) {
      log('Failed to register background task for update notifications: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ignoreLifeCycle = ref.read(lockScreenActiveProvider) ||
        ref.read(userProvider) == null ||
        ref.read(videoPlayerProvider).lastState?.playing == true ||
        nativeActivityStarted;

    if (ignoreLifeCycle) {
      _lastPaused = DateTime.now();
      _hidden = false;
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        ref.read(connectivityStatusProvider.notifier).checkConnectivity();
        if (_hidden) {
          _enableTimeOut();
          _hidden = false;
        }
        break;
      case AppLifecycleState.paused:
        _hidden = true;
        _lastPaused = DateTime.now();
        break;
      default:
        break;
    }
  }

  Future<void> _enableTimeOut() async {
    final timeOut = ref.read(clientSettingsProvider).timeOut;
    if (timeOut == null) return;

    final difference = DateTime.now().difference(_lastPaused);
    final lockMethod = ref.read(userProvider.select((value) => value?.authMethod));
    final shouldLock = Authentication.secureOptions.contains(lockMethod);

    if (difference > timeOut && shouldLock) {
      _lastPaused = DateTime.now();
      autoRouter.push(const LockRoute());
    }
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _appLinkSub?.cancel();
    _deepLinks.detach(autoRouter);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      autoRouter,
    );
  }
}


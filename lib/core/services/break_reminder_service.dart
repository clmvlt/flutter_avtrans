import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../utils/time_format.dart';

/// Rappel de pause : une notification locale programmée auprès du système,
/// qui s'affiche même app fermée après [threshold] de travail sans pause.
///
/// Une seule notification à la fois (id fixe) : chaque programmation remplace
/// la précédente. Disponible sur Android et iOS ; ailleurs, les appels sont
/// sans effet (le message de la page Pointage reste affiché). Jamais
/// bloquant : une erreur du plugin est ignorée.
class BreakReminderService {
  BreakReminderService({FlutterLocalNotificationsPlugin? plugin, bool? enabled})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
      _enabled = enabled ?? _isSupportedPlatform;

  /// Travail continu au-delà duquel une pause est demandée (6 h
  /// consécutives au plus pour le personnel roulant).
  static const Duration threshold = Duration(hours: 6);

  static const int _notificationId = 6001;
  static const String _channelId = 'break_reminder';

  static bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _enabled;

  Future<bool>? _ready;

  /// Heure de la notification programmée (`null` = aucune) : évite de
  /// reprogrammer à l'identique à chaque rafraîchissement.
  DateTime? _scheduledAt;

  /// Un rappel peut être en attente (programmé lors d'un lancement
  /// précédent) : la première annulation passe toujours.
  bool _maybePending = true;

  Future<bool> _ensureReady() => _ready ??= _init();

  Future<bool> _init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Les permissions sont demandées au démarrage d'un service, pas au
          // lancement de l'app.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('BreakReminderService: init impossible ($e)');
      return false;
    }
  }

  /// Demande l'autorisation d'afficher des notifications (Android 13+, iOS).
  /// Sans effet si elle est déjà accordée ou définitivement refusée.
  Future<void> requestPermission() async {
    if (!_enabled || !await _ensureReady()) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true);
      // Une programmation faite avant l'accord a pu être ignorée par iOS.
      _scheduledAt = null;
    } catch (e) {
      debugPrint('BreakReminderService: permission impossible ($e)');
    }
  }

  /// Programme le rappel à [at] ; une heure passée annule le rappel (le
  /// message de la page Pointage prend le relais).
  Future<void> scheduleAt(DateTime at) async {
    if (!at.isAfter(DateTime.now())) return cancel();
    if (!_enabled || _scheduledAt == at || !await _ensureReady()) return;
    final label = TimeFormat.durationShort(threshold);
    try {
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: 'Pense à ta pause',
        body: 'Tu travailles depuis $label sans pause. Prends une pause !',
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Rappels de pause',
            channelDescription: 'Rappel après 6h de travail sans pause',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Pas d'alarme exacte (permission spéciale) : quelques minutes de
        // décalage possibles en veille, acceptable pour un rappel.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      _scheduledAt = at;
      _maybePending = true;
    } catch (e) {
      debugPrint('BreakReminderService: programmation impossible ($e)');
    }
  }

  /// Annule le rappel programmé (pause, fin de service, déconnexion).
  Future<void> cancel() async {
    if (!_enabled || !_maybePending || !await _ensureReady()) return;
    try {
      await _plugin.cancel(id: _notificationId);
      _scheduledAt = null;
      _maybePending = false;
    } catch (e) {
      debugPrint('BreakReminderService: annulation impossible ($e)');
    }
  }
}

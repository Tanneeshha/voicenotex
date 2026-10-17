import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:audio_session/audio_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Accurate speech lifecycle status states for UI and controllers.
enum SpeechStatus {
  idle,
  listening,
  paused,
  restarting,
  networkError,
  permissionDenied,
  error,
}

/// A production-grade, highly resilient Speech Service for VoiceNoteX.
///
/// Universal Zero-Loss Architecture:
/// - Handles both Android (utterance-based / segmented) and Web/iOS (cumulative) speech streams
/// - Prevents previous transcription from vanishing when speech recognizer fills an utterance or restarts
/// - Prefix deduplication prevents repeated phrases across intermediate finalResults
/// - Zero-latency session transitions for 45-60+ min continuous lectures
/// - Network resilience with automatic recovery
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speech = SpeechToText();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<AudioInterruptionEvent>? _audioInterruptionSubscription;

  SpeechStatus _status = SpeechStatus.idle;
  String _lastErrorMessage = "";

  // ── Stream Controllers for Reactive UI ──────────────────────
  final StreamController<SpeechStatus> _statusController =
      StreamController<SpeechStatus>.broadcast();
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();

  Stream<SpeechStatus> get statusStream => _statusController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  SpeechStatus get status => _status;
  String get errorMessage => _lastErrorMessage;
  bool get isListening => _status == SpeechStatus.listening;
  bool get isPaused => _status == SpeechStatus.paused;
  bool get isAvailable => _speech.isAvailable;

  // ── Universal Transcript Model ──────────────────────────────
  // _accumulatedTranscript: All finalized text across utterances & sessions
  String _accumulatedTranscript = "";
  // _currentUtterance: In-flight, unfinalized partial words of active phrase
  String _currentUtterance = "";
  // _sessionCommitted: Text already committed from the current listen session.
  // Engines that report cumulative text (Web/iOS), and late final results that
  // arrive after a pause/restart commit, repeat this prefix — it gets stripped.
  String _sessionCommitted = "";

  String get fullTranscript {
    final acc = _accumulatedTranscript.trim();
    final cur = _currentUtterance.trim();
    if (acc.isEmpty) return cur;
    if (cur.isEmpty) return acc;
    return "$acc $cur";
  }

  // ── Control Flags & Concurrency Guards ──────────────────────
  bool _shouldListen = false;
  bool _isManuallyPaused = false;
  bool _isRestarting = false;
  bool _isNetworkOffline = false;
  bool _isInitialized = false;
  String _currentLocale = 'en_US';

  Timer? _restartDebounceTimer;
  Timer? _watchdogTimer;

  // ── Initialize Service ──────────────────────────────────────
  Future<bool> init() async {
    if (_isInitialized) return true;

    final hasPerm = await requestMicrophonePermission();
    if (!hasPerm) {
      _updateStatus(SpeechStatus.permissionDenied);
      return false;
    }

    _setupConnectivityListener();

    try {
      _isInitialized = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: false,
      );

      if (!_isInitialized) {
        _lastErrorMessage = "Speech recognition is not supported on this device.";
        _updateStatus(SpeechStatus.error);
        return false;
      }
    } catch (e) {
      debugPrint("SpeechService init error: $e");
      _lastErrorMessage = e.toString();
      _updateStatus(SpeechStatus.error);
      return false;
    }

    return _isInitialized;
  }

  // ── Permission Handling ─────────────────────────────────────
  Future<bool> requestMicrophonePermission() async {
    try {
      var permStatus = await Permission.microphone.status;
      if (permStatus.isGranted) return true;

      permStatus = await Permission.microphone.request();
      if (permStatus.isGranted) return true;

      if (permStatus.isPermanentlyDenied) {
        _lastErrorMessage = "Microphone permission is permanently denied. Please enable it in Settings.";
        _updateStatus(SpeechStatus.permissionDenied);
      } else {
        _lastErrorMessage = "Microphone permission denied.";
        _updateStatus(SpeechStatus.permissionDenied);
      }
      return false;
    } catch (e) {
      debugPrint("Permission check error: $e");
      return false;
    }
  }

  // ── Network Connectivity Listener ───────────────────────────
  void _setupConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.every((r) => r == ConnectivityResult.none);
      if (isOffline) {
        if (!_isNetworkOffline && _shouldListen && !_isManuallyPaused) {
          _handleNetworkInterruption();
        }
      } else {
        if (_isNetworkOffline) {
          _isNetworkOffline = false;
          if (_shouldListen && !_isManuallyPaused) {
            _scheduleSafeRestart(reason: "Network connection restored", delayMs: 200);
          }
        }
      }
    });
  }

  void _handleNetworkInterruption() {
    _isNetworkOffline = true;
    commitActiveUtterance();
    _notifyTranscriptChanged();
    _updateStatus(SpeechStatus.networkError);
    try {
      _speech.stop();
    } catch (_) {}
  }

  // ── Audio Session Configuration ─────────────────────────────
  Future<void> configureAudioSession(bool enableNoiseCancel) async {
    if (kIsWeb) return;

    try {
      final session = await AudioSession.instance;

      if (enableNoiseCancel) {
        await session.configure(
          AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
            avAudioSessionCategoryOptions:
                AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.defaultToSpeaker,
            avAudioSessionMode: AVAudioSessionMode.voiceChat,
            androidAudioAttributes: const AndroidAudioAttributes(
              contentType: AndroidAudioContentType.speech,
              usage: AndroidAudioUsage.voiceCommunication,
            ),
            androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
          ),
        );
      } else {
        await session.configure(const AudioSessionConfiguration.speech());
      }

      _audioInterruptionSubscription?.cancel();
      _audioInterruptionSubscription =
          session.interruptionEventStream.listen((event) {
        if (event.begin) {
          if (_shouldListen && !_isManuallyPaused) {
            commitActiveUtterance();
            _notifyTranscriptChanged();
            pauseListening();
          }
        } else {
          if (event.type == AudioInterruptionType.pause && _shouldListen) {
            resumeListening();
          }
        }
      });
    } catch (e) {
      debugPrint("AudioSession error: $e");
    }
  }

  // ── Start Listening (New or Continue) ───────────────────────
  Future<bool> startListening({
    String? initialText,
    String locale = 'en_US',
  }) async {
    final ready = await init();
    if (!ready) return false;

    _currentLocale = locale;
    _shouldListen = true;
    _isManuallyPaused = false;
    _isNetworkOffline = false;

    if (initialText != null) {
      _accumulatedTranscript = initialText.trim();
    }
    _currentUtterance = "";
    _notifyTranscriptChanged();

    _startWatchdog();
    return await _startListeningInternal();
  }

  Future<bool> _startListeningInternal() async {
    if (!_speech.isAvailable) {
      final ok = await init();
      if (!ok) return false;
    }

    if (_speech.isListening) {
      try {
        await _speech.stop();
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {}
    }

    try {
      _sessionCommitted = "";
      _updateStatus(SpeechStatus.listening);

      await _speech.listen(
        onResult: _handleSpeechResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          pauseFor: const Duration(seconds: 120),
          listenFor: const Duration(hours: 2),
          localeId: _currentLocale,
        ),
      );
      return true;
    } catch (e) {
      debugPrint("Speech listen error: $e");
      if (_shouldListen && !_isManuallyPaused && !_isNetworkOffline) {
        _scheduleSafeRestart(reason: "Exception on listen", delayMs: 150);
      }
      return false;
    }
  }

  // ── Universal Result Handler ────────────────────────────────
  void _handleSpeechResult(SpeechRecognitionResult result) {
    String words = result.recognizedWords.trim();
    if (words.isEmpty) return;

    // Strip text this session already committed (cumulative engines, or a late
    // final result delivered after pause/restart already committed the partial).
    final committed = _sessionCommitted.toLowerCase();
    if (committed.isNotEmpty) {
      final lower = words.toLowerCase();
      if (lower.startsWith(committed)) {
        words = words.substring(committed.length).trim();
      } else if (committed.startsWith(lower)) {
        words = "";
      }
    }

    _currentUtterance = words;

    // When an utterance is finalized by Android/Web, commit it to accumulated transcript immediately!
    // This prevents the previous text from vanishing when the next utterance arrives.
    if (result.finalResult) {
      commitActiveUtterance();
    }

    _notifyTranscriptChanged();
  }

  // ── Pause & Resume ──────────────────────────────────────────
  Future<void> pauseListening() async {
    _shouldListen = false;
    _isManuallyPaused = true;
    _restartDebounceTimer?.cancel();
    _stopWatchdog();

    commitActiveUtterance();
    _notifyTranscriptChanged();
    _updateStatus(SpeechStatus.paused);

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
  }

  Future<void> resumeListening() async {
    _shouldListen = true;
    _isManuallyPaused = false;
    _isNetworkOffline = false;

    _startWatchdog();
    await _startListeningInternal();
  }

  // ── Stop & Reset ───────────────────────────────────────────
  Future<void> stopListening() async {
    _shouldListen = false;
    _isManuallyPaused = true;
    _restartDebounceTimer?.cancel();
    _stopWatchdog();

    commitActiveUtterance();
    _notifyTranscriptChanged();
    _updateStatus(SpeechStatus.idle);

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
  }

  // ── Status & Error Handlers ─────────────────────────────────
  void _handleStatus(String status) {
    debugPrint("Speech status: $status (shouldListen: $_shouldListen, paused: $_isManuallyPaused)");
    if (_isManuallyPaused || !_shouldListen) return;

    if (status == "done" || status == "notListening") {
      // Near zero-latency restart when Android finishes its session window (~60-80s)
      _scheduleSafeRestart(reason: "Status $status", delayMs: 50);
    } else if (status == "listening") {
      _updateStatus(SpeechStatus.listening);
    }
  }

  void _handleError(SpeechRecognitionError error) {
    debugPrint("Speech error: ${error.errorMsg} (permanent: ${error.permanent})");
    if (_isManuallyPaused || !_shouldListen) return;

    final msg = error.errorMsg.toLowerCase();
    _lastErrorMessage = error.errorMsg;

    if (msg.contains("network")) {
      _handleNetworkInterruption();
    } else if (msg.contains("busy")) {
      _scheduleSafeRestart(reason: "Engine busy", delayMs: 300);
    } else if (msg.contains("speech_timeout") || msg.contains("no_match")) {
      _scheduleSafeRestart(reason: "Silence timeout", delayMs: 50);
    } else if (msg.contains("permission")) {
      _updateStatus(SpeechStatus.permissionDenied);
    } else {
      _scheduleSafeRestart(reason: "Error: $msg", delayMs: 150);
    }
  }

  // ── Safe Zero-Latency Auto-Restart ──────────────────────────
  void _scheduleSafeRestart({String reason = "", int delayMs = 50}) {
    if (!_shouldListen || _isManuallyPaused || _isNetworkOffline) return;
    if (_isRestarting) return;

    _restartDebounceTimer?.cancel();
    _restartDebounceTimer = Timer(Duration(milliseconds: delayMs), () async {
      await _performSafeRestart(reason);
    });
  }

  Future<void> _performSafeRestart(String reason) async {
    if (!_shouldListen || _isManuallyPaused || _isNetworkOffline || _isRestarting) {
      return;
    }

    _isRestarting = true;
    _updateStatus(SpeechStatus.restarting);

    try {
      // 1. Commit active partial words before recycling session
      commitActiveUtterance();
      _notifyTranscriptChanged();

      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (e) {
      debugPrint("Restart cleanup error: $e");
    }

    // Minimal hardware re-binding delay (<80ms)
    await Future.delayed(const Duration(milliseconds: 60));

    _isRestarting = false;

    if (_shouldListen && !_isManuallyPaused && !_isNetworkOffline) {
      await _startListeningInternal();
    } else if (_isManuallyPaused) {
      _updateStatus(SpeechStatus.paused);
    }
  }

  // ── Watchdog to keep long sessions alive ───────────────────
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_shouldListen && !_isManuallyPaused && !_isNetworkOffline && !_isRestarting) {
        if (!_speech.isListening) {
          debugPrint("Watchdog: Engine inactive while listening; triggering immediate restart...");
          _scheduleSafeRestart(reason: "Watchdog keep-alive", delayMs: 50);
        }
      }
    });
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  // ── Zero-Loss Buffer Manipulations ──────────────────────────
  void commitActiveUtterance() {
    final cur = _currentUtterance.trim();
    if (cur.isNotEmpty) {
      if (_accumulatedTranscript.trim().isEmpty) {
        _accumulatedTranscript = cur;
      } else {
        _accumulatedTranscript = "${_accumulatedTranscript.trim()} $cur";
      }
      _sessionCommitted =
          _sessionCommitted.isEmpty ? cur : "$_sessionCommitted $cur";
      _currentUtterance = "";
    }
  }

  void setAccumulatedText(String text) {
    _accumulatedTranscript = text.trim();
    _currentUtterance = "";
    _notifyTranscriptChanged();
  }

  void clearTranscript() {
    _accumulatedTranscript = "";
    _currentUtterance = "";
    _notifyTranscriptChanged();
  }

  // ── State Broadcasts ────────────────────────────────────────
  void _updateStatus(SpeechStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      if (!_statusController.isClosed) {
        _statusController.add(_status);
      }
    }
  }

  void _notifyTranscriptChanged() {
    if (!_transcriptController.isClosed) {
      _transcriptController.add(fullTranscript);
    }
  }

  // ── Dispose ────────────────────────────────────────────────
  void dispose() {
    _restartDebounceTimer?.cancel();
    _stopWatchdog();
    _connectivitySubscription?.cancel();
    _audioInterruptionSubscription?.cancel();
    _statusController.close();
    _transcriptController.close();
  }
}

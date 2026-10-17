import 'dart:async';
import 'package:flutter/material.dart';
import '../../home/screens/ai_screen.dart';
import '../services/speech_service.dart';
import '../services/lecture_draft_service.dart';
import '../services/whisper_recorder_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/style_service.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../widgets/speech_text_area.dart';
import '../widgets/speech_control_panel.dart';

class SpeechScreen extends StatefulWidget {
  final String? lectureTitle;
  final String? courseCode;
  final String? instructor;

  const SpeechScreen({
    super.key,
    this.lectureTitle,
    this.courseCode,
    this.instructor,
  });

  @override
  State<SpeechScreen> createState() => _SpeechScreenState();
}

class _SpeechScreenState extends State<SpeechScreen> with WidgetsBindingObserver {
  final SpeechService _speechService = SpeechService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<SpeechStatus>? _statusSubscription;
  StreamSubscription<String>? _transcriptSubscription;

  SpeechStatus _currentStatus = SpeechStatus.idle;
  bool _isNoiseCancelEnabled = true;

  // ── Whisper Mode (record audio, transcribe on pause via Deepgram Whisper) ──
  final WhisperRecorderService _whisperRecorder = WhisperRecorderService();
  bool _useWhisper = true;
  bool _isTranscribing = false;

  // ── Duration Timer & Autosave ───────────────────────────────
  Timer? _durationTimer;
  Timer? _autosaveTimer;
  int _durationSeconds = 0;
  bool _isAutoScrolling = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _setupAudioSession();
    _subscribeToSpeechService();
    _checkForExistingDraft();
    _setupAutosaveTimer();

    _textController.addListener(_onTextChanged);
    _scrollController.addListener(_onScrollChanged);
  }

  Future<void> _setupAudioSession() async {
    await _speechService.configureAudioSession(_isNoiseCancelEnabled);
  }

  void _subscribeToSpeechService() {
    _statusSubscription = _speechService.statusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _currentStatus = status;
      });

      if (status == SpeechStatus.listening) {
        _startDurationTimer();
      } else if (status == SpeechStatus.paused || status == SpeechStatus.idle) {
        _pauseDurationTimer();
        _saveDraftCheckpoint();
      } else if (status == SpeechStatus.permissionDenied) {
        _showPermissionDialog();
      }
    });

    _transcriptSubscription = _speechService.transcriptStream.listen((transcript) {
      if (!mounted) return;
      if (_textController.text != transcript) {
        _textController.value = TextEditingValue(
          text: transcript,
          selection: TextSelection.collapsed(offset: transcript.length),
        );
        _maybeScrollToBottom();
      }
    });
  }

  Future<void> _checkForExistingDraft() async {
    final draft = await LectureDraftService.loadDraft();
    if (draft != null && draft.transcript.trim().isNotEmpty && mounted) {
      // If a previous uncommitted draft exists, ask or restore
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Restored unsaved draft: ${draft.title}"),
          action: SnackBarAction(
            label: "DISCARD",
            textColor: Colors.amber,
            onPressed: () async {
              await LectureDraftService.clearDraft();
              setState(() {
                _textController.clear();
                _speechService.clearTranscript();
                _durationSeconds = 0;
              });
            },
          ),
          backgroundColor: const Color(0xFF1E3A8A),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _textController.text = draft.transcript;
        _durationSeconds = draft.durationSeconds;
        _speechService.setAccumulatedText(draft.transcript);
      });
    }
  }

  void _setupAutosaveTimer() {
    _autosaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_currentStatus == SpeechStatus.listening || _textController.text.isNotEmpty) {
        _saveDraftCheckpoint();
      }
    });
  }

  void _saveDraftCheckpoint() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    LectureDraftService.saveDraft(
      id: "lecture_${widget.lectureTitle ?? 'untitled'}",
      title: widget.lectureTitle ?? "Untitled Lecture",
      courseCode: widget.courseCode,
      instructor: widget.instructor,
      transcript: text,
      durationSeconds: _durationSeconds,
    );
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _currentStatus == SpeechStatus.listening) {
        setState(() {
          _durationSeconds++;
        });
      }
    });
  }

  void _pauseDurationTimer() {
    _durationTimer?.cancel();
  }

  void _onTextChanged() {
    // If user edited text in the text field while paused or recording
    if (_speechService.fullTranscript != _textController.text) {
      _speechService.setAccumulatedText(_textController.text);
    }
    if (mounted) setState(() {});
  }

  void _onScrollChanged() {
    if (_scrollController.hasClients) {
      final isAtBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 40;
      _isAutoScrolling = isAtBottom;
    }
  }

  void _maybeScrollToBottom() {
    if (_isAutoScrolling && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // ── App Lifecycle (Handles phone calls & backgrounding) ──────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveDraftCheckpoint();
    } else if (state == AppLifecycleState.resumed) {
      _speechService.configureAudioSession(_isNoiseCancelEnabled);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDraftCheckpoint();

    _durationTimer?.cancel();
    _autosaveTimer?.cancel();
    _statusSubscription?.cancel();
    _transcriptSubscription?.cancel();

    _textController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScrollChanged);

    _textController.dispose();
    _scrollController.dispose();

    _speechService.stopListening();
    _whisperRecorder.dispose();
    super.dispose();
  }

  // ── User Actions ────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (_useWhisper) {
      await _toggleWhisperRecording();
      return;
    }
    if (_currentStatus == SpeechStatus.listening) {
      await _speechService.pauseListening();
    } else if (_currentStatus == SpeechStatus.paused) {
      await _speechService.resumeListening();
    } else {
      // Idle / Initial start
      final currentText = _textController.text.trim();
      await _speechService.startListening(
        initialText: currentText.isNotEmpty ? currentText : null,
      );
    }
  }

  Future<void> _toggleWhisperRecording() async {
    if (_isTranscribing) return;

    if (_whisperRecorder.isRecording) {
      await _finishWhisperClip();
      return;
    }

    final started = await _whisperRecorder.start(noiseSuppress: _isNoiseCancelEnabled);
    if (!mounted) return;
    if (!started) {
      _showPermissionDialog();
      return;
    }
    setState(() {
      _currentStatus = SpeechStatus.listening;
    });
    _startDurationTimer();
  }

  /// Stops the current Whisper clip and appends its transcript to the text area.
  Future<void> _finishWhisperClip() async {
    _pauseDurationTimer();
    setState(() {
      _isTranscribing = true;
      _currentStatus = SpeechStatus.paused;
    });

    final res = await _whisperRecorder.stopAndTranscribe();
    if (!mounted) return;
    setState(() {
      _isTranscribing = false;
    });

    if (res["success"] == true) {
      final transcript = res["transcript"] as String;
      if (transcript.isEmpty) {
        CustomSnackBar.show(context, "No speech detected in the recording", isError: true);
        return;
      }
      final current = _textController.text.trim();
      _textController.text = current.isEmpty ? transcript : "$current\n\n$transcript";
      _maybeScrollToBottom();
      _saveDraftCheckpoint();
    } else {
      CustomSnackBar.show(context, res["error"] ?? "Transcription failed", isError: true);
    }
  }

  void _toggleTranscriptionMode() {
    setState(() {
      _useWhisper = !_useWhisper;
    });
    CustomSnackBar.show(
      context,
      _useWhisper
          ? "Whisper mode: accurate text appears when you pause"
          : "Live mode: text appears as you speak",
    );
  }

  Future<void> _toggleNoiseCancellation() async {
    setState(() {
      _isNoiseCancelEnabled = !_isNoiseCancelEnabled;
    });
    await _speechService.configureAudioSession(_isNoiseCancelEnabled);

    if (!mounted) return;
    CustomSnackBar.show(
      context,
      _isNoiseCancelEnabled
          ? "Noise Cancellation Enabled"
          : "Noise Cancellation Disabled",
    );
  }

  void _handleRetry() {
    final hasContent = _textController.text.trim().isNotEmpty;
    if (!hasContent) {
      _resetSession();
      return;
    }

    // Protection dialog so students don't accidentally wipe long lectures
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Lecture Transcript?"),
        content: const Text(
          "Are you sure you want to clear the entire transcription? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _resetSession();
            },
            child: const Text("CLEAR ALL", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSession() async {
    await _speechService.stopListening();
    await _whisperRecorder.cancel();
    await LectureDraftService.clearDraft();
    setState(() {
      _textController.clear();
      _speechService.clearTranscript();
      _durationSeconds = 0;
      _currentStatus = SpeechStatus.idle;
    });
  }

  Future<void> _handleProceed() async {
    if (_isTranscribing) return;
    if (_whisperRecorder.isRecording) {
      await _finishWhisperClip();
      if (!mounted) return;
    }

    final transcript = _textController.text.trim();
    if (transcript.isEmpty) {
      CustomSnackBar.show(context, "Cannot proceed with empty transcript", isError: true);
      return;
    }

    await _speechService.pauseListening();
    _saveDraftCheckpoint();

    final email = StyleService.currentUserEmail;
    if (email != null) {
      final res = await ApiService.saveLecture(
        email: email,
        title: widget.lectureTitle ?? "Untitled Lecture",
        courseCode: widget.courseCode,
        instructor: widget.instructor,
        transcript: transcript,
      );

      if (res["success"] == true) {
        // Clear local draft upon confirmed server save
        await LectureDraftService.clearDraft();

        final lectureId = res["data"]?["lecture_id"]?.toString();
        if (!mounted) return;
        CustomSnackBar.show(context, "Lecture saved successfully!");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AiAssistantScreen(
              initialPrompt: transcript,
              lectureId: lectureId,
              persistInitialResponseToLecture: true,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        CustomSnackBar.show(
          context,
          res["error"] ?? "Failed to save lecture to server",
          isError: true,
        );
      }
    } else {
      await LectureDraftService.clearDraft();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AiAssistantScreen(initialPrompt: transcript),
        ),
      );
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Microphone Access Required"),
        content: const Text(
          "VoiceNoteX requires microphone access to transcribe your lectures. Please grant microphone permission in device settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _speechService.requestMicrophonePermission();
            },
            child: const Text("GRANT PERMISSION"),
          ),
        ],
      ),
    );
  }

  int get _wordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _textController.text.trim().isNotEmpty;
    final showActionButtons = hasText && _currentStatus != SpeechStatus.listening;
    final isActivelyRecording = _currentStatus == SpeechStatus.listening || _currentStatus == SpeechStatus.restarting;

    return PopScope(
      canPop: !isActivelyRecording,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Recording in Progress"),
            content: const Text(
              "Your lecture is currently recording. Do you want to pause and leave? Your transcript will be safely saved as a draft.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("STAY"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("PAUSE & LEAVE", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (shouldLeave == true && context.mounted) {
          if (_whisperRecorder.isRecording) await _finishWhisperClip();
          await _speechService.pauseListening();
          _saveDraftCheckpoint();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC), // Clean off-white canvas
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Column(
            children: [
              Text(
                widget.lectureTitle ?? "Voice Assistant",
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (widget.courseCode != null || widget.instructor != null)
                Text(
                  [
                    if (widget.courseCode != null) widget.courseCode,
                    if (widget.instructor != null) widget.instructor,
                  ].join(" • "),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          actions: [
            IconButton(
              tooltip: _useWhisper
                  ? "Whisper mode (accurate, text after pause)"
                  : "Live mode (instant text)",
              icon: Icon(
                _useWhisper ? Icons.graphic_eq_rounded : Icons.bolt_rounded,
                color: const Color(0xFF1E3A8A),
              ),
              onPressed: isActivelyRecording || _isTranscribing
                  ? null
                  : _toggleTranscriptionMode,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SpeechTextArea(
                  textController: _textController,
                  scrollController: _scrollController,
                  isListening: _currentStatus == SpeechStatus.listening,
                ),
              ),
              if (_isTranscribing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    children: [
                      LinearProgressIndicator(color: Color(0xFF1E3A8A)),
                      SizedBox(height: 6),
                      Text(
                        "Transcribing with Whisper…",
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              SpeechControlPanel(
                status: _currentStatus,
                durationSeconds: _durationSeconds,
                wordCount: _wordCount,
                isNoiseCancelEnabled: _isNoiseCancelEnabled,
                showActionButtons: showActionButtons,
                onToggleListening: _toggleListening,
                onToggleNoiseCancel: _toggleNoiseCancellation,
                onRetry: _handleRetry,
                onProceed: _handleProceed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

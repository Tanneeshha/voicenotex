import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import '../services/speech_service.dart';

class SpeechControlPanel extends StatelessWidget {
  final SpeechStatus status;
  final int durationSeconds;
  final int wordCount;
  final bool isNoiseCancelEnabled;
  final bool showActionButtons;
  final VoidCallback onToggleListening;
  final VoidCallback onToggleNoiseCancel;
  final VoidCallback onRetry;
  final VoidCallback onProceed;

  const SpeechControlPanel({
    super.key,
    required this.status,
    required this.durationSeconds,
    required this.wordCount,
    required this.isNoiseCancelEnabled,
    required this.showActionButtons,
    required this.onToggleListening,
    required this.onToggleNoiseCancel,
    required this.onRetry,
    required this.onProceed,
  });

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hStr = hours.toString().padLeft(2, '0');
      return "$hStr:$mStr:$sStr";
    }
    return "$mStr:$sStr";
  }

  @override
  Widget build(BuildContext context) {
    final isListening = status == SpeechStatus.listening;
    final isRestarting = status == SpeechStatus.restarting;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 12, left: 16, right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Real-Time Status & Metrics Bar ────────────────────
          _buildStatusBar(context),
          const SizedBox(height: 14),

          // ── Action Buttons / Mic Controls ─────────────────────
          if (showActionButtons)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: _buildActionBtn(
                    label: "RETRY",
                    icon: Icons.refresh_rounded,
                    color: Colors.redAccent,
                    onTap: onRetry,
                    isOutline: true,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: _buildMicButton(
                    isListening: isListening,
                    isRestarting: isRestarting,
                    showLabel: true,
                    small: true,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: _buildActionBtn(
                    label: "PROCEED",
                    icon: Icons.arrow_forward_rounded,
                    color: const Color(0xFF1E3A8A),
                    textColor: Colors.white,
                    onTap: onProceed,
                    isOutline: false,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Expanded(child: SizedBox()), // Balance spacer
                _buildMicButton(
                  isListening: isListening,
                  isRestarting: isRestarting,
                  showLabel: true,
                  small: false,
                ),
                Expanded(child: Center(child: _buildNoiseCancelToggle())),
              ],
            ),
        ],
      ),
    );
  }

  // ── Status & Metrics Bar ────────────────────────────────────
  Widget _buildStatusBar(BuildContext context) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case SpeechStatus.listening:
        statusText = "Listening";
        statusColor = const Color(0xFF10B981); // Emerald green
        statusIcon = Icons.mic;
        break;
      case SpeechStatus.restarting:
        statusText = "Syncing...";
        statusColor = const Color(0xFFF59E0B); // Amber
        statusIcon = Icons.sync;
        break;
      case SpeechStatus.paused:
        statusText = "Paused";
        statusColor = const Color(0xFF6366F1); // Indigo
        statusIcon = Icons.pause_circle_outline;
        break;
      case SpeechStatus.networkError:
        statusText = "Offline";
        statusColor = const Color(0xFFEF4444); // Red
        statusIcon = Icons.wifi_off_rounded;
        break;
      case SpeechStatus.permissionDenied:
        statusText = "Mic Permission";
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.mic_off_rounded;
        break;
      case SpeechStatus.error:
        statusText = "Error";
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.error_outline_rounded;
        break;
      case SpeechStatus.idle:
        statusText = "Ready";
        statusColor = const Color(0xFF64748B); // Slate
        statusIcon = Icons.radio_button_unchecked;
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 15),
                const SizedBox(width: 5),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (durationSeconds > 0 || wordCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(durationSeconds),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(
                    "$wordCount words",
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Noise Cancellation Toggle ───────────────────────────────
  Widget _buildNoiseCancelToggle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onToggleNoiseCancel,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isNoiseCancelEnabled
                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: isNoiseCancelEnabled
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
                    : Colors.grey.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Icon(
              isNoiseCancelEnabled ? Icons.graphic_eq : Icons.multiline_chart,
              color: isNoiseCancelEnabled
                  ? const Color(0xFF1E3A8A)
                  : Colors.grey,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "NOISE CANCEL",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            color: isNoiseCancelEnabled ? const Color(0xFF1E3A8A) : Colors.grey,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  // ── Microphone / Pause Button ───────────────────────────────
  Widget _buildMicButton({
    required bool isListening,
    required bool isRestarting,
    required bool showLabel,
    required bool small,
  }) {
    final double size = small ? 62 : 78;
    final double iconSize = small ? 28 : 36;

    Color startColor;
    Color endColor;
    IconData icon;
    String label;

    if (isListening) {
      startColor = const Color(0xFFFFB300);
      endColor = const Color(0xFFFF8F00);
      icon = Icons.pause_rounded;
      label = "PAUSE";
    } else if (isRestarting) {
      startColor = const Color(0xFFF59E0B);
      endColor = const Color(0xFFD97706);
      icon = Icons.sync_rounded;
      label = "SYNCING";
    } else {
      startColor = const Color(0xFF1E3A8A);
      endColor = const Color(0xFF3B82F6);
      icon = Icons.mic_rounded;
      label = showActionButtons ? "RESUME" : "TAP TO RECORD";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarGlow(
          animate: isListening,
          glowColor: const Color(0xFFFFB300),
          duration: const Duration(milliseconds: 1800),
          repeat: true,
          child: GestureDetector(
            onTap: onToggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [startColor, endColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: startColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF1E293B),
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ],
    );
  }

  // ── Action Buttons (Retry / Proceed) ────────────────────────
  Widget _buildActionBtn({
    required String label,
    required IconData icon,
    required Color color,
    Color textColor = const Color(0xFF0F111A),
    required VoidCallback onTap,
    required bool isOutline,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isOutline ? color.withValues(alpha: 0.08) : color,
          borderRadius: BorderRadius.circular(24),
          border: isOutline ? Border.all(color: color, width: 1.5) : null,
          boxShadow: isOutline
              ? []
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isOutline ? color : textColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isOutline ? color : textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

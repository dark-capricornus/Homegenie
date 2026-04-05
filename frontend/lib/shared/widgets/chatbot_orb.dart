import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';

class ChatbotOrb extends StatefulWidget {
  final bool isDark;
  const ChatbotOrb({super.key, required this.isDark});

  @override
  State<ChatbotOrb> createState() => _ChatbotOrbState();
}

class _ChatbotOrbState extends State<ChatbotOrb>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  bool _isRecording = false;
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  AudioRecorder? _recorder;

  // Pulse animation for the orb button
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder?.dispose();
    super.dispose();
  }

  void _togglePanel() => setState(() => _isOpen = !_isOpen);

  Future<void> _startRecording() async {
    _recorder = AudioRecorder();
    if (await _recorder!.hasPermission()) {
      final String extension = Platform.isIOS ? 'm4a' : 'aac';
      final filePath =
          '${Directory.systemTemp.path}/hg_chat_${DateTime.now().millisecondsSinceEpoch}.$extension';
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          bitRate: 32000,
        ),
        path: filePath,
      );
      HapticFeedback.mediumImpact();
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    setState(() => _isRecording = false);
    if (_recorder == null) return;
    final ctrl = context.read<DashboardController>();
    final path = await _recorder!.stop();
    HapticFeedback.lightImpact();
    if (path != null && mounted) {
      final bytes = await File(path).readAsBytes();
      final String extension = Platform.isIOS ? 'm4a' : 'aac';
      await ctrl.sendVoiceAudio(bytes.toList(), 'audio.$extension');
      try {
        await File(path).delete();
      } catch (_) {}
    }
    await _recorder?.dispose();
    _recorder = null;
  }

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    context.read<DashboardController>().sendChatMessage(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final panelWidth = (screenSize.width - 40).clamp(280.0, 380.0);
    final maxPanelHeight =
        screenSize.height < 600 ? screenSize.height * 0.6 : 480.0;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Chat panel
        AnimatedScale(
          scale: _isOpen ? 1.0 : 0.85,
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.bottomRight,
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: _isOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_isOpen,
              child: _buildChatPanel(panelWidth, maxPanelHeight),
            ),
          ),
        ),
        // Orb button
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: GestureDetector(
            onTap: _togglePanel,
            child: ScaleTransition(
              scale: _isRecording ? const AlwaysStoppedAnimation(1.0) : _pulseAnim,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? AppColors.error : AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? AppColors.error : AppColors.primary)
                          .withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isOpen ? Icons.close : Icons.auto_awesome,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatPanel(double width, double maxHeight) {
    return Consumer<DashboardController>(
      builder: (context, ctrl, _) {
        _scrollToBottom();
        final textPrimary =
            widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        final surface = widget.isDark ? AppColors.darkSurface : Colors.white;
        final border = widget.isDark ? AppColors.darkBorder : AppColors.lightBorder;

        return Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            constraints: BoxConstraints(maxHeight: maxHeight),
            margin: const EdgeInsets.only(bottom: 92, right: 16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(textPrimary),
                Flexible(child: _buildMessageList(ctrl)),
                _buildInputBar(ctrl),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color textPrimary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HomeGenie AI',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    )),
                Text('Smart home assistant',
                    style: TextStyle(
                      color: widget.isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 11,
                    )),
              ],
            ),
          ),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isOpen = false),
              icon: Icon(
                Icons.close,
                size: 18,
                color: widget.isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(DashboardController ctrl) {
    if (ctrl.chatMessages.isEmpty && !ctrl.isChatProcessing) {
      return _buildEmptyState();
    }
    final itemCount =
        ctrl.chatMessages.length + (ctrl.isChatProcessing ? 1 : 0);
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      itemCount: itemCount,
      itemBuilder: (ctx, i) {
        if (i == ctrl.chatMessages.length) {
          return const _TypingIndicator();
        }
        final msg = ctrl.chatMessages[i];
        return _ChatBubble(
          message: msg.text,
          isUser: msg.isUser,
          isDark: widget.isDark,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.primaryDim,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            'Hi! I\'m HomeGenie AI',
            style: TextStyle(
              color: widget.isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me to control devices, create routines, or check your home status.',
            style: TextStyle(
              color: widget.isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 12,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _SuggestionChip(
                label: 'Turn off all lights',
                isDark: widget.isDark,
                onTap: () => context
                    .read<DashboardController>()
                    .sendChatMessage('Turn off all lights'),
              ),
              _SuggestionChip(
                label: 'Home status',
                isDark: widget.isDark,
                onTap: () => context
                    .read<DashboardController>()
                    .sendChatMessage('What is my home status?'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(DashboardController ctrl) {
    final border = widget.isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final hint = widget.isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final textColor = widget.isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          // Mic button
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _isRecording
                    ? AppColors.errorDim
                    : AppColors.primaryDim,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                color: _isRecording ? AppColors.error : AppColors.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Text field
          Expanded(
            child: TextField(
              controller: _textCtrl,
              enabled: !_isRecording,
              style: TextStyle(color: textColor, fontSize: 13),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              decoration: InputDecoration(
                hintText: _isRecording ? 'Listening...' : 'Ask anything...',
                hintStyle: TextStyle(color: hint, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button
          GestureDetector(
            onTap: ctrl.isChatProcessing ? null : _sendText,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ctrl.isChatProcessing
                    ? AppColors.primaryDim
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: ctrl.isChatProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat bubble
// ---------------------------------------------------------------------------
class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isDark;

  const _ChatBubble(
      {required this.message, required this.isUser, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary),
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator (bouncing dots)
// ---------------------------------------------------------------------------
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkSurface2,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final offset =
                    sin((_ctrl.value * 2 * pi) + (i * pi / 2.5)) * 4.0;
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Suggestion chip (empty state)
// ---------------------------------------------------------------------------
class _SuggestionChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _SuggestionChip(
      {required this.label, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryDim,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

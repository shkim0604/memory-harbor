import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum CallStatus { connecting, onCall, ended }

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  CallStatus _callStatus = CallStatus.connecting;
  bool _isRecording = false;
  final TextEditingController _memoController = TextEditingController();

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const Spacer(),
            // Call Info
            _buildCallInfo(),
            const SizedBox(height: 40),
            // Status Indicator
            _buildStatusIndicator(),
            const Spacer(),
            // Memo Section
            _buildMemoSection(),
            const SizedBox(height: 24),
            // Control Buttons
            _buildControlButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            _getStatusText(),
            style: TextStyle(
              color: _getStatusColor(),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 48), // Balance
        ],
      ),
    );
  }

  Widget _buildCallInfo() {
    return Column(
      children: [
        // Profile Image
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: _getStatusColor(),
              width: 4,
            ),
          ),
          child: const Icon(
            Icons.person,
            size: 60,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 20),
        // Name
        const Text(
          '할머니',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        // Residence Era Info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '1960~1980 · 서울 종로구',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    return Column(
      children: [
        if (_callStatus == CallStatus.onCall) ...[
          const Text(
            '12:34',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w300,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
          if (_isRecording)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '녹음 중',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
        ] else if (_callStatus == CallStatus.connecting) ...[
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _getStatusColor(),
            ),
          ),
        ] else ...[
          const Icon(
            Icons.call_end,
            size: 60,
            color: Colors.white54,
          ),
          const SizedBox(height: 8),
          const Text(
            '통화 종료',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMemoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.edit_note,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '짧은 메모',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '통화 중 메모를 남겨보세요...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute Button
          _buildControlButton(
            icon: Icons.mic_off,
            label: '음소거',
            onPressed: () {},
          ),
          // Record Button
          _buildControlButton(
            icon: _isRecording ? Icons.stop : Icons.fiber_manual_record,
            label: _isRecording ? '중지' : '녹음',
            color: _isRecording ? Colors.red : null,
            onPressed: () {
              setState(() {
                _isRecording = !_isRecording;
              });
            },
          ),
          // End Call Button
          _buildControlButton(
            icon: Icons.call_end,
            label: '종료',
            color: Colors.red,
            isLarge: true,
            onPressed: () {
              setState(() {
                _callStatus = CallStatus.ended;
              });
            },
          ),
          // Speaker Button
          _buildControlButton(
            icon: Icons.volume_up,
            label: '스피커',
            onPressed: () {},
          ),
          // Status Toggle (for demo)
          _buildControlButton(
            icon: Icons.swap_horiz,
            label: '상태',
            onPressed: () {
              setState(() {
                if (_callStatus == CallStatus.connecting) {
                  _callStatus = CallStatus.onCall;
                } else if (_callStatus == CallStatus.onCall) {
                  _callStatus = CallStatus.ended;
                } else {
                  _callStatus = CallStatus.connecting;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    bool isLarge = false,
  }) {
    final size = isLarge ? 64.0 : 52.0;
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color ?? Colors.white.withValues(alpha: 0.15),
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: color != null ? Colors.white : Colors.white70,
              size: isLarge ? 28 : 24,
            ),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _getStatusText() {
    switch (_callStatus) {
      case CallStatus.connecting:
        return '● 연결 중...';
      case CallStatus.onCall:
        return '● 통화 중';
      case CallStatus.ended:
        return '● 통화 종료';
    }
  }

  Color _getStatusColor() {
    switch (_callStatus) {
      case CallStatus.connecting:
        return AppColors.connecting;
      case CallStatus.onCall:
        return AppColors.onCall;
      case CallStatus.ended:
        return AppColors.ended;
    }
  }
}

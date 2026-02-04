import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../call/receiver_call_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'receiver_home_screen.dart';
import '../../viewmodels/call_session_viewmodel.dart';
import '../../widgets/call_status_indicator.dart';

class ReceiverMainNavigation extends StatefulWidget {
  const ReceiverMainNavigation({super.key});

  @override
  State<ReceiverMainNavigation> createState() => _ReceiverMainNavigationState();
}

class _ReceiverMainNavigationState extends State<ReceiverMainNavigation> {
  int _currentIndex = 0;
  final CallSessionViewModel _session = CallSessionViewModel.instance;
  late final VoidCallback _onSessionChanged;
  Offset? _callPipOffset;

  @override
  void initState() {
    super.initState();
    _onSessionChanged = () {
      if (mounted) setState(() {});
    };
    _session.init();
    _session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: const [
                  ReceiverHomeScreen(),
                  HistoryScreen(),
                  SettingsScreen(),
                ],
              ),
              if (_session.status != CallStatus.ended)
                _buildCallPip(context, constraints),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textHint,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined),
              activeIcon: Icon(Icons.location_on),
              label: '히스토리',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallPip(BuildContext context, BoxConstraints constraints) {
    const margin = 16.0;
    const pipMinHeight = 64.0;

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isConnecting = _session.status == CallStatus.connecting;
    final isOnCall = _session.status == CallStatus.onCall;
    final label = isConnecting
        ? '연결 중...'
        : (isOnCall ? '통화 중' : '통화 대기');

    final availableWidth = constraints.maxWidth - (margin * 2);
    final pipWidth = availableWidth.clamp(240.0, 360.0);

    final reservedBottom = bottomPadding + 72.0;
    final minX = margin;
    final maxX = (constraints.maxWidth - pipWidth - margin).clamp(minX, 1e9);
    final minY = margin;
    final maxY = (constraints.maxHeight - pipMinHeight - reservedBottom)
        .clamp(minY, 1e9);

    final defaultOffset = Offset(minX, maxY);
    _callPipOffset ??= defaultOffset;

    final effectiveOffset = Offset(
      _callPipOffset!.dx.clamp(minX, maxX),
      _callPipOffset!.dy.clamp(minY, maxY),
    );

    if (effectiveOffset != _callPipOffset) {
      _callPipOffset = effectiveOffset;
    }

    return Positioned(
      left: effectiveOffset.dx,
      top: effectiveOffset.dy,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onPanUpdate: (details) {
            final next = Offset(
              (_callPipOffset!.dx + details.delta.dx).clamp(minX, maxX),
              (_callPipOffset!.dy + details.delta.dy).clamp(minY, maxY),
            );
            setState(() {
              _callPipOffset = next;
            });
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: pipWidth, maxWidth: pipWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnCall ? AppColors.onCall : AppColors.connecting,
                    ),
                    child: const Icon(Icons.call, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (isOnCall)
                          Text(
                            _session.formattedDuration,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '복귀',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReceiverCallScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_full, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: isConnecting ? '취소' : '종료',
                    onPressed: () async {
                      await _session.endCall();
                    },
                    icon: Icon(
                      isConnecting ? Icons.close : Icons.call_end,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

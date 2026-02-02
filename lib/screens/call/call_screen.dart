import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../widgets/call_status_indicator.dart';
import 'call_detail_screen.dart';

class CallScreen extends StatefulWidget {
  final bool startConnecting;

  const CallScreen({super.key, this.startConnecting = false});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late CallStatus _callStatus;
  bool _isMuted = false;
  bool _isSpeaker = false;
  int? _selectedResidenceIndex;

  @override
  void initState() {
    super.initState();
    _callStatus = widget.startConnecting
        ? CallStatus.connecting
        : CallStatus.ended;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusSection(),
            Expanded(child: _buildResidenceSection()),
            _buildControlSection(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 상단: Status 섹션
  // ============================================================
  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          CallStatusIndicator(status: _callStatus, duration: '12:34'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _getStatusColor(), width: 3),
                  image: DecorationImage(
                    image: AssetImage(MockData.careReceiver.profileImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                MockData.careReceiver.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 중단: 시대별 거주지 리스트
  // ============================================================
  Widget _buildResidenceSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                '시대별 거주지',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '대화 주제를 선택하세요',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: MockData.residences.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final residence = MockData.residences[index];
                final isSelected = _selectedResidenceIndex == index;
                return _buildResidenceCard(
                  era: residence.era,
                  location: residence.location,
                  detail: residence.detail,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedResidenceIndex = isSelected ? null : index;
                    });
                    if (!isSelected) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CallDetailScreen(
                            residenceId: residence.residenceId,
                            era: residence.era,
                            location: residence.location,
                            detail: residence.detail,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResidenceCard({
    required String era,
    required String location,
    required String detail,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.3)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                era,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isSelected ? AppColors.primary : AppColors.textHint,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 하단: 통화 관련 아이콘들
  // ============================================================
  Widget _buildControlSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            label: _isMuted ? '음소거 해제' : '음소거',
            isActive: _isMuted,
            onPressed: () => setState(() => _isMuted = !_isMuted),
          ),
          _buildControlButton(
            icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
            label: '스피커',
            isActive: _isSpeaker,
            onPressed: () => setState(() => _isSpeaker = !_isSpeaker),
          ),
          _buildEndCallButton(),
          _buildControlButton(
            icon: Icons.edit_note,
            label: '메모',
            onPressed: _showMemoBottomSheet,
          ),
          _buildControlButton(
            icon: Icons.swap_horiz,
            label: '상태변경',
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
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.15),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndCallButton() {
    final isEnded = _callStatus == CallStatus.ended;
    return GestureDetector(
      onTap: () {
        setState(() {
          _callStatus = isEnded ? CallStatus.connecting : CallStatus.ended;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEnded ? AppColors.primary : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (isEnded ? AppColors.primary : Colors.red).withValues(
                    alpha: 0.4,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isEnded ? Icons.phone : Icons.call_end,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isEnded ? '다시 연결' : '종료',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemoBottomSheet() {
    final memoController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '통화 메모',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: memoController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '통화 내용을 메모하세요...',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '저장',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

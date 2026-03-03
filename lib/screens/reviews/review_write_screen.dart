import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/review_service.dart';
import '../../theme/app_colors.dart';
import '../../services/local_call_memo_service.dart';

class ReviewWriteScreen extends StatefulWidget {
  final VoidCallback? onDone;
  final String? callId;

  const ReviewWriteScreen({super.key, this.onDone, this.callId});

  @override
  State<ReviewWriteScreen> createState() => _ReviewWriteScreenState();
}

class _TopicOption {
  final String value;
  final String topicType;
  final String topicId;
  final String label;
  final String question;
  final Map<String, dynamic>? residencePayload;

  const _TopicOption({
    required this.value,
    required this.topicType,
    required this.topicId,
    required this.label,
    required this.question,
    this.residencePayload,
  });

  bool get isResidence => topicType == 'residence';
  bool get isMeaning => topicType == 'meaning';
  String? get residenceId => isResidence ? topicId : null;
  String? get meaningId => isMeaning ? topicId : null;
}

class _ReviewWriteScreenState extends State<ReviewWriteScreen> {
  int? _listeningScore = 1;
  final TextEditingController _callMemoController = TextEditingController();
  final TextEditingController _notHeardMomentController =
      TextEditingController();
  final TextEditingController _nextTryController = TextEditingController();
  final TextEditingController _emotionWordController = TextEditingController();
  String _emotionSource = '내 것';
  final TextEditingController _smallResetController = TextEditingController();

  bool _isLoadingExisting = false;
  bool _isSubmitting = false;
  String? _topicLoadError;
  String? _existingMyReviewDocId;
  List<_TopicOption> _topicOptions = const [];
  String? _selectedTopicValue;
  static const List<String> _emotionSourceOptions = ['내 것', '상대 것', '감정섞임'];
  final DateTime _requiredStepOpenedAt = DateTime.now();
  int? _requiredDurationSec;
  bool _isOptionalStep = false;

  @override
  void initState() {
    super.initState();
    _initReviewData();
  }

  @override
  void dispose() {
    _callMemoController.dispose();
    _notHeardMomentController.dispose();
    _nextTryController.dispose();
    _emotionWordController.dispose();
    _smallResetController.dispose();
    super.dispose();
  }

  Future<void> _initReviewData() async {
    final callId = widget.callId?.trim() ?? '';
    if (callId.isEmpty) return;

    setState(() {
      _isLoadingExisting = true;
    });

    try {
      await _loadCallContext(callId);
      await _loadExistingMyReview(callId);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExisting = false;
        });
      }
    }
  }

  Future<void> _loadCallContext(String callId) async {
    try {
      final contextData = await ReviewService.instance.fetchContext(
        callId: callId,
      );
      final localMemo = await LocalCallMemoService.instance.getMemo(callId);
      if (localMemo != null) {
        _callMemoController.text = localMemo;
      } else {
        _callMemoController.text = contextData?.humanNotes ?? '';
      }
      if (contextData == null) {
        _topicLoadError = '대화주제 데이터를 서버에서 불러오지 못했습니다.';
        return;
      }
      _topicLoadError = null;

      if (contextData.selectedMeaningId != null &&
          contextData.selectedMeaningId!.isNotEmpty) {
        _selectedTopicValue = _topicValue('meaning', contextData.selectedMeaningId!);
      } else if (contextData.selectedResidenceId != null &&
          contextData.selectedResidenceId!.isNotEmpty) {
        _selectedTopicValue = _topicValue(
          'residence',
          contextData.selectedResidenceId!,
        );
      } else if (contextData.selectedTopicType != null &&
          contextData.selectedTopicType!.isNotEmpty &&
          contextData.selectedTopicId != null &&
          contextData.selectedTopicId!.isNotEmpty) {
        _selectedTopicValue = _topicValue(
          contextData.selectedTopicType!,
          contextData.selectedTopicId!,
        );
      }

      _topicOptions = contextData.topicOptions
          .map(
            (option) => _TopicOption(
              value: option.value,
              topicType: option.topicType,
              topicId: option.topicId,
              label: option.label,
              question: option.question,
              residencePayload: option.residencePayload,
            ),
          )
          .toList();
      if (_selectedTopicValue != null &&
          !_topicOptions.any((topic) => topic.value == _selectedTopicValue)) {
        _selectedTopicValue = null;
      }
    } catch (_) {
      // Keep UI usable even when call context load fails.
    }
  }

  Future<void> _loadExistingMyReview(String callId) async {
    try {
      final myReview = await ReviewService.instance.fetchMyReview(callId: callId);
      if (myReview == null) return;
      _existingMyReviewDocId = myReview.reviewId;

      final score = myReview.listeningScore;
      if (score is int && score >= 1 && score <= 10) {
        _listeningScore = score;
      }

      _notHeardMomentController.text = myReview.notFullyHeardMoment;
      _nextTryController.text = myReview.nextSessionTry;
      _emotionWordController.text = myReview.emotionWord;

      final source = myReview.emotionSource;
      if (source.isNotEmpty) {
        if (source == '감정섞임') {
          _emotionSource = '감정섞임';
        } else {
          _emotionSource = source;
        }
      }

      _smallResetController.text = myReview.smallReset;

      if (myReview.selectedTopicType == 'meaning' &&
          (myReview.selectedMeaningId ?? '').isNotEmpty) {
        _selectedTopicValue = _topicValue('meaning', myReview.selectedMeaningId!);
      } else if ((myReview.selectedResidenceId ?? '').isNotEmpty) {
        _selectedTopicValue = _topicValue(
          'residence',
          myReview.selectedResidenceId!,
        );
      } else if ((myReview.selectedTopicType ?? '').isNotEmpty &&
          (myReview.selectedTopicId ?? '').isNotEmpty) {
        _selectedTopicValue = _topicValue(
          myReview.selectedTopicType!,
          myReview.selectedTopicId!,
        );
      } else {
        final mentioned = myReview.mentionedResidences;
        if (mentioned.isNotEmpty) {
          final first = mentioned.first;
          final rid = (first['residenceId'] ?? '').toString().trim();
          if (rid.isNotEmpty) {
            _selectedTopicValue = _topicValue('residence', rid);
          }
        }
      }
    } catch (_) {
      // Ignore load failures and keep write mode.
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final callId = widget.callId?.trim() ?? '';
    if (callId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('통화 정보가 없어 리뷰를 저장할 수 없습니다')));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다')));
      return;
    }

    if (!_validateRequiredFields()) return;
    final notFullyHeardMoment = _notHeardMomentController.text.trim();
    final nextSessionTry = _nextTryController.text.trim();
    final emotionWord = _emotionWordController.text.trim();
    final emotionSource = _emotionSource.trim();
    final callMemo = _callMemoController.text.trim();
    final selectedTopicValue = _selectedTopicValue?.trim();
    final listeningScore = _listeningScore;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final selectedTopic = _topicOptions
          .where((topic) => topic.value == selectedTopicValue)
          .cast<_TopicOption?>()
          .firstWhere((_) => true, orElse: () => null);
      final mentionedResidences =
          selectedTopic?.isResidence == true &&
              selectedTopic?.residencePayload != null
          ? <Map<String, dynamic>>[
              Map<String, dynamic>.from(selectedTopic!.residencePayload!),
            ]
          : const <Map<String, dynamic>>[];

      final requiredDurationSec =
          _requiredDurationSec ??
          DateTime.now()
              .difference(_requiredStepOpenedAt)
          .inSeconds
          .clamp(0, 86400);

      final saved = await ReviewService.instance.upsertReview(
        ReviewUpsertRequest(
          callId: callId,
          existingMyReviewDocId: _existingMyReviewDocId,
          listeningScore: listeningScore!,
          notFullyHeardMoment: notFullyHeardMoment,
          nextSessionTry: nextSessionTry,
          emotionWord: emotionWord,
          emotionSource: emotionSource,
          smallReset: _smallResetController.text.trim(),
          callMemo: callMemo,
          selectedTopicType: selectedTopic?.topicType,
          selectedTopicId: selectedTopic?.topicId,
          selectedTopicLabel: selectedTopic?.label,
          selectedTopicQuestion: selectedTopic?.question,
          selectedResidenceId: selectedTopic?.residenceId,
          selectedMeaningId: selectedTopic?.meaningId,
          mentionedResidences: mentionedResidences,
          requiredStepOpenedAt: _requiredStepOpenedAt,
          requiredDurationSec: requiredDurationSec,
        ),
      );
      if (!saved) {
        throw StateError('review upsert failed');
      }
      await LocalCallMemoService.instance.removeMemo(callId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('리뷰가 저장되었습니다')));
      widget.onDone?.call();
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('리뷰 저장에 실패했습니다')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool _validateRequiredFields() {
    final notFullyHeardMoment = _notHeardMomentController.text.trim();
    final nextSessionTry = _nextTryController.text.trim();
    final emotionWord = _emotionWordController.text.trim();
    final emotionSource = _emotionSource.trim();
    final selectedTopicValue = _selectedTopicValue?.trim();
    final listeningScore = _listeningScore;

    if (selectedTopicValue == null || selectedTopicValue.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('1. 대화주제를 선택해주세요')));
      return false;
    }
    if (listeningScore == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('2. 경청 점수를 선택해주세요')));
      return false;
    }
    if (notFullyHeardMoment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('3. 충분히 듣지 못한 순간을 입력해주세요')),
      );
      return false;
    }
    if (nextSessionTry.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('4. 다음 세션에서 시도할 한 가지를 입력해주세요')),
      );
      return false;
    }
    if (emotionWord.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('5. 감정을 표현하는 한 단어를 입력해주세요')));
      return false;
    }
    if (emotionSource.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('5-1. 감정의 출처를 선택해주세요')));
      return false;
    }
    return true;
  }

  void _goToOptionalStep() {
    if (!_validateRequiredFields()) return;
    setState(() {
      _requiredDurationSec = DateTime.now()
          .difference(_requiredStepOpenedAt)
          .inSeconds
          .clamp(0, 86400);
      _isOptionalStep = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_existingMyReviewDocId == null ? '리뷰 작성' : '리뷰 수정/보기'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: _isOptionalStep
            ? _buildOptionalStepChildren()
            : _buildRequiredStepChildren(),
      ),
    );
  }

  List<Widget> _buildRequiredStepChildren() {
    return [
      _buildStepHeader('1/2 단계 · 필수 질문'),
      const SizedBox(height: 16),
      _buildSectionTitle('1. 대화주제 선택 (시대/의미)'),
      const SizedBox(height: 8),
      _buildTopicDropdown(),
      const SizedBox(height: 20),
      _buildSectionTitle('2. 오늘 나의 경청은 몇 점? (1~10)'),
      const SizedBox(height: 8),
      Text(
        '1점: 주어진 태스크를 수행하기에 급급했다\n10점: 상대의 속도에 맞추어 충분히 이해하며 들었다 (경청자 역할)',
        style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 10),
      _buildScoreDropdown(),
      const SizedBox(height: 22),
      _buildSectionTitle('3. 내가 충분히 듣지 못했다고 느낀 순간이 있었나? 무엇이 그렇게 만들었나?'),
      const SizedBox(height: 8),
      _buildTextField(
        controller: _notHeardMomentController,
        hint: '그 순간과 이유를 적어주세요',
        maxLines: 4,
      ),
      const SizedBox(height: 22),
      _buildSectionTitle('4. 다음 세션에서 하나만 바꾼다면, 무엇을 시도해볼 것인가?'),
      const SizedBox(height: 8),
      _buildTextField(
        controller: _nextTryController,
        hint: '다음에 시도할 한 가지를 적어주세요',
        maxLines: 3,
      ),
      const SizedBox(height: 22),
      _buildSectionTitle('5. 내 감정을 표현하는 한 단어는?'),
      const SizedBox(height: 8),
      _buildTextField(
        controller: _emotionWordController,
        hint: '예: 아쉬움, 안도, 뿌듯함',
        maxLines: 1,
      ),
      const SizedBox(height: 22),
      _buildSubQuestionBlock(
        title: '5-1. 그 감정은 어디에 가까운가?',
        child: _buildEmotionSourceDropdown(),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_isSubmitting || _isLoadingExisting)
              ? null
              : _goToOptionalStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            _isLoadingExisting ? '불러오는 중...' : '선택 질문으로 이동',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildOptionalStepChildren() {
    return [
      _buildStepHeader('2/2 단계 · 선택 질문'),
      const SizedBox(height: 16),
      _buildSubQuestionBlock(
        title: '5-2. (선택) 이 감정을 오래 끌고 가지 않기 위해, 내가 할 작은 행동 1개는?',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOptionalLabel(),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _smallResetController,
              hint: '예: 5분 산책, 물 한 잔 마시기',
              maxLines: 2,
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      _buildSectionTitle('6. (선택) 통화 메모'),
      const SizedBox(height: 8),
      _buildOptionalLabel(description: '통화 요약이나 주요 대화 내용을 메모해 주세요.'),
      const SizedBox(height: 8),
      _buildTextField(
        controller: _callMemoController,
        hint: '메모를 입력하세요',
        maxLines: 4,
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: (_isSubmitting || _isLoadingExisting)
                  ? null
                  : () {
                      setState(() {
                        _isOptionalStep = false;
                      });
                    },
              child: const Text('필수로 돌아가기'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: (_isSubmitting || _isLoadingExisting) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isSubmitting ? '저장 중...' : '저장',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildStepHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTopicDropdown() {
    if (_isLoadingExisting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_topicLoadError != null) {
      return Text(
        _topicLoadError!,
        style: TextStyle(fontSize: 14, color: Colors.red.shade400),
      );
    }
    if (_topicOptions.isEmpty) {
      return Text(
        '표시할 대화 주제가 없습니다',
        style: TextStyle(fontSize: 14, color: AppColors.textHint),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedTopicValue,
      isExpanded: true,
      decoration: _dropdownDecoration('대화 주제를 선택하세요'),
      items: _topicOptions
          .map(
            (topic) => DropdownMenuItem<String>(
              value: topic.value,
              child: _buildTopicOptionLabel(topic),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedTopicValue = value;
        });
      },
    );
  }

  String _topicValue(String type, String id) => '$type::$id';

  Widget _buildTopicOptionLabel(_TopicOption topic) {
    final isResidence = topic.topicType == 'residence';
    final tagText = isResidence ? '[시대]' : '[의미]';
    final bodyText = topic.label
        .replaceFirst('[시대]', '')
        .replaceFirst('[의미]', '')
        .trim();

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isResidence
                ? AppColors.primaryLight.withValues(alpha: 0.35)
                : AppColors.accentLight.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            tagText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isResidence ? AppColors.primaryDark : AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            bodyText,
            style: const TextStyle(fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreDropdown() {
    final scores = List<int>.generate(10, (i) => i + 1);
    return DropdownButtonFormField<int>(
      initialValue: _listeningScore,
      isExpanded: true,
      decoration: _dropdownDecoration('경청 점수를 선택하세요'),
      items: scores
          .map(
            (score) => DropdownMenuItem<int>(
              value: score,
              child: Text('$score점', style: const TextStyle(fontSize: 15)),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _listeningScore = value;
        });
      },
    );
  }

  Widget _buildEmotionSourceDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _emotionSourceOptions.contains(_emotionSource)
          ? _emotionSource
          : _emotionSourceOptions.first,
      isExpanded: true,
      decoration: _dropdownDecoration('감정의 출처를 선택하세요'),
      items: _emotionSourceOptions
          .map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                style: const TextStyle(fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _emotionSource = value;
        });
      },
    );
  }

  Widget _buildOptionalLabel({String description = '작성하지 않아도 저장할 수 있습니다.'}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            '선택',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: AppColors.textHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSubQuestionBlock({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 16,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 15, color: AppColors.textHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

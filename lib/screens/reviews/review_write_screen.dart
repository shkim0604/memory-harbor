import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class _MeaningQuestionOption {
  final String meaningId;
  final int order;
  final String title;
  final String question;

  const _MeaningQuestionOption({
    required this.meaningId,
    required this.order,
    required this.title,
    required this.question,
  });
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
  String? _existingMyReviewDocId;
  List<_TopicOption> _topicOptions = const [];
  String? _selectedTopicValue;
  static const List<_MeaningQuestionOption> _defaultMeaningQuestions = [
    _MeaningQuestionOption(
      meaningId: 'meaning_legacy_event',
      order: 1,
      title: '꼭 남기고 싶은 사건',
      question: '남은 사람들이 꼭 기억해줬으면 하는 사건은 무엇인가요?',
    ),
    _MeaningQuestionOption(
      meaningId: 'meaning_work_memory',
      order: 2,
      title: '직장생활 기억',
      question: '직장생활에서 가장 기억에 남는 사건은 무엇인가요?',
    ),
    _MeaningQuestionOption(
      meaningId: 'meaning_church_memory',
      order: 3,
      title: '교회생활 기억',
      question: '교회생활에서 가장 기억에 남는 사건은 무엇인가요?',
    ),
    _MeaningQuestionOption(
      meaningId: 'meaning_influential_person',
      order: 4,
      title: '영향을 준 사람',
      question: '인생에서 가장 큰 영향을 받은 사람은 누구인가요?',
    ),
    _MeaningQuestionOption(
      meaningId: 'meaning_rewind_moment',
      order: 5,
      title: '돌아가고 싶은 순간',
      question: '인생에서 다시 돌아가고 싶은 순간이 있다면 언제인가요?',
    ),
  ];
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (callId.isEmpty || uid == null || uid.isEmpty) return;

    setState(() {
      _isLoadingExisting = true;
    });

    try {
      await _loadCallContext(callId);
      await _loadExistingMyReview(callId, uid);
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
      final callDoc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .get();
      final callData = callDoc.data();
      final localMemo = await LocalCallMemoService.instance.getMemo(callId);
      if (localMemo != null) {
        _callMemoController.text = localMemo;
      } else {
        _callMemoController.text = (callData?['humanNotes'] ?? '').toString();
      }
      if (callData == null) return;

      final mentioned = callData['mentionedResidences'];
      if (mentioned is List && mentioned.isNotEmpty && mentioned.first is Map) {
        final first = Map<String, dynamic>.from(mentioned.first as Map);
        final rid = (first['residenceId'] ?? '').toString();
        if (rid.isNotEmpty) {
          _selectedTopicValue = _topicValue('residence', rid);
        }
      }
      final selectedMeaningId = (callData['selectedMeaningId'] ?? '')
          .toString()
          .trim();
      if (selectedMeaningId.isNotEmpty) {
        _selectedTopicValue = _topicValue('meaning', selectedMeaningId);
      }

      final receiverId = (callData['receiverId'] ?? '').toString();
      if (receiverId.isEmpty) return;

      final receiverRef = FirebaseFirestore.instance
          .collection('receivers')
          .doc(receiverId);

      final snaps = await Future.wait([
        receiverRef.collection('residence_stats').get(),
        receiverRef.collection('meaning_stats').get(),
      ]);
      final residenceSnap = snaps[0];
      final meaningSnap = snaps[1];

      final residenceOptions = residenceSnap.docs.map((doc) {
        final data = doc.data();
        final era = (data['era'] ?? '').toString();
        final location = (data['location'] ?? '').toString();
        final detail = (data['detail'] ?? '').toString();
        final label = era.isNotEmpty ? '$era · $location' : location;
        return _TopicOption(
          value: _topicValue('residence', doc.id),
          topicType: 'residence',
          topicId: doc.id,
          label: '[시대] $label',
          question: detail,
          residencePayload: {
            'residenceId': doc.id,
            'era': era,
            'location': location,
            'detail': detail,
          },
        );
      }).toList();

      final meaningOptions = _buildMeaningTopicOptions(meaningSnap);
      _topicOptions = [...residenceOptions, ...meaningOptions];
      if (_selectedTopicValue != null &&
          !_topicOptions.any((topic) => topic.value == _selectedTopicValue)) {
        _selectedTopicValue = null;
      }
    } catch (_) {
      // Keep UI usable even when call context load fails.
    }
  }

  Future<void> _loadExistingMyReview(String callId, String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .collection('reviews')
          .where('writerUserId', isEqualTo: uid)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return;
      final doc = snap.docs.first;
      final data = doc.data();
      _existingMyReviewDocId = doc.id;

      final score = data['listeningScore'];
      if (score is int && score >= 1 && score <= 10) {
        _listeningScore = score;
      }

      _notHeardMomentController.text = (data['notFullyHeardMoment'] ?? '')
          .toString();
      _nextTryController.text = (data['nextSessionTry'] ?? '').toString();
      _emotionWordController.text = (data['emotionWord'] ?? data['mood'] ?? '')
          .toString();

      final source = (data['emotionSource'] ?? '').toString();
      if (source.isNotEmpty) {
        if (source == '감정섞임') {
          _emotionSource = '감정섞임';
        } else {
          _emotionSource = source;
        }
      }

      _smallResetController.text = (data['smallReset'] ?? '').toString();

      final selectedTopicType = (data['selectedTopicType'] ?? '')
          .toString()
          .trim();
      final selectedMeaningId = (data['selectedMeaningId'] ?? '')
          .toString()
          .trim();
      final selectedResidenceId = (data['selectedResidenceId'] ?? '')
          .toString()
          .trim();
      if (selectedTopicType == 'meaning' && selectedMeaningId.isNotEmpty) {
        _selectedTopicValue = _topicValue('meaning', selectedMeaningId);
      } else if (selectedResidenceId.isNotEmpty) {
        _selectedTopicValue = _topicValue('residence', selectedResidenceId);
      } else {
        final mentioned = data['mentionedResidences'];
        if (mentioned is List &&
            mentioned.isNotEmpty &&
            mentioned.first is Map) {
          final first = Map<String, dynamic>.from(mentioned.first as Map);
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
      final user = FirebaseAuth.instance.currentUser;
      final writerName = (user?.displayName ?? '').trim();

      const summary = '';
      const comment = '';

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

      final firestore = FirebaseFirestore.instance;
      final callRef = firestore.collection('calls').doc(callId);
      final requiredDurationSec =
          _requiredDurationSec ??
          DateTime.now()
              .difference(_requiredStepOpenedAt)
          .inSeconds
          .clamp(0, 86400);

      final payload = <String, dynamic>{
        'callId': callId,
        'writerUserId': uid,
        'writerNameSnapshot': writerName,
        'mentionedResidences': mentionedResidences,
        'selectedTopicType': selectedTopic?.topicType,
        'selectedTopicId': selectedTopic?.topicId,
        'selectedTopicLabel': selectedTopic?.label,
        'selectedTopicQuestion': selectedTopic?.question,
        'selectedResidenceId': selectedTopic?.residenceId,
        'selectedMeaningId': selectedTopic?.meaningId,
        'humanSummary': summary,
        'humanKeywords': const [],
        'mood': emotionWord,
        'comment': comment,
        'listeningScore': listeningScore,
        'notFullyHeardMoment': notFullyHeardMoment,
        'nextSessionTry': nextSessionTry,
        'emotionWord': emotionWord,
        'emotionSource': emotionSource,
        'smallReset': _smallResetController.text.trim(),
        'requiredQuestionDurationSec': requiredDurationSec,
      };

      await firestore.runTransaction((tx) async {
        final callSnap = await tx.get(callRef);
        if (!callSnap.exists) {
          throw StateError('call document not found: $callId');
        }
        final callBeforeData = callSnap.data() ?? <String, dynamic>{};
        final receiverId = (callBeforeData['receiverId'] ?? '')
            .toString()
            .trim();

        final reviewRef = _existingMyReviewDocId != null
            ? callRef.collection('reviews').doc(_existingMyReviewDocId)
            : callRef.collection('reviews').doc();
        final reviewSnap = await tx.get(reviewRef);
        final isEdit = reviewSnap.exists;

        Set<String> removedResidenceIds = const <String>{};
        Set<String> addedResidenceIds = const <String>{};
        Set<String> removedMeaningIds = const <String>{};
        Set<String> addedMeaningIds = const <String>{};
        Map<String, int> residenceCurrentById = const <String, int>{};
        Map<String, int> meaningCurrentById = const <String, int>{};
        DocumentReference<Map<String, dynamic>>? receiverRef;

        if (receiverId.isNotEmpty) {
          receiverRef = firestore.collection('receivers').doc(receiverId);
          final beforeResidenceIds = _extractResidenceIdsFromCallData(
            callBeforeData,
          );
          final afterResidenceIds = _extractResidenceIdsFromPayload(
            mentionedResidences,
          );
          final beforeMeaningId = _extractMeaningIdFromCallData(callBeforeData);
          final afterMeaningId = selectedTopic?.topicType == 'meaning'
              ? (selectedTopic?.meaningId ?? '').trim()
              : '';

          removedResidenceIds = beforeResidenceIds.difference(afterResidenceIds);
          addedResidenceIds = afterResidenceIds.difference(beforeResidenceIds);
          final beforeMeaningSet = beforeMeaningId.isEmpty
              ? const <String>{}
              : {beforeMeaningId};
          final afterMeaningSet = afterMeaningId.isEmpty
              ? const <String>{}
              : {afterMeaningId};
          removedMeaningIds = beforeMeaningSet.difference(afterMeaningSet);
          addedMeaningIds = afterMeaningSet.difference(beforeMeaningSet);

          residenceCurrentById = await _readCurrentTotalCalls(
            tx: tx,
            collectionRef: receiverRef.collection('residence_stats'),
            ids: {...removedResidenceIds, ...addedResidenceIds},
          );
          meaningCurrentById = await _readCurrentTotalCalls(
            tx: tx,
            collectionRef: receiverRef.collection('meaning_stats'),
            ids: {...removedMeaningIds, ...addedMeaningIds},
          );
        }

        if (isEdit) {
          tx.update(reviewRef, <String, dynamic>{
            ...payload,
            'lastWriteDurationSec': requiredDurationSec,
            'lastWriteStartedAtClient': Timestamp.fromDate(_requiredStepOpenedAt),
            'lastWriteType': 'edit',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          tx.set(reviewRef, <String, dynamic>{
            ...payload,
            'firstWriteDurationSec': requiredDurationSec,
            'firstWriteStartedAtClient': Timestamp.fromDate(_requiredStepOpenedAt),
            'lastWriteDurationSec': requiredDurationSec,
            'lastWriteStartedAtClient': Timestamp.fromDate(_requiredStepOpenedAt),
            'lastWriteType': 'create',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        final logRef = reviewRef.collection('write_logs').doc();
        tx.set(logRef, <String, dynamic>{
          'type': isEdit ? 'edit' : 'create',
          'durationSec': requiredDurationSec,
          'startedAtClient': Timestamp.fromDate(_requiredStepOpenedAt),
          'phase': 'required',
          'savedAt': FieldValue.serverTimestamp(),
        });

        tx.update(callRef, <String, dynamic>{
          if (!isEdit) 'reviewCount': FieldValue.increment(1),
          if (!isEdit) 'lastReviewAt': FieldValue.serverTimestamp(),
          'humanNotes': callMemo,
          'selectedTopicType': selectedTopic?.topicType,
          'selectedTopicId': selectedTopic?.topicId,
          'selectedResidenceId': selectedTopic?.residenceId,
          'selectedMeaningId': selectedTopic?.meaningId,
          'mentionedResidences': mentionedResidences,
        });

        if (receiverRef != null) {
          _applyCounterDeltaForIds(
            tx: tx,
            collectionRef: receiverRef.collection('residence_stats'),
            removedIds: removedResidenceIds,
            addedIds: addedResidenceIds,
            currentById: residenceCurrentById,
          );
          _applyCounterDeltaForIds(
            tx: tx,
            collectionRef: receiverRef.collection('meaning_stats'),
            removedIds: removedMeaningIds,
            addedIds: addedMeaningIds,
            currentById: meaningCurrentById,
          );
        }
      });
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

  Set<String> _extractResidenceIdsFromCallData(Map<String, dynamic> data) {
    final result = <String>{};
    final mentioned = data['mentionedResidences'];
    if (mentioned is! List) return result;
    for (final item in mentioned) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = (map['residenceId'] ?? '').toString().trim();
      if (id.isNotEmpty) result.add(id);
    }
    return result;
  }

  Set<String> _extractResidenceIdsFromPayload(
    List<Map<String, dynamic>> mentionedResidences,
  ) {
    final result = <String>{};
    for (final item in mentionedResidences) {
      final id = (item['residenceId'] ?? '').toString().trim();
      if (id.isNotEmpty) result.add(id);
    }
    return result;
  }

  String _extractMeaningIdFromCallData(Map<String, dynamic> data) {
    final selectedMeaningId = (data['selectedMeaningId'] ?? '')
        .toString()
        .trim();
    if (selectedMeaningId.isNotEmpty) return selectedMeaningId;

    final selectedTopicType = (data['selectedTopicType'] ?? '')
        .toString()
        .trim();
    if (selectedTopicType == 'meaning') {
      return (data['selectedTopicId'] ?? '').toString().trim();
    }
    return '';
  }

  Future<Map<String, int>> _readCurrentTotalCalls({
    required Transaction tx,
    required CollectionReference<Map<String, dynamic>> collectionRef,
    required Set<String> ids,
  }) async {
    final result = <String, int>{};
    for (final id in ids) {
      final snap = await tx.get(collectionRef.doc(id));
      final data = snap.data() ?? const <String, dynamic>{};
      result[id] = (data['totalCalls'] is num)
          ? (data['totalCalls'] as num).toInt()
          : 0;
    }
    return result;
  }

  void _applyCounterDeltaForIds({
    required Transaction tx,
    required CollectionReference<Map<String, dynamic>> collectionRef,
    required Set<String> removedIds,
    required Set<String> addedIds,
    required Map<String, int> currentById,
  }) {
    for (final id in removedIds) {
      final docRef = collectionRef.doc(id);
      final current = currentById[id] ?? 0;
      final next = (current - 1).clamp(0, 1 << 30);
      tx.set(docRef, <String, dynamic>{
        'totalCalls': next,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    for (final id in addedIds) {
      final docRef = collectionRef.doc(id);
      final current = currentById[id] ?? 0;
      final next = current + 1;
      tx.set(docRef, <String, dynamic>{
        'totalCalls': next,
        'lastCallAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
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
              child: Text(
                topic.label,
                style: const TextStyle(fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
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

  List<_TopicOption> _buildMeaningTopicOptions(
    QuerySnapshot<Map<String, dynamic>> meaningSnap,
  ) {
    final questions = meaningSnap.docs.isNotEmpty
        ? meaningSnap.docs
              .map((doc) {
                final data = doc.data();
                return _MeaningQuestionOption(
                  meaningId: doc.id,
                  order: (data['order'] ?? 999) as int,
                  title: (data['title'] ?? '').toString(),
                  question: (data['question'] ?? '').toString(),
                );
              })
              .toList()
        : _defaultMeaningQuestions;
    questions.sort((a, b) => a.order.compareTo(b.order));
    return questions
        .map(
          (item) => _TopicOption(
            value: _topicValue('meaning', item.meaningId),
            topicType: 'meaning',
            topicId: item.meaningId,
            label: '[의미] Q${item.order}. ${item.question}',
            question: item.question,
          ),
        )
        .toList();
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

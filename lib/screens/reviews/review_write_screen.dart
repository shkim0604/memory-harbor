import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ReviewWriteScreen extends StatefulWidget {
  final VoidCallback? onDone;

  const ReviewWriteScreen({super.key, this.onDone});

  @override
  State<ReviewWriteScreen> createState() => _ReviewWriteScreenState();
}

class _ReviewWriteScreenState extends State<ReviewWriteScreen> {
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String _mood = '기쁨';

  @override
  void dispose() {
    _summaryController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    // TODO: wire to review create API/service.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('리뷰가 저장되었습니다')),
    );
    widget.onDone?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('리뷰 작성'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildSectionTitle('오늘의 분위기'),
          const SizedBox(height: 8),
          _buildMoodChips(),
          const SizedBox(height: 20),
          _buildSectionTitle('요약'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _summaryController,
            hint: '한 줄 요약을 적어주세요',
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('상세 메모'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _commentController,
            hint: '대화 내용을 메모하세요',
            maxLines: 5,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
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
    );
  }

  Widget _buildMoodChips() {
    final moods = ['기쁨', '평온', '감동', '그리움', '기타'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: moods.map((mood) {
        final selected = _mood == mood;
        return ChoiceChip(
          label: Text(mood),
          selected: selected,
          selectedColor: AppColors.primaryLight,
          labelStyle: TextStyle(
            color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            setState(() {
              _mood = mood;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
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
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textHint),
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

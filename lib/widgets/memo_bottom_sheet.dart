import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shows a modal bottom sheet for writing a call memo.
///
/// Always returns the latest memo text when the sheet is dismissed
/// (close button, outside tap, drag down).
Future<String> showMemoBottomSheet(
  BuildContext context, {
  String initialText = '',
}) {
  var latestText = initialText;
  final memoController = TextEditingController(text: initialText);
  memoController.addListener(() {
    latestText = memoController.text;
  });

  return showModalBottomSheet<String>(
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
                  onPressed: () => Navigator.pop(context, memoController.text),
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
            Text(
              '닫으면 임시 저장됩니다',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    ),
  ).then((value) => value ?? latestText);
}

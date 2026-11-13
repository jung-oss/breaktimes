import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../common/widgets/shop_history_list.dart';
import '../services/comfort_service.dart';

/// 받은 위로 편지 기록
class ComfortHistoryScreen extends StatelessWidget {
  const ComfortHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isKorean =
        Provider.of<LocaleProvider>(context).locale.languageCode == 'ko';
    final service = ComfortService();

    return ShopHistoryScreen(
      isKorean: isKorean,
      title: isKorean ? '받은 위로 편지' : 'My comfort letters',
      categoryId: 'comfort',
      emptyText:
          isKorean ? '아직 받은 위로 편지가 없어요.' : 'No comfort letters yet.',
      stream: service.getUserComfortsStream().map((items) => [
            for (final item in items)
              ShopHistoryEntry(
                id: item.id,
                date: item.date,
                status: item.status ??
                    (item.content.isEmpty ? 'pending' : 'generated'),
                content: item.content,
              ),
          ]),
      onDelete: service.deleteComfort,
    );
  }
}

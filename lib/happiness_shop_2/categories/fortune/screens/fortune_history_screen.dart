import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../common/widgets/shop_history_list.dart';
import '../services/fortune_service.dart';

/// 받은 운세 기록
class FortuneHistoryScreen extends StatelessWidget {
  const FortuneHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isKorean =
        Provider.of<LocaleProvider>(context).locale.languageCode == 'ko';
    final service = FortuneService();

    return ShopHistoryScreen(
      isKorean: isKorean,
      title: isKorean ? '받은 운세' : 'My fortunes',
      categoryId: 'fortune',
      emptyText: isKorean ? '아직 받은 운세가 없어요.' : 'No fortunes yet.',
      stream: service.getUserFortunesStream().map((items) => [
            for (final item in items)
              ShopHistoryEntry(
                id: item.id,
                date: item.date,
                status: item.status ??
                    (item.content.isEmpty ? 'pending' : 'generated'),
                content: item.content,
                caption: item.mood,
              ),
          ]),
      onDelete: service.deleteFortune,
    );
  }
}

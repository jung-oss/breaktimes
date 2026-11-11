import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../providers/locale_provider.dart';
import '../services/comfort_service.dart';
import '../models/comfort_item.dart';

class ComfortHistoryScreen extends StatelessWidget {
  const ComfortHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isKorean =
        Provider.of<LocaleProvider>(context).locale.languageCode == 'ko';
    final service = ComfortService();
    final dateFormat = DateFormat(
      isKorean ? 'yyyy년 MM월 dd일' : 'MMMM dd, yyyy',
      isKorean ? 'ko' : 'en',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isKorean ? '위로 기록' : 'Comfort History'),
      ),
      body: StreamBuilder<List<ComfortItem>>(
        stream: service.getUserComfortsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                isKorean ? '아직 기록이 없습니다.' : 'No comfort letters yet.',
                style: const TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(dateFormat.format(item.date)),
                  subtitle: Text(
                    item.status == 'generated'
                        ? item.content
                        : (isKorean ? '생성 중…' : 'Generating…'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => service.deleteComfort(item.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breaktimes/happiness_shop_2/common/models/shop_catalog_item.dart';
import 'package:breaktimes/happiness_shop_2/common/services/heart_cost_service.dart';
import 'package:breaktimes/happiness_shop_2/common/widgets/pill_button.dart';

void main() {
  group('HeartCost', () {
    test('shop category costs are 1 heart each', () {
      expect(HeartCost.QUOTE, 1);
      expect(HeartCost.MUSIC, 1);
      expect(HeartCost.FORTUNE, 1);
      expect(HeartCost.COMFORT, 1);
      expect(HeartCost.FLOWERS, 1);
      expect(HeartCost.RECIPE, 1);
      expect(HeartCost.TRAVEL, 1);
    });
  });

  group('ShopCatalogItem', () {
    const item = ShopCatalogItem(
      id: 'test',
      titleKo: '제목',
      titleEn: 'Title',
      bodyKo: '본문',
      bodyEn: 'Body',
    );

    test('returns localized title and body', () {
      expect(item.title(true), '제목');
      expect(item.title(false), 'Title');
      expect(item.body(true), '본문');
      expect(item.body(false), 'Body');
    });
  });

  testWidgets('PillButton renders and responds to tap', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PillButton(
            imagePath: 'assets/images/pill/pill_01.png',
            onTap: () => tapped = true,
            isEmpty: true,
          ),
        ),
      ),
    );

    expect(find.byType(PillButton), findsOneWidget);
    await tester.tap(find.byType(PillButton));
    await tester.pump();
    expect(tapped, isTrue);
  });
}

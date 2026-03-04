import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ygo_slot_app/main.dart';

void main() {
  testWidgets('앱이 정상적으로 실행되고 랜딩 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // 랜딩 화면의 타이틀 텍스트 확인
    expect(find.text('유희왕 슬롯'), findsOneWidget);
  });

  testWidgets('랜딩 화면에 시작 버튼과 설정 버튼이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.textContaining('바로 시작'), findsOneWidget);
    expect(find.textContaining('카드 수 설정'), findsOneWidget);
  });

  testWidgets('카드 수 설정 버튼을 누르면 다이얼로그가 열린다', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    await tester.tap(find.textContaining('카드 수 설정'));
    await tester.pumpAndSettle();

    // 다이얼로그 또는 바텀시트가 열리는지 확인
    expect(find.byType(Dialog).evaluate().isNotEmpty || find.byType(BottomSheet).evaluate().isNotEmpty, isTrue);
  });
}

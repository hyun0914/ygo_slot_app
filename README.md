# Yu-Gi-Oh Slot (Flutter)

유희왕 카드 데이터를 기반으로 **카드를 랜덤으로 뽑는 과정을 슬롯(릴)처럼 연출**하고,
**오늘의 3칸 타겟(조건/특정 카드)** 과 결과가 맞으면 "적중"으로 판정해주는 Flutter 앱입니다.
오늘의 타겟은 **하루 동안 고정**됩니다.

> 비공식 팬 프로젝트입니다. Konami 및 Yu-Gi-Oh!와 무관합니다.
> 카드 데이터/이미지 출처: YGOPRODeck API

---

## 배포
- 배포 URL: <https://ygo-slot-app.web.app>

---

## 주요 기능

- 🎲 **랜덤 뽑기 (슬롯 릴 연출)**
    - 모드: 도전(3장) / 기본(5장) / 편안(7장)
    - 릴(슬롯) 애니메이션 + 단계별 정지 연출

- 🎯 **오늘의 타겟 (데일리 슬롯 룰, 하루 고정)**
    - 하루마다 3개의 타겟이 결정됨
    - 날 종류: **일반** / **특별** / **보스** (모드별 확률로 매일 결정)
    - 타겟 유형:
        - **category 타겟**: 레벨/속성/종족/특성/엑스트라/ATK 구간 등
        - **exact 타겟**: 특정 카드 지정 (특별/보스 날에 등장)
    - 뽑기 결과가 타겟에 걸리면 적중 팝업 표시
    - **SharedPreferences**로 날짜+모드별(today × count) 룰 저장

- 🎰 **잭팟 연출**
    - 타겟 3개 전부 적중 시 컨페티 + 스트릭 카운트
    - **보스 잭팟** (보스 날 3장 전부 적중): 별도 임팩트 연출
        - 화면 3방향 컨페티 (중앙·좌상·우상)
        - 풀스크린 골드 플래시
        - BOSS JACKPOT!! 텍스트 오버레이
        - 햅틱 진동 패턴 (heavyImpact × 3)
        - 적중 카드 골드 글로우 애니메이션
        - 전용 다이얼로그 (금색 테마 + `BOSS JACKPOT` 배지)

- 🔁 **연속 뽑기**
    - 5/10/15회 연속 실행
    - 마지막에 적중(0~3개) 분포 요약 팝업

- 📜 **뽑기 기록**
    - 뽑기 이력 확인 페이지

- 📊 **확률 정보**
    - 날 종류별 출현 확률 표
    - 보스 날 잭팟 확률 (정확한 수식 기반)
    - 특별 날·일반 날 조건 적중 확률 범위
    - 일반 날 잭팟 확률 범위

---

## 날 종류 설명

| 날 종류 | 타겟 구성 | 잭팟 조건 |
|---|---|---|
| **일반** | 카테고리 조건 3개 | 3개 전부 적중 |
| **특별** | 특정 카드 1장 + 카테고리 조건 2개 | 3개 전부 적중 |
| **보스** | 특정 카드 3장 | 3장 전부 적중 → 보스 잭팟 연출 |

---

## 기술 스택

- Flutter / Dart
- http : YGOPRODeck API 호출
- shared_preferences : 데일리 룰 및 스트릭 저장(날짜 기준)
- confetti : 잭팟·보스 잭팟 컨페티 연출
- web : AppNetworkImage에서 웹 환경(Flutter Web) 대응을 위해 사용 중

> web 패키지는 앱 전반에서 "직접 UI를 구성하기 위해서"가 아니라,
> 네트워크 이미지 처리(AppNetworkImage)에서 웹 환경 대응/호환 처리용으로 사용됩니다.

---

## 프로젝트 구조

프로젝트는 core / features 중심으로 분리되어 있습니다.

- lib/core/
    - api_client.dart : YGO API 클라이언트(카드 목록 fetch)
    - models/ygopro_card.dart : 카드 모델
    - widgets/
        - app_network_image.dart : 네트워크 이미지 위젯(웹 대응 포함)
        - ygo_card_back.dart : 카드 뒷면 UI 등

- lib/features/random_draw/
    - application/
        - random_draw_controller.dart : 뽑기 로직
        - draw_history_store.dart : 뽑기 기록 저장
    - domain/
        - draw_filter.dart : 뽑기 필터(현재 count 중심)
        - daily_slot_rule.dart : 데일리 룰/타겟 모델 및 생성 로직
        - draw_history_entry.dart : 뽑기 기록 모델
    - presentation/
        - pages/
            - random_draw_page.dart : 슬롯 UI/애니메이션/팝업 등 화면
            - history_page.dart : 뽑기 기록 페이지
            - probability_page.dart : 확률 정보 페이지
        - slot_ui/slot_ui_helpers.dart : 슬롯 UI 헬퍼(라벨/뱃지/색상 등)
        - widgets/ : 화면 구성 위젯들 (card_tile, slot_header, slot_result_dialog 등)

> 핵심은 "UI는 presentation, 규칙/모델은 domain, 동작은 application, 공통은 core"입니다.

---

## 실행 방법

### 1) 의존성 설치

    flutter pub get

### 2) 실행

#### 모바일

    flutter run

#### 웹

    flutter run -d chrome

---

## 데일리 룰 동작 방식

룰은 **날짜 + 모드(카드 수 3/5/7)** 기준으로 고정됩니다.

첫 진입 시 룰이 없으면:

1. 데일리 풀(카드 pool)을 API로 구성
2. 풀 기반으로 오늘의 룰 생성 (날 종류: 일반/특별/보스)
3. SharedPreferences에 저장

이후 같은 날/같은 모드에서는 룰이 유지됩니다.

---

## Hosting

- Firebase Hosting으로 배포했습니다. (Flutter Web build/web 산출물 기준)

---

## 주의 사항 (저작권/면책)

- 본 앱은 비공식 팬 프로젝트입니다.
- Konami 및 Yu-Gi-Oh!와 어떤 형태로도 제휴/승인/후원을 받지 않습니다.
- 카드 데이터/이미지 출처: YGOPRODeck API
- 현재는 YGOPRODeck 이미지 URL을 직접 사용합니다. 추후 캐싱/프록시/자체 호스팅 등으로 개선할 수 있습니다.

---

## API / Terms

- YGOPRODeck API Guide / Terms: https://ygoprodeck.com/api-guide/
- YGOPRODeck API는 호출 제한/정책이 있을 수 있으므로, 과도한 호출을 피하고 공식 가이드를 참고하세요.

---

## License

개인 학습/포트폴리오 목적의 프로젝트입니다.

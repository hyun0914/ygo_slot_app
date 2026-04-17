# Yu-Gi-Oh Slot (Flutter)

유희왕 카드 데이터를 기반으로 **카드를 랜덤으로 뽑는 과정을 슬롯(릴)처럼 연출**하고,
**오늘의 3칸 타겟(조건/특정 카드)** 과 결과가 맞으면 "적중"으로 판정해주는 Flutter 웹 앱입니다.
오늘의 타겟은 **하루 동안 고정**됩니다.

> 비공식 팬 프로젝트입니다. Konami 및 Yu-Gi-Oh!와 무관합니다.
> 카드 데이터/이미지 출처: YGOPRODeck API

---

## 배포
- 배포 URL: <https://ygo-slot-app.web.app>

---

## 주요 기능

### 🎲 랜덤 뽑기 (슬롯 릴 연출)
- 모드: 도전(3장) / 기본(5장) / 편안(7장)
- 릴(슬롯) 애니메이션 + 단계별 정지 연출
- 5/10/15회 연속 뽑기 + 결과 요약 팝업

### 🎯 오늘의 타겟 (데일리 슬롯 룰)
- 하루마다 3개의 타겟이 고정 결정
- 날 종류: **일반** / **특별** / **보스**

| 날 종류 | 타겟 구성 | 잭팟 조건 |
|---|---|---|
| **일반** | 카테고리 조건 3개 | 3개 전부 적중 |
| **특별** | 특정 카드 1장 + 카테고리 2개 | 3개 전부 적중 |
| **보스** | 특정 카드 3장 | 3장 전부 적중 → 보스 잭팟 |

### 🎰 잭팟 연출
- 타겟 3개 전부 적중 시 컨페티 + 스트릭 카운트
- **보스 잭팟**: 화면 3방향 컨페티, 풀스크린 골드 플래시, BOSS JACKPOT 오버레이, 골드 글로우 애니메이션

### 🔊 효과음 (Web Audio API)
- 오디오 파일 없이 Web Audio API 오실레이터로 합성
- 뽑기 시작 / 릴 틱 / 적중 / 잭팟 / 보스 잭팟 효과음
- 음소거 토글 지원

### 🏆 도전과제 (19종)
- 첫 뽑기, 첫 잭팟, 보스 잭팟, 연속 3/7/30일, 누적 뽑기 10/100/1000회 등
- 달성 시 상단 슬라이드 토스트 알림

### 📊 레벨 시스템 (15레벨)
- 뽑기/적중/잭팟 시 XP 획득
- 레벨업 시 풀스크린 애니메이션 연출
- AppBar에 현재 레벨 배지 표시

### 📚 카드 도감
- 뽑은 카드 자동 수집, 수집 카드 그리드 열람
- 검색 및 수집 통계

### 🔖 즐겨찾기
- 카드 상세 화면에서 즐겨찾기 토글
- 즐겨찾기 목록 페이지

### 🗓 주간 챌린지
- 매주 새로운 챌린지 (어둠 속성, 드래곤족, ATK 2000 이상 등 15종 로테이션)
- 진행률 원형 인디케이터 표시

### 📅 스트릭 캘린더
- 최근 5주 플레이/잭팟 달성일 시각화

### 📈 통계 대시보드
- 총 뽑기/잭팟/스트릭/수집 카드/XP 한눈에 확인
- 히트 분포 차트, 최근 30일 플레이 현황

### ⚔️ 배틀 모드
- 뽑은 카드로 랜덤 풀 카드와 ATK 배틀
- 전적 기록

### 👤 계정 및 클라우드 동기화
- 이메일/비밀번호/닉네임으로 회원가입·로그인 (Firebase Auth)
- 로그인 시 Firestore에 게임 데이터 자동 동기화 (레벨·XP·도전과제·도감·스트릭 등)
- 뽑기 완료 시 자동 클라우드 저장
- 메뉴 → 클라우드 저장 / 로그아웃

### 🔔 웹 푸시 알림
- 오늘 아직 뽑지 않았을 때 리마인드 알림 (브라우저 권한 허용 필요)

---

## 기술 스택

| 패키지 | 용도 |
|---|---|
| `flutter` | UI 프레임워크 |
| `http` | YGOPRODeck API 호출 |
| `shared_preferences` | 로컬 데이터 저장 (localStorage on web) |
| `confetti` | 잭팟/보스 잭팟 컨페티 연출 |
| `firebase_core` | Firebase 초기화 |
| `firebase_auth` | 이메일/비밀번호 인증 |
| `cloud_firestore` | 게임 데이터 클라우드 동기화 |
| `web` | AppNetworkImage 웹 환경 대응 |

> 효과음은 `dart:js_interop`으로 Web Audio API를 직접 바인딩해 오디오 파일 없이 합성합니다.

---

## 프로젝트 구조

```
lib/
├── core/
│   ├── api_client.dart               # YGO API 클라이언트
│   ├── models/ygopro_card.dart       # 카드 모델
│   ├── services/
│   │   ├── auth_service.dart         # Firebase Auth 래퍼
│   │   ├── cloud_sync_service.dart   # Firestore 동기화
│   │   ├── sound_service.dart        # 효과음 (Web Audio API)
│   │   ├── notification_service.dart # 웹 푸시 알림
│   │   └── share_service.dart        # 클립보드 공유
│   └── widgets/
│       ├── app_network_image.dart    # 네트워크 이미지 (웹 대응)
│       └── ygo_card_back.dart        # 카드 뒷면 UI
├── features/
│   ├── auth/presentation/pages/auth_page.dart        # 로그인/회원가입 UI
│   ├── random_draw/                                   # 핵심 뽑기 기능
│   ├── achievements/                                  # 도전과제
│   ├── collection/                                    # 카드 도감
│   ├── favorites/                                     # 즐겨찾기
│   ├── level/                                         # 레벨/XP
│   ├── weekly_challenge/                              # 주간 챌린지
│   ├── stats/                                         # 통계 대시보드
│   └── battle/                                        # 배틀 모드
└── main.dart                                          # 앱 진입점 + AuthGate
```

---

## 실행 방법

```bash
flutter pub get
flutter run -d chrome   # 웹
flutter run             # 모바일
```

## 빌드 & 배포

```bash
flutter build web
firebase deploy
```

---

## 주의 사항

- 비공식 팬 프로젝트입니다. Konami 및 Yu-Gi-Oh!와 어떤 형태로도 제휴/승인/후원을 받지 않습니다.
- 카드 데이터/이미지 출처: [YGOPRODeck API](https://ygoprodeck.com/api-guide/)
- 메인 플랫폼은 **Flutter Web**입니다. Android/iOS도 지원하나 일부 기능(Web Audio, 알림)은 웹 전용입니다.

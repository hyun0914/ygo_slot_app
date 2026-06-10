import 'decoder_card.dart';

enum HintJudgment { correct, wrong }

class GuessResult {
  final DecoderCard card;
  final Map<String, HintJudgment> judgments;

  const GuessResult({required this.card, required this.judgments});

  HintJudgment judgment(String key) => judgments[key] ?? HintJudgment.wrong;

  factory GuessResult.compare(DecoderCard guess, DecoderCard answer) {
    HintJudgment cmp(dynamic g, dynamic a) =>
        g == a ? HintJudgment.correct : HintJudgment.wrong;

    return GuessResult(
      card: guess,
      judgments: {
        'monsterType': cmp(guess.frameType, answer.frameType),
        'attribute': cmp(guess.attribute, answer.attribute),
        'levelRankLink': cmp(guess.levelRankLink, answer.levelRankLink),
        'race': cmp(guess.race, answer.race),
        'atk': cmp(guess.atk, answer.atk),
        'def': cmp(guess.def, answer.def),
      },
    );
  }
}

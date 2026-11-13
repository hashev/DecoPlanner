# Независимый VPM: межуровневый подъём и повторный спуск

`vpmb-redescent-normalized.json` содержит60полных профилей:
два варианта × OC/CCR/bailout × metric/imperial × консерватизм0–4.
Тестируется конечная таблица и пройденная физическая история, включая реальные
остановки на промежуточном подъёме, последующую выдержку и новый спуск.

- Above-zone:45→36→42m либо150→120→140ft, длительности12/4/4min.
- With-stops:45→12→30m либо150→40→100ft, длительности12/4/4min.
  Каждый из30таких профилей содержит1–4реальные промежуточные остановки.
- CCR above-zone использует lowSP.7/hold1.3 и switches1.4/.7bar;
  with-stops — SP.7bar, чтобы сохранить non-clipped область внешнего адаптера.
- Bailout происходит после последнего введённого уровня, из фактического
  CCR-state и фактического runtime, а не суммы введённых длительностей.

## Оркестрация внешнего источника

`reference_vpm_multilevel.py` использует исходные процедуры pinned bwaite/vpmb
через существующий normalized adapter. Уравнения crushing/regeneration,
Boyle, gradient/CV и итерационный stop search исполняет внешний код.
Продуктовое ядро и Dart output не импортируются и не читаются генератором.

При вводе более мелкого уровня сначала выполняются полные внешние CV-trials
до поверхности. Только финальный физический проход останавливается на целевой
глубине. Далее выдержка заканчивается на ceil(arrival runtime)+duration;
следующий спуск включает движение в заданную длительность. Это явная
нормализация API, а не обещание native multilevel поддержки upstream.

Upstream рассчитан на один финальный подъём и сбрасывает Max_Actual_Gradient
при каждом начале decompression_loop. Для нескольких частичных подъёмов одного
dive адаптер накапливает максимум реальных физических градиентов по всему dive;
trial-газы/состояния не становятся actual history. Повторный спуск не начинает
новое погружение. Эта нормализация сохраняет состояние для независимой SI0
excitation finalization, уже принятой в остальных VPM reference-наборах.

В последнем сегменте публикуется то же finalized surface state, что и в
finalState. Необработанный surface snapshot source сохранён отдельно в
`raw_surface_bubble`; отличие не скрыто увеличением tolerance.

Изначальный straight-travel candidate и первый raw-surface snapshot остаются
диагностическими материалами в local/oracles/diagnostic-candidates. Они не
используются как ожидания для другой постановки задачи.

## Проверяемые величины

Каждый physical segment: phase, начало/конец глубины, длительность/runtime,
состав/mode/SP, все16N2/He тканей и независимая кислородная quadrature.
На каждом сегменте дополнительно сверяются max crushing, adjusted initial
radii, ambient/tension onset; в финале — все bubble vectors/saved tissue/scalar
поля. Проверяются runtime/ascent/deco/max trial first stop, JSON round-trip
и неизменность исходного запроса. Все60профилей проходят со штатным
CalculationBudget100000, без повышения лимита в тесте.

Допуски заданы прежним контрактом до сравнения: time1e-7min,
tissues/gradients1e-8bar, radius1e-15m, CNS1e-10, OTU1e-9.
61focused tests включают отдельную проверку всех60комбинаций.

## Повторение

```sh
local/oracles/python-env/bin/python tool/capture_vpm_redescent.py
python3 tool/audit_vpm_redescent_reference.py
```

Внешний оригинал проверяется побайтно против git object закреплённого commit.
Registry фиксирует полный fixture SHA и хеши собственных adapters/generator;
обычные Dart tests и read-only audit работают без внешнего checkout.
Общие соглашения — [reference normalization](reference-normalization.md).

Повторный полный захват побайтно совпал:
`1a11ff55e763454c81ae3ddc8e76c01d7587e4ce2a1c0848f7f5fb4c46de0bf6`.
[Машиночитаемая запись](vpm-redescent-reference.json); полный core suite997/997 PASS.

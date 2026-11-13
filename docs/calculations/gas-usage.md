# Расход, баллоны и резервы

Статус: формулы подтверждены байткодом; OC/CCR/bailout итоговые объёмы проверены
вызовом оригинальных postprocessing-методов W.I(), R.B(), Y.K(). Контроллеры
выполнялись на настоящем JavaFX toolkit без показа окна.

## OC и bailout

Постоянная глубина:

```text
ambientATA = (depth + surface)/unitsPerATA
volume = RMV * ambientATA * minutes
```

Движение:

```text
minutes = abs(endDepth-startDepth)/rate
meanAmbientATA = ((startDepth+endDepth)/2+surface)/unitsPerATA
volume = RMV*meanAmbientATA*minutes
```

Подготовитель использует bottom RMV на пользовательских сегментах, ядро — deco RMV
на добавленном подъёме и остановках. `d.W` хранит расход сегмента. Строка таблицы
может объединять расход предыдущего движения и выдержки; не суммировать оба
представления одновременно. W.I()/Y.K() суммируют d.W по индексу газа, затем
округляют объём метрически через rint до целых литров, имперски F.B до 0.1 CuFt.
Y пропускает отображение газа с нулевым расходом.

`h.H` — объём, `h.Q` — **округлённое время на газе**, `h.C` — **число добавленных
constant-depth deco stops**. Эти поля не являются резервом. Итоги после
postprocessing отдельно сохранены в JSON `derived.gas_usage`; исходный J
до postprocessing содержит ещё не заполненные статистические поля.

## CCR

Оригинальный R.B() считает только кислород:

```text
enteredTime = sum(segment.duration for segment.C == true)
oxygenLiters = enteredTime*OCRbottom + totalAscentTime*OCRdeco
```

Metric: rint до целого литра; imperial: перевод L→CuFt и округление до 0.1.
При нескольких пользовательских подъёмах enteredTime и totalAscentTime могут
перекрываться; формулу следует переносить как наблюдаемое поведение, а не
считать общим интегратором метаболического расхода. Отдельного расчёта diluent
volume в этом методе нет. `ccr-gas-ratio-controller` даёт 27 L для указанного
45m/25min SP1.3-профиля с OCR .7/.5.

## Баллоны

Источник Tank.java (локально: `../../local/reference/analysis/decompiled/source/decoplanner/Tank.java`).

Metric tank: working pressure F в bar, water volume B в L; capacity C ≈ B*F.
Imperial tank: C — заявленные CuFt при working PSI F; B=C/F (CuFt/PSI).
Tank.G() возвращает capacity-per-pressure в текущих единицах:

```text
same units -> B
metric tank in imperial -> litersToCuFt(C)/barToPSI(F)
imperial tank in metric -> CuFtToLiters(C)/PSIToBar(F)
requiredPressure = JavaRound(displayGasVolume/Tank.G())
```

Это линейная оценка, без EOS-поправки смешивания и без резерва. Пример
`oc-gas-tank-controller`: 1719 L, 2x12L → 72 Bar. Во входных данных фиксируются
название баллона и actual настройки; произвольные prefs пользователя не читаются.

## Есть ли расчёт резервов

В этой поставке W/Y объявляют `reservesButton`, но initialize скрывает кнопку
через setVisible(false). Обработчика расчёта резервов не найдено. Подпись
интерфейса прямо говорит «one diver, no reserves». По всему набору исходников
не обнаружен самостоятельный расчёт rock-bottom/minimum-gas/reserve.

Итог: подтверждено наличие **расхода без резервов**, отсутствует обнаруженная
исполняемая функция резервов. Создание резервной модели для нового планера —
отдельное проектирование; нельзя выдавать h.Q или процент произвольно за
восстановленный алгоритм GUE.

## Проверки

- `oc-gas-ratio-controller`: 30m/20min air → 1719 L.
- `oc-double-rmv-controller`: обе RMV ×2 дают двойной объём до округления.
- `oc-zero-rmv-controller`: ядро падает с NumberFormatException: нулевой объём
  форматируется пустой строкой и затем передаётся Double.parseDouble. Это
  подтверждённый дефект граничного случая, а не успешный нулевой расход.
- `oc-imperial-gas-controller`: оригинальный imperial путь и CuFt.
- `bailout-gas-ratio-controller`: учитываются только сегменты с d.W; CCR-часть
  не притворяется OC-расходом.
- Сумма d.W по газу проверяется против h.H после установленного округления;
  соответствующий газ и его состав сверяются по исходному индексу.

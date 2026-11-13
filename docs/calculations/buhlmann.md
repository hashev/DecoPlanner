# Bühlmann B/C: ткани, GF и остановки

Статус формул и таблиц: подтверждено байткодом и выполнением оригинала.
Полные профили проверяются отдельно от изолированных формул.

Источники: S.java (локально: `../../local/reference/analysis/decompiled/source/decoplanner/S.java`) (OC),
A.java (локально: `../../local/reference/analysis/decompiled/source/decoplanner/A.java`) (CCR),
S bytecode (локально: `../../local/reference/analysis/bytecode/decoplanner/S.txt`),
A bytecode (локально: `../../local/reference/analysis/bytecode/decoplanner/A-upper.txt`).
Исходные сигнатуры приведены в `analysis/bytecode/symbols.json`.

## Обозначения и таблицы

16 компартментов, каждый с N2 и He. Давления внутри ядра представлены единицами
глубины: `surface` = 10.1325 метрически либо 33 имперски. Время — минуты.
`waterVapor` для Bühlmann = 0.627 либо 2.041. Все коэффициенты и периоды находятся
в buhlmann.json (локально: `../../local/reference/analysis/coefficients/buhlmann.json`). Файл содержит таблицы
B/C отдельно для OC/CCR; они совпадают между режимами.

N2 half-times: 5, 8, 12.5, 18.5, 27, 38.3, 54.3, 77, 109, 146, 187, 239,
305, 390, 498, 635. He half-times: 1.88, 3.02, 4.72, 6.99, 10.21, 14.48,
20.53, 29.11, 41.2, 55.19, 70.69, 90.34, 115.29, 147.42, 188.24, 240.03.
`k = ln(2)/halfTime`.

`a` хранится в bar, затем умножается на **10.0** либо **32.5684678**, а не на
10.1325/33. `b` безразмерен. В этой реализации варианты B/C меняют N2 a;
He a и обе b-таблицы общие. Нельзя заменять эти значения таблицей из другого
планера без проверки по извлечённым данным.

Сопоставление массивов:

| Смысл | S | A |
|---|---|---|
| half N2, k N2, tissue N2 | A, O, Q | A, N, P |
| half He, k He, tissue He | P, L, D | O, L, D |
| aN2 bar/depth, bN2 | G/M, K | G/M, K |
| aHe bar/depth, bHe | C/V, U | C/U, T |

## Начальное состояние

`J.H()`: N2[i] = O.J(), He[i] = 0, CNS=OTU=0.
Установка давления через `O.B(surface)` пересчитывает O.J() как
`(surface-waterVapor)*0.79`. Reset defaults могут хранить другое готовое значение;
поэтому контрольные случаи всегда сохраняют действительные настройки.
Повторные погружения используют отдельный алгоритм surface interval — он не
эквивалентен обычному выдерживанию на воздухе с исходным k.

## Постоянная глубина: Haldane

Для одного газа и компартмента:

```text
Pnew = Pold + (Pinspired - Pold) * (1 - exp(-k * dt))
```

OC: `Pinspired = (depth + surface - waterVapor) * gasFraction`.
S.E(DDDD) — чистая формула; S.A(DIDDD) — N2, S.B(DIDDD) — He.
A.F(DDDD) — чистая формула CCR-класса.

CCR: остаточное inert pressure = `depth + surface - waterVapor - setpoint*unitsPerATA`.
Доля He среди инертных = `diluentHe/(diluentHe+diluentN2)`; остаток — N2.
На постоянной глубине A.A(DDD) прямо использует этот остаток, без той же
защиты отрицательного значения, которая есть при движении. Ввод должен исключать
физически невозможные setpoint; точное поведение ошибочной ветви тестируется отдельно.

## Линейное изменение глубины: Schreiner

```text
Pnew = Pi0 + R*(dt - 1/k) - (Pi0 - Pold - R/k)*exp(-k*dt)
```

OC: `Pi0=(startDepth+surface-waterVapor)*fraction`, `R=depthRate*fraction`.
Знак скорости нормализуется по направлению движения. dt=(end-start)/signedRate.
Чистая формула: A/S.A(DDDDD), порядок `(Pi0,R,dt,k,Pold)`.

CCR: вычислить inert pressure в обоих концах с тем же setpoint, каждый отрицательный
остаток зажать к 0; разделить по отношению He/N2 diluent; R = разность inspired
pressure между концами / dt. На начальном спуске используется low setpoint,
на заданном уровне — высокий. Это переключение создаёт два сегмента, а не один
непрерывный setpoint-профиль.

Проверка: для `oc-air-30m-20min` все 16 N2 значений после спуска 3 мин со скоростью
10 м/мин и последующей выдержки 17 мин совпали с независимым вычислением формул
до 1e-12 единицы глубины. Контроль `surface-equilibrium` даёт неизменное давление;
`schreiner-linear-pressure` проверяет чистую функцию отдельно.

## Смешанные коэффициенты, M-value и потолок

Для каждого компартмента с total = N2+He:

```text
aMix = (aN2*N2 + aHe*He) / total
bMix = (bN2*N2 + bHe*He) / total
Mvalue(Pambient) = Pambient/bMix + aMix
ceilingAbs = max(0, (total - aMix*GF)/(GF/bMix - GF + 1))
ceilingDepth = ceilingAbs - surface
ceiling = max_i(ceilingDepth[i])
```

Потолок возвращает S.D() / A.C(). Он может быть отрицательным после вычитания
surface; это трактуется как отсутствие обязательной первой остановки.
Weighted helpers: S/A.B(IDD) — aMix, S/A.A(IDD) — bMix.
При total=0 оригинал не имеет общей защиты от деления 0/0; новый планер должен
обрабатывать такое состояние явно и отличать это улучшение от поведения оригинала.

В таблице показываются максимумы `total/Mvalue` и
`(total-Pambient)/(Mvalue-Pambient)`, умноженные на 100 и округлённые.
Табличный GF нельзя путать с текущей настройкой разрешённого потолка.

## Интерполяция GF

На первом поиске используется GF low. После выбора первой глубины firstStop:

```text
slope = (GFhigh - GFlow) / (0 - firstStop)
GF_for_next_depth = nextDepth*slope + GFhigh
```

При проверке ухода с текущей остановки применяется GF **следующей** глубины.
Не интерполировать по времени и не привязывать автоматически к rounded off-gassing
start: это отдельные величины. Мультиуровневый профиль может сохранить/обновить
наклон, а при новом спуске slope сбрасывается. Точные ветви вставки остановок
расположены в A/S.A(J), см. ниже.

## Начало off-gassing и первая остановка

A/S.B(D): для каждой ткани ищет глубину, где tissue total пересекает ambient
при подъёме на текущем газе. Используется бискекция (100 итераций, половина
интервала менее 0.001 минуты либо точный ноль). Максимум глубин — start of deco zone.
В начальной проверке скобок есть отличающиеся выражения от основной невязки;
для точного переноса сохранять ветвь из исходного метода, не заменять абстрактным
root solver. При превышении итераций исходник печатает ошибку 733.

Первая candidate stop из потолка c:

```text
if c <= 0: candidate = 0
else if c % step <= step*0.1:
    candidate = floor(c); skipProjectedSearch = true
else:
    candidate = JavaRound(c/step + 0.5)*step
```

Если candidate глубже off-gassing start, ядро показывает first-stop conflict
с предложением увеличить GF low. При отсутствии skipProjectedSearch применяется
projected ascent: симулировать ткани до candidate, сравнить каждую с разрешённым
M-value при текущем GF, сдвигать candidate глубже на step до разрешения.
Затем может выполняться проверка ухода ещё на один step мельче. Вариант CCR
дополнительно вычисляет округлённую границу off-gassing. Исходный метод A.A(II)
содержит эти отличия; OC и CCR нельзя объединять, не проверив ветви.

Если включён последний стоп 6m/20ft, candidate не бывает мельче двойного step,
а из этой глубины следующий переход идёт прямо к поверхности.

## Цикл остановок (нормальный OC-профиль)

```text
first = choose_first_stop(current_tissues, current_depth, GFlow)
set GF slope if first > 0
while true:
    ascend using Schreiner to first/next stop
    append movement segment with tissue snapshot, gas and gas usage
    account ascent time; first movement is excluded from internal deco-time counter
    if stop <= requested_target_depth: break
    choose eligible deco gas at or shallower than its switch depth
    select minimum stop duration override if present
    choose next depth (one step shallower, or 0 from final double-step)
    set GF for next depth
    save current tissues
    trial duration = floor(runtime) + minimumStop - runtime
    repeat:
        apply Haldane for trial duration at current stop
        if roundHalfUp(ceilingDepth, 2) <= nextDepth: accept
        else: duration += minimumStop; extend tissues by minimumStop
    restore tissues from before the trial
    apply accepted duration, create row and constant-depth segment
    update CNS/OTU, runtime, ascent/deco counters
    continue at next depth
append a special surface row and apply the original runtime rounding
```

В OC `minimumStop` в этом цикле — `Math.round(O.£)` (int), а CCR в отдельных
методах использует float O.£ непосредственно. Нулевой минимум может дать зависание.
Для timed trial сравнение потолка идёт после округления HALF_UP на 2 знака;
суммарная таблица использует и другие правила. Случай 30м/20мин завершает
фактический подъём примерно на 27.333 мин, но surface row округляет runtime до 28.
Это не дополнительная физиологическая остановка.

## Мультиуровень, газ и ошибки

A/S.A(J) идёт по сегментам, сохраняет ткани после каждого, вставляет обязательные
остановки перед заданным подъёмом, временно отделяя будущие сегменты и сдвигая
их start/end runtime. При развороте на спуск сбрасывает slope; при продолжении
подъёма сохраняет флаги первого/следующего стопа. Поля флагов CFR локальные,
поэтому для полного воспроизведения использовать ветвления исходного метода
и контрольные мультиуровневые случаи, а не только простой цикл выше.

Газы не выбираются максимизацией O2. Они перебираются в порядке списка, с
проверкой switch depth, роли и глубины текущего deco gas. У OC min-stop override
берётся из выбранного h.P. Порядок входного списка поэтому существенен.

Ядро при невозможном off-gassing gradient только печатает диагностику перед
циклом; это не гарантирует прекращения. Таймаут и отказ по некорректным входам
должны быть явными в новой реализации. UI-проверки не являются частью всех
низкоуровневых функций; они описываются отдельно от поведения ядра.

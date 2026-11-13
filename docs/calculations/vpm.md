# VPM-B: восстановленное ядро

Статус формул: подтверждено байткодом; основные режимы и консерватизм подтверждены
выполнением. Непроверенные ветви и дефекты перечислены отдельно — модель нельзя
считать стандартной VPM-B без различий.

Источники: H.java (локально: `../../local/reference/analysis/decompiled/source/decoplanner/H.java`) для OC,
D.java (локально: `../../local/reference/analysis/decompiled/source/decoplanner/D.java`) для CCR,
H bytecode (локально: `../../local/reference/analysis/bytecode/decoplanner/H-upper.txt`),
D bytecode (локально: `../../local/reference/analysis/bytecode/decoplanner/D-upper.txt`).
Все условные переходы этих классов с сигнатурами и строками `javap` сохранены
в vpm-branches.json (локально: `../../local/reference/analysis/maps/vpm-branches.json`).
Параметры после инициализации для 5 уровней и 2 ядер:
vpm.json (локально: `../../local/reference/analysis/coefficients/vpm.json`).

## Параметры, единицы и тканевая модель

N2/He half-times те же, что в справочнике Bühlmann; `k=ln(2)/half`.
H.B(DDDDD)/D.B(DDDDD) — Schreiner, H.C(DDDD)/D.D(DDDD) — Haldane.
OC/CCR inspired pressures определяются аналогично соответствующим режимам
Bühlmann, но VPM вычитает water vapor **0.493/1.607**, а не 0.627/2.041.
В потолок дополнительно входит other-gases pressure:

```text
other = (102/760)*unitsPerATA
Pa(xDepth) = xDepth/unitsPerATA * 101325
Depth(xPa) = xPa/101325 * unitsPerATA
```

| Параметр | Значение оригинала |
|---|---|
| gamma, surface tension | 0.0179 |
| gammaC, skin compression | 0.257 |
| onset impermeability | 8.2 ATA |
| lambda | 6500 / 33 * 101325 Pa |
| regeneration tau | 20160 минут |
| conservatism scale, indices 0..4 | 1.0, 1.1, 1.15, 1.25, 1.35 |
| initial radius N2 / He | 0.45 / 0.55 микрометра × scale |

Обозначения gamma/gammaC соответствуют роли в формулах; все размерные
преобразования надо сохранять явно. Reset O и O.A(index) пересчитывают радиусы.

## Карта массивов

Все массивы имеют 16 элементов, индекс 0..15.

| Смысл | H (OC) | D (CCR) |
|---|---|---|
| tissue N2 / He | T / q | S / p |
| half N2 / He; k N2 / He | Y/n; k/D | X/m; j/D |
| initial radius N2 / He | c / I | b / I |
| adjusted initial radius N2 / He | p / X | o / W |
| max crushing pressure N2 / He | U / s | T / r |
| regenerated radius N2 / He | d / K | c / K |
| adjusted crushing pressure N2 / He | _ / E | Z / E |
| initial allowable gradient N2 / He | m / S | l / R |
| current allowable gradient N2 / He | f / M | e / M |
| Boyle-compensated gradient N2 / He | F / a | F / _ |
| max actual gradient | O | N |
| surface phase volume time | W | V |
| total phase volume time | C | C |
| ambient/tension at onset | g / o | f / n |
| saved deco-start N2 / He | r / P | q / O |

Остальные скаляры: context J H.b/D.a; surface H.H/D.H; CNS H.i/D.h; OTU L;
other H.j/D.i; vapor H.l/D.k; maximum first stop H.Q/D.P;
start-of-zone runtime H.V/D.U; saved runtime H.e/D.d; saved segment count A;
H.N — округлённый min-stop. H.R/D.Q сохраняют GF low, но GF не заменяет
VPM-пузырьковые градиенты.

## Crushing pressure при спуске

Для каждого газа/ткани:

1. `tension = N2+He+other`, `crush = ambient-tension`.
2. До onset=8.2 ATA максимальный crush обновляется напрямую.
3. При пересечении onset найти время t, где `ambient(t)-tension(t)-onset=0`:
   бискекция в интервале движения, tissue(t) через Schreiner.
4. Сохранить ambientOnset и tensionOnset. Для каждого начального радиуса R0:

```text
Ronset = 1 / (onsetPa/(2*(gammaC-gamma)) + 1/R0)
A = ambientPa - ambientOnsetPa + tensionOnsetPa + 2*(gammaC-gamma)/Ronset
B = 2*(gammaC-gamma)
C = tensionOnsetPa * Ronset^3
R = root(A*R^3 - B*R^2 - C = 0,
         lower=B/A, upper=Ronset)
crushPa = onsetPa + ambientPa - ambientOnsetPa
          + tensionOnsetPa*(1 - Ronset^3/R^3)
maxCrush = max(previousMaxCrush, Depth(crushPa))
```

H.A(DDD[D[D)/D.A(DDD[D[D) выполняют обновление; H/D.A(DDDIDD) — поиск onset.
Массивы до спуска нужны для правильного вычисления промежуточных tension.

## Regeneration и исходные градиенты перед декомпрессией

Для каждой ткани/газа, `C=Pa(maxCrush)`, `R0=adjustedInitialRadius`, t=текущее
время погружения:

```text
Rcrushed = 1/(C/(2*(gammaC-gamma)) + 1/R0)
Rregen = R0 + (Rcrushed-R0)*exp(-t/tau)
ratio = Rcrushed*(R0-Rregen)/(Rregen*(R0-Rcrushed))
adjustedCrush = Depth(C*ratio)
Ginitial = Depth(2*gamma*(gammaC-gamma)/(Rregen*gammaC))
Gallow = Ginitial
```

Методы: H/D.F(D) для regeneration; H.B()/D.A() для градиентов.
Прямое применение при C=0 может дать выражение 0/0; нельзя автоматически
выдавать это за физический результат. Низконагруженные случаи входят в проверку.

## Потолок и расширение пузырька

При `total=N2+He>0`:

```text
Gmix = (G_N2*N2 + G_He*He)/total
ceiling = max_i(max(0, total+other-Gmix)-surface)
```

При total<=0 используется min(G_N2,G_He). H.E()/D.E() берут current allowable
(до Boyle), H.C()/D.B() — Boyle-compensated градиенты для ухода со стопа.

Для каждого следующего стопа применяется Boyle compensation. Отправная глубина
в H.A(DDD)/D.A(DDD) принудительно заменяется сохранённой maximum first stop,
а не используется как переданный первый аргумент. Для каждого газа:

```text
P1 = Pa(maximumFirstStop + surface)
P2 = Pa(currentStop-step + surface)
R1 = 2*gamma / Pa(Gallow)
C = (P1 + 2*gamma/R1)*R1^3
R2 = root(P2*R2^3 + 2*gamma*R2^2 - C = 0,
          lower=R1, upper=R1*(P1/P2)^(1/3))
Gboyle = Depth(2*gamma/R2)
```

## Critical-volume iteration

Порядок H/D.A(II): regeneration → allowable gradients → сохранить ткани/runtime/
газ → найти начало deco zone → пробно дойти до него → trial schedule.
Первая глубина округляется `rint(ceiling/step + 0.5)*step` (ties-to-even),
в отличие от ряда округлений Bühlmann. Слишком глубокая первая остановка
заканчивает процесс через System.exit(1).

Projected-ascent helper возвращает скорректированную candidate depth. В основном
методе H/D результат вызова **отбрасывается**; это подтверждается `pop2` в байткоде.
Не приписывать исправляющее действие проверке, результат которой не использован.

Trial schedule последовательно обновляет ткани, переключает газы, применяет
Boyle compensation и накапливает время до выхода. Далее рассчитывается surface
phase volume time по конечным тканям. Обозначим inspiredSurfaceN2 = S0:

```text
if N2 > S0:
    surfaceTime = (He/kHe + (N2-S0)/kN2)/(He+N2-S0)
else if N2 <= S0 and He+N2 >= S0:
    t0 = ln((S0-N2)/He)/(kN2-kHe)
    integral = He/kHe*(1-exp(-kHe*t0))
             + (N2-S0)/kN2*(1-exp(-kN2*t0))
    surfaceTime = integral/(He+N2-S0)
else:
    surfaceTime = 0
phaseTime[i] = decoPhaseDuration + surfaceTime[i]
```

Если `abs(phaseTime[i]-previousPhaseTime[i]) <= 1.0` **хотя бы для одного** i,
оригинал считает итерацию сошедшейся. Вариант «все ткани» здесь был бы изменением
алгоритма. Если critical volume отключён, принимается первый trial.

Если не сошлось, для каждого газа и ткани в Pa:

```text
lambdaPa = 6500/33*101325
T = decoPhaseDuration + surfaceTime[i]
B = GinitialPa + lambdaPa*gamma/(gammaC*T)
C = gamma^2*lambdaPa*adjustedCrushPa/(gammaC^2*T)
Gallow = Depth((B + sqrt(B^2 - 4*C))/2)
```

Восстановить ткани в deco zone, runtime и газ и повторить trial. Внешний цикл
не имеет собственного счётчика/предела итераций. На принятом расписании ядро
возвращает исходное состояние перед подъёмом и строит окончательные сегменты
и строки с расходом и кислородной нагрузкой.

## Длительность остановки и завершение

OC H.C(DD): округляет runtime к `rint(runtime/N + 0.501)*N`, выдерживает до
следующей разрешённой глубины, добавляет N минут, пока Boyle ceiling глубже
nextDepth. Против невозможного off-gassing gradient есть проверка с System.exit(1).
CCR D.D(DDD) использует setpoint и float O.£; формула времени аналогична, но
с отдельными CCR-параметрами. Ткани trial обновляются непосредственно — нельзя
заменить H.C(DD) реализацией Bühlmann, которая восстанавливает снимок после поиска.

При переходе к следующему сегменту сохраняется state bubble/crush; при новом
спуске после подъёма сбрасываются некоторые границы deco zone. Движение и
inspired-gas логика CCR соответствует D.B(DDDD)/D.B(DDD), а bailout использует H
и подготовку Y, как описано в [modes.md](modes.md).

## Численный поиск корня

H/D.A(DDDDD) решает `A*x^3-B*x^2-C=0` safeguarded Newton/bisection:

- проверить знаки на концах; при неправильных скобках напечатать 3565/3575,
  но не обязательно прекратить вычисление;
- если endpoint невязка 0, вернуть endpoint;
- старт в середине; выбрать Newton, если шаг остаётся в скобках и достаточно
  уменьшает невязку, иначе bisection;
- вернуть при неизменности double либо abs(step)<1e-12;
- максимум 100 итераций; при исчерпании напечатать ошибку и вернуть последнюю оценку.

Onset/deco-zone bisection также ограничена 100 шагами с порогом 0.001 минуты.
При переносе различать численную ошибку и предупреждение исходника. Проверены
корень кубического выражения, endpoint и неверные скобки для обоих ядер.
Неправильные скобки могут вернуть число вне интервала — это дефект контракта,
не разрешённый результат нового root solver.

## Проверенное покрытие

Профиль 45m/25min, trimix21/35, deco50%/21m и O2/6m для OC/bailout;
CCR SP1.3 без дополнительных переключений. Фактический runtime по indices 0..4:

| Режим | 0 | 1 | 2 | 3 | 4 |
|---|---:|---:|---:|---:|---:|
| OC | 45 | 47 | 48 | 49 | 52 |
| CCR | 42 | 43 | 44 | 45 | 47 |
| Bailout | 44 | 45 | 45 | 47 | 48 |

В каждом случае сохранены все static-массивы ядра и снимки тканей сегментов.
Это покрытие нормальных профилей, а не доказательство всех error branches.
Повторные погружения и высота рассматриваются отдельно: в оригинале обнаружены
подозрительные индексы и порядок инициализации, требующие фиксации реальных ошибок.

Дополнительные проверки: `vpm-ccr-setpoint-switch` = 47 мин, с сохранёнными
SP1.5/SP0.7 в сегментах; `vpm-oc-lost-oxygen` = 52 мин против 48 с O2;
`vpm-oc-no-critical-volume` = 55 мин; no-deco = 11 мин; multilevel = 48 мин.
Проверен также явный CCR→OC переход в bailout. В H, в отличие от S, отсутствует
финальное переключение `J.U=J.h` при последнем сегменте с O>0; поэтому для
bailout на H нельзя автоматически переносить эту особенность S. Точный список
сегментов и газов каждого случая находится в JSON, включая ввод и final static state.

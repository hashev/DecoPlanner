# Высота и повторные погружения

Статус: формулы подтверждены байткодом; нормальные и ошибочные случаи сохранены
как результаты выполнения оригинала. Ветви OC и CCR VPM различаются.

## Барометрическая формула

Источник F.A(D), копии есть также в private instance C(D) классов H/D.
Для метрической высоты z в метрах:

```text
h = z/1000
geopotential = h*6369/(h+6369)
T = 288.15 - 6.5*geopotential
pressureDepth = 10*exp(ln(288.15/T)*(9.80665*28.9644/8.31432)/(-6.5))
```

Для imperial: h=z/3280.839895 и множитель 33 вместо 10.
На нулевой высоте получается **10.0**, не 10.1325. Это соглашение именно этой
реализации; не смешивать эквивалент bar/ATA при переносе.
Проверенные результаты F.A: 0м→10; 2000м→7.8461793948306475;
8848м→3.10892761312327. UI W/R/Y ограничивает высоту примерно Эверестом и требует
исходную acclimatized altitude ниже текущей; низкоуровневая формула сама эти
границы не обеспечивает.

## Акклиматизация Bühlmann

A/S.F() вызывается после установки текущего J и копирования начальных тканей.
Если acclimatized и первый dive: He=0, N2=(pressureAtAltitude-vapor)*0.79.
Если не acclimatized:

1. На первом dive инициализировать ткани при исходной высоте.
2. Пройти линейное изменение surface pressure от исходной до новой высоты
   за `hoursToAltitude*60` минут через Schreiner с R=dPressure/dt*0.79.
3. Выдержать `hoursAtAltitude*60` на воздухе через Haldane.
4. Установить глобальный surface через O.B; план хранит своё surface в J.D.

Для повторного dive часть инициализации пропускается по J.M, но ветвь travel
может снова применить переход; переносить это как автоматическую акклиматизацию
между каждым dive без проверки нельзя. Нулевое время перемещения даёт деление
на ноль в исходной формуле; необходим явный контракт нового ядра.

## VPM на высоте: установленное поведение

H.A(J) вызывает H.F() **до** присвоения H.b=J. В H.F() читается H.b.M.
В свежей JVM это NullPointerException: контрольные `altitude-vpm-acclimatized`
и `altitude-vpm-travel` сохраняют стек. Причина подтверждена байткодом; это не
отсутствующая JavaFX-зависимость. Bailout тоже использует H.

D.F() не обращается к контексту таким же образом; `altitude-vpm-ccr` выполняется.
Она рассчитывает radius adjustments после изменения pressure, однако последующее
D.A(J) заново копирует S/p из J.Q/J. Поэтому часть tissue-инициализации D.F()
перезаписывается; для неакклиматизированной высоты нельзя считать успешный exit
доказательством сохранения travel exposure. Это ограничение оригинала, требующее
отдельного решения при создании нового планера.

Предусмотренная формула radius adjustment для каждого газа в VPM:

```text
deltaPa = Pa(tissueN2 + other - altitudePressure)
GcritPa = 2*gamma*(gammaC-gamma)/(Rinitial*gammaC)
if deltaPa > GcritPa:
    Rcompressed = 2*gamma*(gammaC-gamma)/(deltaPa*gammaC)
    Radjusted = Rinitial + (Rinitial-Rcompressed)*exp(-wait/tau)
    Rinitial = Radjusted
else:
    Ralt = 1/(deltaPa/(2*(gamma-gammaC)) + 1/Rinitial)
    Rinitial = Rinitial + (Ralt-Rinitial)*exp(-wait/tau)
    Radjusted = oldInitial
```

Ткани перехода вычисляются Schreiner и Haldane, как выше. Точная последовательность
обновления и последующего перезаписывания — часть поведения сборки, а не образец
правильной реализации высоты VPM.

## Surface interval Bühlmann

M.A(minutes, previousDiveNumber) выбирает A/S по O.S, передаёт конечные ткани
предыдущего J, затем J.E() копирует результат в следующий план.
Целевое N2=(previousContext.surface-vapor)*0.79, He=0. k умножается на временной
коэффициент восстановления:

```text
phase1(n): for i=0..n inclusive: one minute with k*(0.9-0.005555*i)
phase2(n): n minutes with k*0.65
phase3(n): for i=0..n inclusive: one minute with k*(0.65+0.0020833*i)
phase4(n): n minutes with k*0.9

if minutes<=45: phase1(minutes)
else if minutes<=60: phase1(45); phase2(minutes-45)
else if minutes<=180: phase1(45); phase2(15); phase3(minutes-60)
else: phase1(45); phase2(15); phase3(120); phase4(minutes-180)
```

Инклюзивные циклы означают, что interval=0 всё равно выполняет одну минуту
изменения тканей; до 60 добавляется одна, после phase3 — две дополнительные
минуты относительно введённого интервала. Это подтверждено байткодом `<=`
и сравнением входных тканей второго погружения с выходом первого.

CNS: `previousCNS * pow(0.5, (minutes/60 integer)/1.5)`.
OTU: сохраняется до `(minutes/60 integer)>=24`, затем 0.
Поэтому 0 и 45 минут не изменяют CNS; 60 минут дают один час в формуле.
Это наблюдаемые детали, а не рекомендуемый алгоритм восстановления.

## Surface interval VPM

H/D.A([D,[D,int) сначала копирует ткани, применяет обычный Haldane на воздухе
за заданные минуты (без фаз .65/.9), затем обновляет adjusted radii по
максимальному actual gradient, initial allowable gradient и crushing pressure.
Для каждого газа, если maxActualGradient > initialAllowable:

```text
Rnew = 2*gamma*(gammaC-gamma)
       /(Pa(maxActualGradient)*gammaC - gamma*Pa(adjustedCrush))
Radjusted = Rinitial + (Rinitial-Rnew)*exp(-interval/tau)
```

Иначе Radjusted=Rinitial. Затем max crush/actual очищаются.
D.B(D) правильно перебирает 0..15. H.B(D) перебирает **1..16**, хотя массивы
имеют 16 элементов. Все проверенные OC intervals 0/45/60/180/1440 завершаются
ArrayIndexOutOfBoundsException с индексом 16. CCR repeated dive выполняется.
Дополнительный нюанс: контроллеры вызывают prepare/reset VPM перед обработкой
surface interval; переносимые состояния надо сравнивать с фактически вызываемым
порядком, а не с воображаемым полным сохранением всех пузырьковых параметров.

## Контрольные результаты

Два одинаковых OC погружения 30m/20min на воздухе, первое runtime=28:

| Surface interval | B, второе | C, второе | VPM OC |
|---:|---:|---:|---|
| 0 | 46 | 51 | exception index 16 |
| 45 | 30 | 34 | exception index 16 |
| 60 | 29 | 31 | exception index 16 |
| 180 | 28 | 28 | exception index 16 |
| 1440 | 28 | 28 | exception index 16 |

На 2000м B/C air30m/20min дают runtime30 и в acclimatized, и в выбранном travel
случае; ткани сохранены отдельно и не обязаны совпадать из-за совпадения целых
минут. Нормальные CCR altitude/repetitive cases и ошибочные H cases находятся
в `analysis/fixtures/results`. Ни исключение, ни его наличие не подменяются
синтетическим «успешным» планом.

## Для собственной реализации

Формулы и точный путь оригинала восстановлены, но успешного эталона VPM OC
для этих функций нет: оригинал падает. Исправления off-by-one, порядка
инициализации, целочисленных часов CNS и сохранения VPM state должны быть
явными решениями нового ядра и проверяться независимыми эталонами.

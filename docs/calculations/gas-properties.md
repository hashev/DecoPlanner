# MOD, END, плотность и состав по целям

Статус: формулы подтверждены байткодом; MOD/END проверены оригинальным I,
плотность — оригинальным контроллером K.I().

## Максимальная/минимальная рабочая глубина

`I.A(double PO2,int oxygenPercent)`:

```text
depth = (PO2/(oxygenPercent/100)-1)*unitsPerATA
```

Для minimum operating depth используется minPO2 и отрицательный результат
в K.K() зажимается к 0. Maximum использует maxPO2. Метрика округляется F.B
до десятых, imperial через Math.round до целых. Формула использует фиксированное
морское давление 1 ATA, не текущую высоту. При oxygenPercent=0 низкоуровневая
функция возвращает Infinity, а UI отклоняет такой ввод.

## END

`I.A(double oxygenNarcosis,int heliumPercent,int oxygenPercent,double depth)`:

```text
fHe = float32(HePercent/100)
fO2 = float32(O2Percent/100)
fN2 = float32(1 - float32(fHe+fO2))
referenceNarcotic = 0.79 + 0.21*oxygenNarcosis
narcoticPressure = (fN2+fO2*oxygenNarcosis)*(depth/unitsPerATA+1)
END = (narcoticPressure/referenceNarcotic-1)*unitsPerATA
```

Оригинальный UI предлагает коэффициент наркотичности O2 0,0.3,1,2.
Коэффициент и float32-конверсии — часть входа/арифметики. Вывод не доказывает
физиологическую правильность выбранного коэффициента. В ядрах есть также
вычисления N2-only и O2+N2 END, но некоторые значения вычисляются без вывода.
Не выдавать их за отдельную пользовательскую настройку всех экранов.

## Плотность

K.I() для заданного состава:

```text
rhoSurface = fO2*1.43 + fHe*0.18 + fN2*1.25
rho = rhoSurface*(depth/unitsPerATA+1)  # g/L
rhoEquivalentAirDepth = (rho/1.2878-1)*unitsPerATA
```

Воздух21/0 имеет rhoSurface=1.2878. K выводит rho и equivalent air density depth,
а CCR-ядра A/D используют эффективный loop composition при setpoint и сохраняют
плотность в V.A. Данные не включают сложную температурную или реальную EOS-модель:
нельзя автоматически использовать заправочный Q/Z для дыхательной плотности.

## Подбор газа по PO2/END

K.C(): при заданных depth, PO2, END и oxygenNarcosis:

```text
ambient = depth/unitsPerATA+1
fO2 = PO2/ambient
narcoticFraction = (0.79+0.21*oxygenNarcosis)*(END/unitsPerATA+1)/ambient
fN2 = narcoticFraction-fO2*oxygenNarcosis
O2percent = roundTenth(fO2*100)
HePercent = max(0,roundTenth(100-O2percent-fN2*100))
```

Округление O2 происходит до вычисления остаточного He. Нельзя заменить его
полностью округлением в самом конце и ожидать те же десятые процента.

## Проверки

Для воздуха, EAN32 и trimix18/45 сохранены MOD и END в metric/imperial;
проверены варианты oxygenNarcosis 0/.3/1/2, граница O2=0 в низкоуровневом MOD,
и фактические density outputs для трёх смесей. Имена случаев начинаются
`mod-`, `end-`, `density-`.

# Контракт согласования независимых эталонов

Основные сравнимые источники: DecoTengu0.14.1 для Bühlmann B/C1b;
bwaite/vpmb `bec938d84742e42dd43b574beec49ac26f6863ac` для выбранного VPM-B;
mpmath1.3.0 для независимой кинетической/кислородной quadrature.
Внешние исходники остаются в local/. Dart-результат не является источником
ожиданий генераторов.

| Поле | Принятое соглашение | Контроль |
|---|---|---|
| Внутренние единицы | bar, metres, minutes; 1ATA=1.01325bar;1ft=.3048m | units/legacy_pressure_depth tests |
| Давление поверхности | Явное физическое значение, не неявный1ATA; sea-level calibration задана каждым fixture | B/C pressure/altitude + VPM pressure snapshots |
| Water vapour | B/C.0627bar; выбранный VPM.0493bar | Не смешиваются между наборами |
| Насыщение на поверхности | Воздух N2.79, He0; dry inspired pressure | Все16начальных тканей |
| Bühlmann | B/C с первой тканью1b; mixed a/b; GF30/85 если case не задаёт иное | parameter/ceiling fixture,19OC/18CCR-bailout profiles |
| Сетка | Физические шаг/последняя остановка; metric3m либо imperial10ft=3.048m | Полные schedules, не пересчёт округлённой печатной таблицы |
| Время уровня вниз | При includeDescentInLevelTime длительность включает спуск; движение с реальной скоростью | Все travel/hold endpoints |
| Введённый подъём VPM | Полный CV trial-to-surface, затем реальный проход до указанного уровня; выдержка заканчивается на ceil(arrival)+duration | Отдельный partial-ascent/redescent adapter |
| Gas/SP | Мгновенное переключение без задержки; low SP при CCR-спуске, заданный SP на выдержке | Состав/SP каждого физического сегмента |
| CCR ткани | max(0,ambient-vapour-SP), делённое на inert fraction; wet ppO2 для oxygen policy | Независимая ODE quadrature; VPM source adapter ограничен non-clipped областью |
| Границы переключений | Применяются физические глубины и lost/minimum flags; исходный source сохраняется при bailout | OC/CCR/bailout и boundary tests |
| Остановочное время | Невыдуманные raw времена; выбранное runtime alignment/минимальная остановка отдельно от display rounding | Полный stop search и независимые duration/state snapshots |
| VPM Boyle | Максимальный trial first-stop аргумент;70-digit refined roots по уравнениям источника | Отдельно от legacy swapped-gradient диагностики |
| Печатная глубина VPM | int(display) не заменяет физическую глубину; reported/raw поля раздельны | Футовая fractional-grid матрица |
| Состояние VPM | Все22вектора/saved tissue snapshots и scalar context; не только N2/He | Полные конечные состояния и промежуточные physical/crushing states |
| Повторное погружение | Полное состояние, непрерывный SI; SI0identity; общий oxygen recovery | SI0/45/60/180/1440 OC/CCR/bailout |
| Высота | Acclimatized/travel initialization до dive, pressure/radii/state сохранены | Успешные independent2000m и8848m cases вместо исходных JAR-ошибок |
| CNS/OTU | Baker7bands; CNS вне1.6ATA недоступен, OTU/декомпрессия продолжаются; неизвестность CNS сохраняется через SI/JSON | Domain/oxygen fixtures и runtime UI |
| Runtime/ascent/deco | Raw runtime; ascent включает всё движение вверх и остановки; deco учитывается после первой реальной остановки каждого подъёма | Суммы независимой physical timeline |

## Нормализованный VPM не объявляется untouched benchmark

Source остаётся побайтно закреплённым; изменения оркестрации/инструментации
явно описаны. Выбранная stop alignment +.501 и maximum-first-stop Boyle policy
зафиксированы до сравнения. Root precision повышена независимо от Dart output.
Для CCR расширена inspired-pressure preparation, а gradient/crushing/CV/search
выполняет внешний код. Для partial ascent прерывается только final physical pass;
CV trials выполняются полностью. История максимального actual gradient относится
ко всему dive и сохраняется при следующем межуровневом поиске. Итоговая публикация
поверхностного состояния включает независимую SI0 finalization; raw surface
snapshot сохраняется отдельно.

VPM CCR-reference отвергает dry-pressure clipping. Это граница адаптера,
не запрет функции приложения: clipping проверяется отдельными независимыми
кинетическими quadrature cases. Для глубоких полных CCR profiles применены
SP1.3/1.4/.7; для мелкого partial-ascent/deco/redescent — SP.7, для высоты
используются объявленные admissible setpoints. Математически несравнимый профиль
не принимается как совпадение увеличением допуска.

## Роль дополнительных Subsurface snapshots

Pinned Subsurface и libdc используются отдельно как дополнительные native
наблюдения и constant-SP tissue controls. Четыре source-native полных плана
сохранены с их собственными conventions; они не объявлены совпадающим oracle
нашего schedule. Его C1b/VPM параметры/градиенты, газы/стартовая N2 и timing
нельзя автоматически уравнять с выбранным продуктовым вариантом. Они имеют
диагностическую роль и не заменяют успешные полные B/C/VPM сравнения выше.
Неуспешная нормализация дополнительного источника не исключает обязательную
продуктовую ветвь: она проверяется основным согласованным источником.

Полный provenance/coverage audit и перечень полевых допусков — отдельная
задача2.5/11.1. Этот документ фиксирует соглашения, а не объявляет аудит оконченным.

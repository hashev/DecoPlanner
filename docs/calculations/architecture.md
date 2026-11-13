# Карта вычислений

Статус этой карты: подтверждено исходными вызовами и JVM-сигнатурами.
Ссылки на CFR ниже — доказательные ориентиры; оригинальные дескрипторы
сохранены в symbols.json (локально: `../../local/reference/analysis/bytecode/symbols.json`).

```text
DP.fxml --> DP (global settings O)
OC.fxml --> W --> J + d[] + h[] --> S (Buhlmann) or H (VPM)
CC.fxml --> R --> J + d[] + h[] --> A (Buhlmann) or D (VPM)
Bailout.fxml --> Y --> J + d[] + h[] --> S (Buhlmann) or H (VPM)
                                      |
                                      v
                   mutated J, tissue arrays, rows G (OC) / V (CCR)
                                      |
                                      v
                    M (previous dives and surface interval)
```

## Подтверждение маршрутов

| Роль | Исходные символы | Доказательство |
|---|---|---|
| OC | `W` выбирает `S.A(J)` / `H.A(J)` | W.java (локально: `../../local/reference/analysis/decompiled/source/decoplanner/W.java`), строки 1212–1255; W bytecode (локально: `../../local/reference/analysis/bytecode/decoplanner/W.txt`) |
| CCR | `R` выбирает `A.A(J)` / `D.A(J)` | R.java (локально: `../../local/reference/analysis/decompiled/source/decoplanner/R.java`), 1230–1263; R bytecode (локально: `../../local/reference/analysis/bytecode/decoplanner/R.txt`) |
| Bailout | `Y` выбирает `S.A(J)` / `H.A(J)` | Y.java (локально: `../../local/reference/analysis/decompiled/source/decoplanner/Y.java`), 1255–1281; Y bytecode (локально: `../../local/reference/analysis/bytecode/decoplanner/Y.txt`) |
| Выбор модели | `O.È`: 1 Bühlmann, 2 VPM | вызовы выше, настройки O.java (локально: `../../local/reference/analysis/decompiled/source/decoplanner/O.java`) |
| Подготовка модели | `S.C()`, `A.B()`, `H.I()`, `D.I()` | масштабирование параметров до вызова расчёта, контроллеры выше |
| Начальная загрузка | `J.H()` для первого погружения, `M.A(int,int)` + `J.E()` для повторного | J.java (локально: `../../local/reference/analysis/decompiled/source/decoplanner/J.java`), M bytecode (локально: `../../local/reference/analysis/bytecode/decoplanner/M.txt`) |
| Завершение | `J.V/e` конечные N2/He; `J.Y/A` CNS/OTU | завершение `A(J)` в каждом ядре |

Вызовы `A(J)` мутируют объект и коллекцию сегментов: начальная сетка содержит
введённые сегменты, затем ядро вставляет собственные подъёмы и остановки.
Одного значения «глубина/время» для воспроизведения недостаточно: нужен полный
набор настроек и соглашение о включении времени спуска в длительность.

## Сопоставление имён CFR

Обфускатор сохранил Java-символы `a..j`, но CFR переименовал их в `a_0..j_0`.
`d` — сегмент; `h` — газ; `b` — строка выбора декогаза; `a` — набор декогазов.
Имена `A` и `a` различны. При вызовах адаптера использовать оригинальные имена.

## Ядро и UI

Настройки `O` используют Java Preferences. Численные результаты `G/V` зависят
от JavaFX properties/collections, но нормальный расчёт не обязан создавать окно.
Ветви ошибок ядра могут создавать `Alert` и ссылаться на `Main.myStage`.
Поэтому оригинальные классы выполняются в отдельном процессе с таймаутом;
ошибку JavaFX нельзя выдавать за корректный вычислительный результат.

Лицензирование `P`, обновления `e` и интерфейс справки `f` не являются частью
вычислительного контракта. Адаптер не вызывает `Main` и эти подсистемы.

# Реальные кадры Flutter-приложения

Снимки получены `integration_test/plan_flow_test.dart` при нативном запуске
на macOS13ноября2026. Это кадры приложения800×600, снятые через Flutter
RenderRepaintBoundary; не SVG-макеты, не browser preview и не пример из fixture.
Профиль30m/20min вычислен настоящим ядром в отдельном isolate после нажатия
«Рассчитать». Обе темы показывают один неизменённый физический результат.

- [Светлая тема](native-oc-light.png).
- [Тёмная тема](native-oc-dark.png).
- [Bailout, светлая тема](native-bailout-light.png).
- [Bailout, тёмная тема](native-bailout-dark.png).

Bailout-кадры получены вторым native test: режим CCR,45m/25min, diluent21/35,
SP1.3bar введены в редакторе, затем создана отдельная ветвь в25min без декогазов.
Результат68.33333333333333min совпадает с независимым B1b reference. При выборе
исходного сценария CCR-результат остаётся неизменным.

Сценарий запускается официальным Dart MCP `run_tests` с путём
`integration_test/plan_flow_test.dart`. В этой среде автоматически выбрана macOS.
При запуске вручную: `flutter test integration_test/plan_flow_test.dart -d macos`.
Тесты печатают `PLANNER_NATIVE_CAPTURES`/`PLANNER_BAILOUT_CAPTURES`, PNG сохраняются
во временную директорию приложения; сюда переносятся репрезентативные кадры.

Отдельные widget tests проверяют375/599/600/999/1000/1440px, landscape740×375,
text scaling100%/200%, обе темы, навигацию, редактор, отмену/подтверждения и
недоступный CNS с причиной. Эти тесты не подменяют проверку VoiceOver/TalkBack
или запуск на физическом мобильном устройстве. Полный перечень доступных и
непроверенных сценариев — в `docs/development/validation-current.md`.

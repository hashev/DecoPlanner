# Изолированный расчёт

`lib/data/services/calculation_worker.dart` — production adapter к чистому ядру.
`CalculationWorker.calculate` принимает immutable DiveRequest, optional BailoutRequest, inputRevision и
версию зависимостей. Возвращает handle с result Future, stage stream и cancel.
Каждый запрос получает отдельный isolate и requestId. Envelope проверяет
protocol/model version, requestId, inputRevision и dependencyVersion; результат
дополнительно проверяет diveId/modelVersion и полную core JSON-схему.
Protocol version2 поддерживает отдельный bailout ID. Для ветви вызывается
calculateBuhlmannBailout/calculateVpmBailout; исходный CCR и OC escape рассчитываются
в одном isolate с общим budget. Parent ожидает ID ветви, а не ID исходного dive.

Единственный активный запрос на экземпляр сервиса: следующий запрос завершает
предыдущий как superseded и убивает его isolate. Cancel, external timeout и dispose
закрывают ports/timer и прекращают worker с Isolate.immediate. Гонка отмены до
завершения Isolate.spawn обработана: поздно созданный isolate сразу уничтожается.
`dispose()` дожидается незавершённых spawn. Запрос после dispose запрещён.

Внутри worker вызывается calculateBuhlmann/calculateVpm с общим iteration/time
budget. Core CalculationFailure сохраняется в структурированной причине.
External timeout, cancelled/superseded, protocol mismatch, unexpected exit и
прочие worker failures имеют отдельные виды, не превращаются в пустой план.
Следующий корректный запрос может выполняться после ошибки/таймаута.

Progress — стадии starting/calculating/completed без выдуманного процента.
Completed публикуется родителем только после получения и валидации результата.
Progress диапазона (число завершённых ячеек) принадлежит range orchestration,
а последовательность — PlannerViewModel; worker рассчитывает один dive или одну
связанную bailout-ветвь за запрос.

Проверки `test/data/services/calculation_worker_test.dart`: настоящие расчёты
Bühlmann/VPM в isolate, изменение входов, typed core failure, отмена до/после
spawn, родительский heartbeat при синхронно заблокированном тестовом worker,
hard timeout, recovery, superseded revision, неверные dependency/model/protocol,
malformed response и unexpected exit. Тестовые entry points — constructor
injection, в production default используется настоящий численный расчёт.
Тесты не подменяют ядро сохранёнными fixtures.

Базовый UI подключён к обычным dive-расчётам и проверен native integration test.
Worker bailout проверен настоящими isolate-тестами для B/C/VPM; связанный экран
bailout ещё требует подключения и отдельной UI-проверки.

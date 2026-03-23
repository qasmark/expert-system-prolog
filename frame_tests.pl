run_tests :-
    writeln(' Запуск тестов фреймовой системы '),
    nl,
    test_inheritance,
    test_override_class,
    test_override_instance,
    test_deep_inheritance,
    test_procedure,
    nl,
    writeln(' Тесты завершены ').

test_inheritance :-
    value('VIP-8801', status, V),
    format('Тест 1 (Базовое наследование): Статус VIP-8801 = ~w [Ожидаем: opened]~n', [V]).

test_override_class :-
    value('VIP-8801', priority, V),
    format('Тест 2 (Переопределение классом): Приоритет VIP-8801 = ~w [Ожидаем: high]~n', [V]).

test_override_instance :-
    value('API-3099', status, V),
    format('Тест 3 (Переопределение экземпляром): Статус API-3099 = ~w [Ожидаем: in_progress]~n', [V]).

test_deep_inheritance :-
    value('API-3099', department, V),
    format('Тест 4 (Глубокое наследование): Отдел для API-3099 = ~w [Ожидаем: it_operations]~n', [V]).

test_procedure :-
    value('API-3099', resolution_time, V),
    format('Тест 5 (Вызов процедуры/демона): Время решения API-3099 = ~w ч. [Ожидаем: 12]~n', [V]).
% semantic_module.pl


run_semantic_analysis :-
    findall(Id, current_selection(Id), Selection),
    % Проверяем, есть ли вообще что анализировать
    ( Selection == [] ->
        writeln('Выборка пуста. Гипотезы не могут быть проверены.'), !
    ;
        length(Selection, Count),
        format('Анализ выборки из ~w тикетов.~n', [Count]),
        hypothesis_menu(Selection)
    ).
hypothesis_menu(Selection) :-
    nl,
    writeln('Какую гипотезу вы хотите проверить?'),
    writeln('1. Какова общая вероятность, что проблемы в этой выборке вызваны ошибкой API?'),
    writeln('2. Оценить для каждого тикета в выборке риск "долгого решения".'),
    writeln('0. Завершить анализ.'),
    read(Choice),
    process_hypothesis(Choice, Selection).

process_hypothesis(1, Selection) :-
    check_api_error_hypothesis(Selection),
    hypothesis_menu(Selection).
process_hypothesis(2, Selection) :-
    check_long_resolution_risk(Selection),
    hypothesis_menu(Selection).
process_hypothesis(0, _) :-
    writeln('Анализ завершен.').
process_hypothesis(_, Selection) :-
    writeln('Неверный выбор, попробуйте снова.'),
    hypothesis_menu(Selection).

check_api_error_hypothesis(Selection) :-
    maplist(get_ticket_evidence, Selection, Evidences),
    maplist(prob(api_error), Evidences, Probabilities),
    sum_list(Probabilities, TotalProb),
    length(Selection, Count),
    AverageProb is TotalProb / Count,
    format('~nГипотеза: Общая вероятность того, что причиной проблем в выборке является ошибка API, составляет: ~2f%~n', [AverageProb * 100]).

check_long_resolution_risk(Selection) :-
    writeln('~nГипотеза: Риск долгого решения для каждого тикета в выборке:'),
    forall(
        member(Id, Selection),
        (
            get_ticket_evidence(Id, Evidence),
            prob(long_resolution, Evidence, Prob),
            format('  - Тикет ~w: Вероятность долгого решения = ~2f%~n', [Id, Prob * 100])
        )
    ).

get_ticket_evidence(Id, Evidence) :-
    ticket(Id, Problem, Priority, _, Client, _),
    ( member(Client, [vip]) -> E1 = vip_client ; E1 = not(vip_client) ),
    ( Problem == api_error -> E2 = api_error ; E2 = not(api_error) ),
    ( member(Priority, [critical]) -> E3 = critical_priority ; E3 = not(critical_priority) ),
    Evidence = [E1, E2, E3].
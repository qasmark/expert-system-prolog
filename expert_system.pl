% expert_system.pl

ticket('B2C-8801', p_sbp, low, chat, guest, opened).
ticket('B2C-8845', refund, medium, tg_bot, b2c, closed).
ticket('API-3099', api_error, urgent, email, b2b, rework).
ticket('API-3102', pay_error, high, tg_bot, partner, waiting).
ticket('SEC-0450', block, urgent, phone, guest, in_progress).
ticket('SEC-0451', block, critical, email, b2b, waiting).
ticket('VIP-0012', api_error, critical, phone, vip, rework).
ticket('VIP-0018', refund, medium, chat, vip, opened).
ticket('FIN-5510', refund, low, email, partner, closed).
ticket('B2B-9021', p_sbp, medium, phone, b2b, opened).
ticket('FIN-5588', pay_error, medium, max_messenger, b2c, opened).

problem_name(pay_error, 'Ошибка оплаты').
problem_name(refund, 'Возврат средств').
problem_name(block, 'Блокировка аккаунта').
problem_name(api_error, 'Ошибка API/интеграции').
problem_name(p_sbp, 'Платежи СБП').

priority_name(low, 'Низкий').
priority_name(medium, 'Средний').
priority_name(high, 'Высокий').
priority_name(critical, 'Критический').
priority_name(urgent, 'Неотложный').

channel_name(chat, 'Чат').
channel_name(tg_bot, 'Telegram-бот').
channel_name(email, 'Email').
channel_name(phone, 'Телефон').
channel_name(max_messenger, 'Max').

client_name(b2c, 'Физ. лицо (B2C)').
client_name(b2b, 'Мерчант (B2B)').
client_name(partner, 'Партнер').
client_name(vip, 'VIP').
client_name(guest, 'Гость').

status_name(opened, 'Открыто').
status_name(in_progress, 'В работе').
status_name(waiting, 'Ожидает ответа').
status_name(closed, 'Закрыто').
status_name(rework, 'На доработке').


:- dynamic current_selection/1.

start :-
    writeln(' Этап 1: Фильтрация тикетов '),
    retractall(current_selection(_)),

    ask_problem(Problem),
    ask_priority(Priority),
    ask_channel(Channel),
    ask_client(Client),
    ask_status(Status),
    
    find_and_save_tickets(Problem, Priority, Channel, Client, Status),
    
    nl,
    writeln(' Результаты фильтрации '),
    print_selection,
    
    nl,
    writeln(' Этап 2: Семантический анализ выборки '),
    run_semantic_analysis.


ask_problem(P) :-
    writeln('Выберите тип проблемы:'),
    writeln('1. Ошибка оплаты'),
    writeln('2. Возврат средств'),
    writeln('3. Блокировка аккаунта'),
    writeln('4. Ошибка API/интеграции'),
    writeln('5. Платежи СБП'),
    writeln('0. Любая'),
    read(Choice),
    map_problem(Choice, P).

map_problem(1, pay_error).
map_problem(2, refund).
map_problem(3, block).
map_problem(4, api_error).
map_problem(5, p_sbp).
map_problem(0, any).
map_problem(_, any).

ask_priority(P) :-
    nl,
    writeln('Выберите приоритет:'),
    writeln('1. Низкий'),
    writeln('2. Средний'),
    writeln('3. Высокий'),
    writeln('4. Критический'),
    writeln('5. Неотложный'),
    writeln('0. Любой'),
    read(Choice),
    map_priority(Choice, P).

map_priority(1, low).
map_priority(2, medium).
map_priority(3, high).
map_priority(4, critical).
map_priority(5, urgent).
map_priority(0, any).
map_priority(_, any).

ask_channel(C) :-
    nl,
    writeln('Выберите канал связи:'),
    writeln('1. Чат'),
    writeln('2. Telegram-бот'),
    writeln('3. Email'),
    writeln('4. Телефон'),
    writeln('5. Max'),
    writeln('0. Любой'),
    read(Choice),
    map_channel(Choice, C).

map_channel(1, chat).
map_channel(2, tg_bot).
map_channel(3, email).
map_channel(4, phone).
map_channel(5, max_messenger).
map_channel(0, any).
map_channel(_, any).

ask_client(C) :-
    nl,
    writeln('Выберите тип клиента:'),
    writeln('1. Физ. лицо (B2C)'),
    writeln('2. Мерчант (B2B)'),
    writeln('3. Партнер'),
    writeln('4. VIP'),
    writeln('5. Гость'),
    writeln('0. Любой'),
    read(Choice),
    map_client(Choice, C).

map_client(1, b2c).
map_client(2, b2b).
map_client(3, partner).
map_client(4, vip).
map_client(5, guest).
map_client(0, any).
map_client(_, any).

ask_status(S) :-
    nl,
    writeln('Выберите статус:'),
    writeln('1. Открыто'),
    writeln('2. В работе'),
    writeln('3. Ожидает ответа'),
    writeln('4. Закрыто'),
    writeln('5. На доработке'),
    writeln('0. Любой'),
    read(Choice),
    map_status(Choice, S).

map_status(1, opened).
map_status(2, in_progress).
map_status(3, waiting).
map_status(4, closed).
map_status(5, rework).
map_status(0, any).
map_status(_, any).

match_attr(any, _).
match_attr(X, X).

find_and_save_tickets(TargetProb, TargetPrio, TargetChan, TargetCli, TargetStat) :-
    findall(Id, (
        ticket(Id, Prob, Prio, Chan, Cli, Stat),
        match_attr(TargetProb, Prob),
        match_attr(TargetPrio, Prio),
        match_attr(TargetChan, Chan),
        match_attr(TargetCli, Cli),
        match_attr(TargetStat, Stat)
    ), Results),
    forall(member(TicketId, Results), assertz(current_selection(TicketId))).

print_selection :-
    findall(Id, current_selection(Id), Selection),
    ( Selection == [] ->
        writeln('Подходящие тикеты не найдены. Анализ невозможен.')
    ;
        writeln('Найдено и сохранено для анализа тикетов:'),
        print_results(Selection)
    ).

print_results([]).
print_results([H|T]) :-
    ticket(H, Prob, Prio, Chan, Cli, Stat),
    problem_name(Prob, ProbStr),
    priority_name(Prio, PrioStr),
    channel_name(Chan, ChanStr),
    client_name(Cli, CliStr),
    status_name(Stat, StatStr),
    format('Тикет ~w | Проблема: ~w | Приоритет: ~w | Канал: ~w | Клиент: ~w | Статус: ~w~n', 
           [H, ProbStr, PrioStr, ChanStr, CliStr, StatStr]),
    print_results(T).
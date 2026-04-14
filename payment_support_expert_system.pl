:- module(payment_support_expert_system, [
    run/0,
    admin_menu/0,
    diagnose/1,
    diagnose/2,
    diagnosis_confidence/2,
    diagnosis_confidence/3,
    reset_session/0,
    remember_answer/2,
    clear_answer/1,
    learn_new_case/11,
    remove_learned_case/1,
    delete_learned_case/1,
    list_learned_cases/0,
    list_learned_cases/1,
    reset_learned_knowledge/0,
    save_learned_knowledge/0,
    save_learned_knowledge/1,
    load_learned_knowledge/1
]).

:- use_module(library(lists)).
:- use_module(library(readutil)).
:- use_module('knowledge/base_facts.pl', []).
:- use_module('knowledge/bayesian_facts.pl', [bayesian_symptom/1, diagnosis_probability/3]).
:- use_module('knowledge/learned_facts.pl', []).

:- dynamic known_answer/2.
:- dynamic system_directory/1.

:- prolog_load_context(directory, Dir),
   retractall(system_directory(_)),
   assertz(system_directory(Dir)).

run :-
    reset_session,
    print_banner,
    diagnose(CaseId, Path),
    show_diagnosis(CaseId, Path),
    maybe_learn(CaseId, Path).

admin_menu :-
    nl,
    writeln("Learned knowledge administration"),
    writeln("Available commands: list, delete, exit"),
    repeat,
    nl,
    prompt_atom("admin> ", Command),
    ( Command = list ->
        list_learned_cases,
        fail
    ; Command = delete ->
        delete_learned_case_interactive,
        fail
    ; Command = exit ->
        writeln("Administration menu closed."),
        !
    ; writeln("Unknown command. Use: list, delete, exit."),
      fail
    ).

diagnose(CaseId) :-
    diagnose(CaseId, _).

diagnose(CaseId, Path) :-
    payment_support_base_facts:root_node(RootNode),
    resolve_node(RootNode, [], Path, CaseId).

reset_session :-
    retractall(known_answer(_, _)).

remember_answer(QuestionId, Answer) :-
    retractall(known_answer(QuestionId, _)),
    assertz(known_answer(QuestionId, Answer)).

clear_answer(QuestionId) :-
    retractall(known_answer(QuestionId, _)).

learn_new_case(
    ParentNode,
    ParentAnswer,
    OldCaseId,
    NewCaseId,
    Title,
    Explanation,
    Recommendation,
    QuestionId,
    QuestionPrompt,
    NewCaseAnswer,
    Properties
) :-
    must_be_binary(NewCaseAnswer),
    opposite_binary_answer(NewCaseAnswer, OldCaseAnswer),
    new_node_id(NewCaseId, NewNodeId),
    retractall(payment_support_learned_facts:branch_override(ParentNode, ParentAnswer, _)),
    assertz(payment_support_learned_facts:branch_override(ParentNode, ParentAnswer, node(NewNodeId))),
    assertz(payment_support_learned_facts:question(QuestionId, QuestionPrompt, [yes, no])),
    assertz(payment_support_learned_facts:node_question(NewNodeId, QuestionId)),
    assertz(payment_support_learned_facts:node_branch(NewNodeId, NewCaseAnswer, leaf(NewCaseId))),
    assertz(payment_support_learned_facts:node_branch(NewNodeId, OldCaseAnswer, leaf(OldCaseId))),
    assertz(payment_support_learned_facts:case_info(NewCaseId, Title, Explanation, Recommendation)),
    assert_case_properties(NewCaseId, Properties),
    assertz(
        payment_support_learned_facts:learned_extension(
            NewCaseId,
            ParentNode,
            ParentAnswer,
            NewNodeId,
            QuestionId,
            NewCaseAnswer,
            OldCaseAnswer,
            OldCaseId
        )
    ).

remove_learned_case(CaseId) :-
    forall(
        retract(payment_support_learned_facts:learned_extension(
            CaseId,
            ParentNode,
            ParentAnswer,
            NewNodeId,
            QuestionId,
            NewCaseAnswer,
            OldCaseAnswer,
            OldCaseId
        )),
        remove_extension_facts(
            CaseId,
            ParentNode,
            ParentAnswer,
            NewNodeId,
            QuestionId,
            NewCaseAnswer,
            OldCaseAnswer,
            OldCaseId
        )
    ),
    retractall(payment_support_learned_facts:case_info(CaseId, _, _, _)),
    retractall(payment_support_learned_facts:case_property(CaseId, _, _)).

delete_learned_case(CaseId) :-
    payment_support_learned_facts:learned_extension(CaseId, _, _, _, _, _, _, _),
    !,
    remove_learned_case(CaseId),
    save_learned_knowledge.
delete_learned_case(CaseId) :-
    format("Learned case `~w` was not found.~n", [CaseId]),
    fail.

list_learned_cases :-
    list_learned_cases(Cases),
    ( Cases = [] ->
        writeln("No learned cases are currently stored.")
    ; writeln("Learned cases:"),
      forall(
          member(case(CaseId, Title, ParentNode, QuestionId), Cases),
          format("  - ~w | ~w | parent node: ~w | discriminator: ~w~n", [CaseId, Title, ParentNode, QuestionId])
      )
    ).

list_learned_cases(Cases) :-
    findall(
        case(CaseId, Title, ParentNode, QuestionId),
        learned_case_summary(CaseId, Title, ParentNode, QuestionId),
        Cases
    ).

reset_learned_knowledge :-
    retractall(payment_support_learned_facts:question(_, _, _)),
    retractall(payment_support_learned_facts:node_question(_, _)),
    retractall(payment_support_learned_facts:node_branch(_, _, _)),
    retractall(payment_support_learned_facts:branch_override(_, _, _)),
    retractall(payment_support_learned_facts:case_info(_, _, _, _)),
    retractall(payment_support_learned_facts:case_property(_, _, _)),
    retractall(payment_support_learned_facts:learned_extension(_, _, _, _, _, _, _, _)).

save_learned_knowledge :-
    default_learned_file(Path),
    save_learned_knowledge(Path).

save_learned_knowledge(Path) :-
    open(Path, write, Stream, [encoding(utf8)]),
    write_learned_header(Stream),
    write_learned_facts(Stream),
    close(Stream).

load_learned_knowledge(Path) :-
    reset_learned_knowledge,
    ( exists_file(Path) ->
        setup_call_cleanup(
            open(Path, read, Stream, [encoding(utf8)]),
            load_terms(Stream),
            close(Stream)
        )
    ; true
    ).

print_banner :-
    nl,
    writeln("Экспертная система поддержки платежной системы"),
    writeln("Система задает уточняющие вопросы, выдает наиболее вероятный кейс и оценивает его вероятность по Байесу."),
    writeln("Если рекомендация не подходит, можно дообучить дерево новым признаком."),
    nl.

resolve_node(NodeId, StepsAcc, Path, CaseId) :-
    kb_node_question(NodeId, QuestionId),
    resolve_answer(QuestionId, Answer),
    Step = step(NodeId, QuestionId, Answer),
    ( kb_node_branch(NodeId, Answer, node(NextNode)) ->
        resolve_node(NextNode, [Step | StepsAcc], Path, CaseId)
    ; kb_node_branch(NodeId, Answer, leaf(CaseId)) ->
        reverse([Step | StepsAcc], Path)
    ; reverse([Step | StepsAcc], Path),
      CaseId = unknown_situation
    ).

resolve_answer(QuestionId, Answer) :-
    known_answer(QuestionId, Answer),
    !.
resolve_answer(QuestionId, Answer) :-
    ask_question(QuestionId, Answer),
    remember_answer(QuestionId, Answer).

ask_question(QuestionId, Answer) :-
    kb_question(QuestionId, Prompt, Options),
    repeat,
    nl,
    writeln(Prompt),
    format("Допустимые варианты: ~w~n> ", [Options]),
    read_line_to_string(user_input, RawInput),
    normalize_space(string(Normalized), RawInput),
    ( option_from_input(Normalized, Options, Answer) ->
        !
    ; writeln("Не удалось распознать ответ. Повторите ввод точно одним из вариантов."),
      fail
    ).

show_diagnosis(CaseId, Path) :-
    kb_case_info(CaseId, Title, Explanation, Recommendation),
    ( diagnosis_confidence_percent(CaseId, Percent) -> true ; true ),
    nl,
    writeln("Скорее всего, ситуация такая:"),
    format("  ~w~n", [Title]),
    ( nonvar(Percent) ->
        format("  Вероятность диагноза по Байесовской сети: ~1f%~n", [Percent])
    ; true
    ),
    nl,
    print_case_frame_context(CaseId),
    writeln("Почему система так решила:"),
    print_path(Path),
    nl,
    writeln("Описание кейса:"),
    format("  ~w~n", [Explanation]),
    nl,
    writeln("Характерные признаки в базе знаний:"),
    print_case_properties(CaseId),
    nl,
    writeln("Что делать оператору:"),
    format("  ~w~n", [Recommendation]),
    nl.

maybe_learn(unknown_situation, _) :-
    ask_yes_no("Добавить новый кейс в обучаемую базу сейчас?", Reply),
    ( Reply = yes ->
        writeln("Для автоматического добавления новой ветки нужен конфликт с существующим листом. Запустите сценарий повторно после уточнения базового пути или добавьте кейс через learn_new_case/11.")
    ; true
    ).
maybe_learn(CaseId, Path) :-
    format("Подтверждаете кейс `~w`?~n", [CaseId]),
    ask_yes_no("Введите yes или no.", Reply),
    ( Reply = yes ->
        writeln("Кейс подтвержден.")
    ; learn_from_console(Path, CaseId)
    ).

diagnosis_confidence(CaseId, Probability) :-
    known_bayesian_evidence(Evidence),
    diagnosis_confidence(CaseId, Evidence, Probability).

diagnosis_confidence(CaseId, Evidence, Probability) :-
    diagnosis_probability(CaseId, Evidence, Probability),
    !.

known_bayesian_evidence(Evidence) :-
    findall(
        QuestionId-Answer,
        (
            known_answer(QuestionId, Answer),
            bayesian_symptom(QuestionId)
        ),
        Evidence
    ).

diagnosis_confidence_percent(CaseId, Percent) :-
    diagnosis_confidence(CaseId, Probability),
    Percent is round(Probability * 1000) / 10.

learn_from_console(Path, OldCaseId) :-
    last(Path, step(ParentNode, _, ParentAnswer)),
    nl,
    writeln("Добавление нового кейса."),
    prompt_atom("Идентификатор нового кейса (например, manual_bank_hold): ", NewCaseId),
    prompt_text("Название нового кейса: ", Title),
    prompt_text("Краткое описание нового кейса: ", Explanation),
    prompt_text("Рекомендуемое действие для оператора: ", Recommendation),
    prompt_atom("Идентификатор нового признака (например, manual_hold_indicator): ", QuestionId),
    prompt_text("Текст нового уточняющего вопроса: ", QuestionPrompt),
    ask_yes_no("Ответ yes должен вести к новому кейсу?", NewCaseAnswer),
    prompt_text("Название нового характерного признака: ", PropertyLabel),
    prompt_text("Подсказка по этому признаку: ", PropertyHint),
    learn_new_case(
        ParentNode,
        ParentAnswer,
        OldCaseId,
        NewCaseId,
        Title,
        Explanation,
        Recommendation,
        QuestionId,
        QuestionPrompt,
        NewCaseAnswer,
        [property(PropertyLabel, PropertyHint)]
    ),
    save_learned_knowledge,
    writeln("Новый кейс сохранен в обучаемой базе и будет доступен в следующей итерации.").

delete_learned_case_interactive :-
    list_learned_cases(Cases),
    ( Cases = [] ->
        writeln("There is nothing to delete.")
    ; prompt_atom("Enter learned case id to delete: ", CaseId),
      ( delete_learned_case(CaseId) ->
          format("Learned case `~w` has been deleted and saved.~n", [CaseId])
      ; true
      )
    ).

prompt_atom(Prompt, Atom) :-
    repeat,
    format("~w", [Prompt]),
    read_line_to_string(user_input, RawInput),
    normalize_space(string(Normalized), RawInput),
    ( Normalized = "" ->
        writeln("Значение не может быть пустым."),
        fail
    ; string_lower(Normalized, Lower),
      atom_string(Atom, Lower),
      !
    ).

prompt_text(Prompt, Text) :-
    repeat,
    format("~w", [Prompt]),
    read_line_to_string(user_input, RawInput),
    normalize_space(string(Text), RawInput),
    ( Text = "" ->
        writeln("Значение не может быть пустым."),
        fail
    ; !
    ).

ask_yes_no(Prompt, Answer) :-
    repeat,
    format("~w~n> ", [Prompt]),
    read_line_to_string(user_input, RawInput),
    normalize_space(string(Normalized), RawInput),
    string_lower(Normalized, Lower),
    ( memberchk(Lower, ["yes", "no"]) ->
        atom_string(Answer, Lower),
        !
    ; writeln("Ожидается yes или no."),
      fail
    ).

option_from_input(Input, Options, Answer) :-
    string_lower(Input, LowerInput),
    member(Answer, Options),
    atom_string(Answer, OptionString),
    string_lower(OptionString, LowerOption),
    LowerInput = LowerOption,
    !.

kb_question(QuestionId, Prompt, Options) :-
    payment_support_learned_facts:question(QuestionId, Prompt, Options),
    !.
kb_question(QuestionId, Prompt, Options) :-
    payment_support_base_facts:question(QuestionId, Prompt, Options).

kb_node_question(NodeId, QuestionId) :-
    payment_support_learned_facts:node_question(NodeId, QuestionId),
    !.
kb_node_question(NodeId, QuestionId) :-
    payment_support_base_facts:node_question(NodeId, QuestionId).

kb_node_branch(NodeId, Answer, Target) :-
    payment_support_learned_facts:branch_override(NodeId, Answer, Target),
    !.
kb_node_branch(NodeId, Answer, Target) :-
    payment_support_learned_facts:node_branch(NodeId, Answer, Target),
    !.
kb_node_branch(NodeId, Answer, Target) :-
    payment_support_base_facts:node_branch(NodeId, Answer, Target).

kb_case_info(CaseId, Title, Explanation, Recommendation) :-
    payment_support_learned_facts:case_info(CaseId, Title, Explanation, Recommendation),
    !.
kb_case_info(CaseId, Title, Explanation, Recommendation) :-
    payment_support_base_facts:case_info(CaseId, Title, Explanation, Recommendation).

kb_case_property(CaseId, Label, Hint) :-
    payment_support_learned_facts:case_property(CaseId, Label, Hint).
kb_case_property(CaseId, Label, Hint) :-
    payment_support_base_facts:case_property(CaseId, Label, Hint).

kb_case_slot(CaseId, Slot, Value) :-
    payment_support_base_facts:case_slot(CaseId, Slot, Value),
    !.
kb_case_slot(CaseId, criticality, medium) :-
    payment_support_learned_facts:case_info(CaseId, _, _, _).
kb_case_slot(CaseId, source, "Дообученный кейс, добавленный оператором.") :-
    payment_support_learned_facts:case_info(CaseId, _, _, _).
kb_case_slot(CaseId, escalation_team, "Оператор поддержки и владелец добавленного кейса.") :-
    payment_support_learned_facts:case_info(CaseId, _, _, _).

print_path([]) :-
    writeln("  Путь пока пустой.").
print_path(Path) :-
    forall(
        member(step(_, QuestionId, Answer), Path),
        print_path_step(QuestionId, Answer)
    ).

print_path_step(QuestionId, Answer) :-
    kb_question(QuestionId, Prompt, _),
    format("  - ~w Ответ: ~w~n", [Prompt, Answer]).

print_case_frame_context(CaseId) :-
    findall(Label-Value, case_context_value(CaseId, Label, Value), Pairs),
    ( Pairs = [] ->
        true
    ; writeln("Фреймовые слоты:"),
      forall(
          member(Label-Value, Pairs),
          format("  - ~w: ~w~n", [Label, Value])
      ),
      nl
    ).

case_context_value(CaseId, "Критичность", Label) :-
    kb_case_slot(CaseId, criticality, Criticality),
    criticality_label(Criticality, Label).
case_context_value(CaseId, "Источник сигнала", Source) :-
    kb_case_slot(CaseId, source, Source).
case_context_value(CaseId, "Команда эскалации", Team) :-
    kb_case_slot(CaseId, escalation_team, Team).

criticality_label(low, "Низкая").
criticality_label(medium, "Средняя").
criticality_label(high, "Высокая").
criticality_label(Criticality, Criticality).

print_case_properties(CaseId) :-
    findall(Label-Hint, kb_case_property(CaseId, Label, Hint), Pairs),
    ( Pairs = [] ->
        writeln("  Для кейса пока не заданы типовые признаки.")
    ; forall(
        member(Label-Hint, Pairs),
        format("  - ~w: ~w~n", [Label, Hint])
      )
    ).

assert_case_properties(_, []).
assert_case_properties(CaseId, [property(Label, Hint) | Rest]) :-
    assertz(payment_support_learned_facts:case_property(CaseId, Label, Hint)),
    assert_case_properties(CaseId, Rest).

remove_extension_facts(CaseId, ParentNode, ParentAnswer, NewNodeId, QuestionId, NewCaseAnswer, OldCaseAnswer, OldCaseId) :-
    retractall(payment_support_learned_facts:branch_override(ParentNode, ParentAnswer, node(NewNodeId))),
    retractall(payment_support_learned_facts:node_question(NewNodeId, QuestionId)),
    retractall(payment_support_learned_facts:node_branch(NewNodeId, NewCaseAnswer, leaf(CaseId))),
    retractall(payment_support_learned_facts:node_branch(NewNodeId, OldCaseAnswer, leaf(OldCaseId))),
    retractall(payment_support_learned_facts:question(QuestionId, _, _)).

learned_case_summary(CaseId, Title, ParentNode, QuestionId) :-
    payment_support_learned_facts:learned_extension(
        CaseId,
        ParentNode,
        _ParentAnswer,
        _NewNodeId,
        QuestionId,
        _NewCaseAnswer,
        _OldCaseAnswer,
        _OldCaseId
    ),
    kb_case_info(CaseId, Title, _Explanation, _Recommendation).

must_be_binary(yes).
must_be_binary(no).

opposite_binary_answer(yes, no).
opposite_binary_answer(no, yes).

new_node_id(NewCaseId, NewNodeId) :-
    atomic_list_concat([learned_node, NewCaseId], '_', NewNodeId).

default_learned_file(Path) :-
    system_directory(Dir),
    directory_file_path(Dir, 'knowledge/learned_facts.pl', Path).

write_learned_header(Stream) :-
    format(Stream, ":- module(payment_support_learned_facts, [~n", []),
    format(Stream, "    question/3,~n", []),
    format(Stream, "    node_question/2,~n", []),
    format(Stream, "    node_branch/3,~n", []),
    format(Stream, "    branch_override/3,~n", []),
    format(Stream, "    case_info/4,~n", []),
    format(Stream, "    case_property/3,~n", []),
    format(Stream, "    learned_extension/8~n", []),
    format(Stream, "]).~n~n", []),
    format(Stream, ":- dynamic question/3.~n", []),
    format(Stream, ":- dynamic node_question/2.~n", []),
    format(Stream, ":- dynamic node_branch/3.~n", []),
    format(Stream, ":- dynamic branch_override/3.~n", []),
    format(Stream, ":- dynamic case_info/4.~n", []),
    format(Stream, ":- dynamic case_property/3.~n", []),
    format(Stream, ":- dynamic learned_extension/8.~n~n", []).

write_learned_facts(Stream) :-
    forall(
        payment_support_learned_facts:question(QuestionId, Prompt, Options),
        portray_clause(Stream, question(QuestionId, Prompt, Options))
    ),
    forall(
        payment_support_learned_facts:node_question(NodeId, QuestionId),
        portray_clause(Stream, node_question(NodeId, QuestionId))
    ),
    forall(
        payment_support_learned_facts:node_branch(NodeId, Answer, Target),
        portray_clause(Stream, node_branch(NodeId, Answer, Target))
    ),
    forall(
        payment_support_learned_facts:branch_override(NodeId, Answer, Target),
        portray_clause(Stream, branch_override(NodeId, Answer, Target))
    ),
    forall(
        payment_support_learned_facts:case_info(CaseId, Title, Explanation, Recommendation),
        portray_clause(Stream, case_info(CaseId, Title, Explanation, Recommendation))
    ),
    forall(
        payment_support_learned_facts:case_property(CaseId, Label, Hint),
        portray_clause(Stream, case_property(CaseId, Label, Hint))
    ),
    forall(
        payment_support_learned_facts:learned_extension(
            CaseId,
            ParentNode,
            ParentAnswer,
            NewNodeId,
            QuestionId,
            NewCaseAnswer,
            OldCaseAnswer,
            OldCaseId
        ),
        portray_clause(
            Stream,
            learned_extension(
                CaseId,
                ParentNode,
                ParentAnswer,
                NewNodeId,
                QuestionId,
                NewCaseAnswer,
                OldCaseAnswer,
                OldCaseId
            )
        )
    ).

load_terms(Stream) :-
    repeat,
    read_term(Stream, Term, []),
    ( Term == end_of_file ->
        !
    ; load_term(Term),
      fail
    ).

load_term((:- _)) :-
    !.
load_term(Fact) :-
    functor(Fact, Name, Arity),
    allowed_learned_predicate(Name/Arity),
    assertz(payment_support_learned_facts:Fact).

allowed_learned_predicate(question/3).
allowed_learned_predicate(node_question/2).
allowed_learned_predicate(node_branch/3).
allowed_learned_predicate(branch_override/3).
allowed_learned_predicate(case_info/4).
allowed_learned_predicate(case_property/3).
allowed_learned_predicate(learned_extension/8).


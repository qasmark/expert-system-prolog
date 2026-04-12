:- begin_tests(payment_support_expert_system).

:- use_module('../payment_support_expert_system.pl').
:- use_module('../knowledge/base_facts.pl').
:- use_module('../knowledge/learned_facts.pl').
:- use_module(library(filesex)).
:- use_module(library(readutil)).

cleanup_state :-
    reset_session,
    reset_learned_knowledge.

seed_manual_bank_hold :-
    learn_new_case(
        reason_node,
        issuer_decline,
        user_payment_error,
        manual_bank_hold,
        "Ручная блокировка банком",
        "Сценарий похож на обычную ошибку оплаты, но платеж задержан из-за ручной проверки банком.",
        "Проверить коды эмитента, предупредить пользователя о ручной проверке и предложить повторную попытку позже.",
        manual_hold_indicator,
        "Есть ли признак ручной проверки банком? Введите: yes или no.",
        yes,
        [
            property("Код ответа банка-эмитента", "Часто содержит сервисные коды ручной проверки."),
            property("ID пользователя", "Нужен для поиска повторных обращений по ручной блокировке.")
        ]
    ).

with_temp_system_directory(TempDir, Goal) :-
    payment_support_expert_system:system_directory(OriginalDir),
    tmp_file(expert_system_dir, TempDir),
    make_directory_path(TempDir),
    directory_file_path(TempDir, knowledge, KnowledgeDir),
    make_directory_path(KnowledgeDir),
    setup_call_cleanup(
        (
            payment_support_expert_system:retractall(system_directory(_)),
            payment_support_expert_system:assertz(system_directory(TempDir))
        ),
        Goal,
        (
            payment_support_expert_system:retractall(system_directory(_)),
            payment_support_expert_system:assertz(system_directory(OriginalDir)),
            delete_directory_and_contents(TempDir)
        )
    ).

test(route_mass_failure_case, [setup(cleanup_state), cleanup(cleanup_state)]) :-
    remember_answer(mass_issue, yes),
    remember_answer(http_status_family, http_5xx),
    diagnose(CaseId, Path),
    assertion(payment_support_expert_system:known_answer(mass_issue, yes)),
    assertion(CaseId == gateway_sbp_failure),
    assertion(Path == [
        step(root, mass_issue, yes),
        step(mass_issue_node, http_status_family, http_5xx)
    ]).

test(route_anti_fraud_case, [setup(cleanup_state), cleanup(cleanup_state)]) :-
    remember_answer(mass_issue, no),
    remember_answer(decline_reason_present, yes),
    remember_answer(decline_reason_kind, anti_fraud),
    diagnose(CaseId),
    assertion(CaseId == anti_fraud_block).

test(frame_properties_inherit_and_override, [setup(cleanup_state), cleanup(cleanup_state)]) :-
    assertion(case_property(anti_fraud_block, "Маска карты", "Нужна для корреляции повторных обращений.")),
    assertion(case_property(anti_fraud_block, "ID пользователя", "Нужен для поиска истории срабатываний и связанных рисков.")),
    assertion(\+ case_property(anti_fraud_block, "ID пользователя", "Помогает проверить историю обращения пользователя.")).

test(bayesian_probability_is_calculated_for_selected_case, [setup(cleanup_state), cleanup(cleanup_state)]) :-
    remember_answer(mass_issue, yes),
    remember_answer(http_status_family, http_5xx),
    diagnose(CaseId),
    diagnosis_confidence(CaseId, Probability),
    assertion(CaseId == gateway_sbp_failure),
    assertion(Probability > 0.80),
    assertion(Probability < 1.0).

test(learned_branch_is_added_via_assertz, [setup(cleanup_state), cleanup(cleanup_state)]) :-
    seed_manual_bank_hold,
    assertion(payment_support_learned_facts:branch_override(reason_node, issuer_decline, node(learned_node_manual_bank_hold))),
    assertion(payment_support_learned_facts:node_question(learned_node_manual_bank_hold, manual_hold_indicator)),
    assertion(payment_support_learned_facts:node_branch(learned_node_manual_bank_hold, yes, leaf(manual_bank_hold))),
    remember_answer(mass_issue, no),
    remember_answer(decline_reason_present, yes),
    remember_answer(decline_reason_kind, issuer_decline),
    remember_answer(manual_hold_indicator, yes),
    diagnose(CaseId),
    assertion(CaseId == manual_bank_hold).

test(list_learned_cases_returns_metadata, [setup(cleanup_state), cleanup(cleanup_state)]) :-
    seed_manual_bank_hold,
    list_learned_cases(Cases),
    assertion(Cases == [
        case(manual_bank_hold, "Ручная блокировка банком", reason_node, manual_hold_indicator)
    ]).

test(persist_and_reload_learned_knowledge, [setup(cleanup_state), cleanup(cleanup_state)]) :-
    tmp_file_stream(text, Path, Stream),
    close(Stream),
    call_cleanup(
        (
            seed_manual_bank_hold,
            save_learned_knowledge(Path),
            read_file_to_string(Path, Contents, []),
            sub_string(Contents, _, _, _, "branch_override(reason_node, issuer_decline, node(learned_node_manual_bank_hold))."),
            reset_learned_knowledge,
            load_learned_knowledge(Path),
            reset_session,
            remember_answer(mass_issue, no),
            remember_answer(decline_reason_present, yes),
            remember_answer(decline_reason_kind, issuer_decline),
            remember_answer(manual_hold_indicator, yes),
            diagnose(CaseId),
            assertion(CaseId == manual_bank_hold)
        ),
        ( exists_file(Path) -> delete_file(Path) ; true )
    ).

test(delete_learned_case_updates_saved_file, [setup(cleanup_state), cleanup(cleanup_state)]) :-
    with_temp_system_directory(TempDir,
        (
            seed_manual_bank_hold,
            delete_learned_case(manual_bank_hold),
            assertion(\+ payment_support_learned_facts:learned_extension(manual_bank_hold, _, _, _, _, _, _, _)),
            directory_file_path(TempDir, 'knowledge/learned_facts.pl', LearnedPath),
            assertion(exists_file(LearnedPath)),
            read_file_to_string(LearnedPath, Contents, []),
            assertion(\+ sub_string(Contents, _, _, _, "manual_bank_hold"))
        )
    ).

test(remove_learned_case_restores_base_leaf, [setup(cleanup_state), cleanup(cleanup_state)]) :-
    seed_manual_bank_hold,
    remove_learned_case(manual_bank_hold),
    assertion(\+ payment_support_learned_facts:branch_override(reason_node, issuer_decline, _)),
    reset_session,
    remember_answer(mass_issue, no),
    remember_answer(decline_reason_present, yes),
    remember_answer(decline_reason_kind, issuer_decline),
    diagnose(CaseId),
    assertion(CaseId == user_payment_error).

:- end_tests(payment_support_expert_system).


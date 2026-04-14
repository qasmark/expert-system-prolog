:- begin_tests(payment_support_expert_system).

:- use_module('../payment_support_expert_system.pl').
:- use_module('../knowledge/base_facts.pl').
:- use_module('../knowledge/learned_facts.pl').
:- use_module('../knowledge/bayesian_facts.pl', [diagnosis_probability/3]).
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

% Обоснование: «массовый сбой» в CPT сильнее согласуется с отказом шлюза (0.90), чем с его
% отсутствием (0.10). При фиксированном HTTP 5xx апостериорная вероятность gateway_sbp_failure
% выше, если массовый сбой есть — аналог «при грозе вероятность взлома/сбоя инфраструктуры выше».
test(bayesian_dependent_mass_issue_increases_posterior_gateway_sbp_vs_no_mass_issue, []) :-
    diagnosis_probability(
        gateway_sbp_failure,
        [mass_issue-yes, http_status_family-http_5xx],
        P_with_mass
    ),
    diagnosis_probability(
        gateway_sbp_failure,
        [mass_issue-no, http_status_family-http_5xx],
        P_without_mass
    ),
    assertion(P_with_mass > P_without_mass).

% Обоснование: при массовом сбое индивидуальная антифрод-блокировка маловероятна как объяснение
% (CPT mass_issue: yes 0.05 против no 0.95). При том же «мягком» HTTP 2xx/timeout уверенность
% в anti_fraud_block выше, когда массового сбоя нет.
test(bayesian_dependent_mass_issue_decreases_posterior_anti_fraud_vs_no_mass_issue, []) :-
    diagnosis_probability(
        anti_fraud_block,
        [mass_issue-no, http_status_family-http_2xx_or_timeout],
        P_no_mass
    ),
    diagnosis_probability(
        anti_fraud_block,
        [mass_issue-yes, http_status_family-http_2xx_or_timeout],
        P_mass
    ),
    assertion(P_no_mass > P_mass).

% Обоснование: для отказа шлюза HTTP 5xx в CPT существенно вероятнее (0.55), чем 2xx/timeout (0.40).
% При том же массовом сбое апостериор gateway_sbp_failure выше при кодах 5xx.
test(bayesian_dependent_http_5xx_increases_posterior_gateway_sbp_vs_2xx, []) :-
    diagnosis_probability(
        gateway_sbp_failure,
        [mass_issue-yes, http_status_family-http_5xx],
        P_5xx
    ),
    diagnosis_probability(
        gateway_sbp_failure,
        [mass_issue-yes, http_status_family-http_2xx_or_timeout],
        P_2xx
    ),
    assertion(P_5xx > P_2xx).

% Обоснование: наличие причины отказа в данных (decline_reason_present=yes) для антифрода гораздо
% типичнее (0.90), чем её отсутствие (0.10). При том же kind=anti_fraud апостериор anti_fraud_block
% выше, если отказ явно зафиксирован.
test(bayesian_dependent_decline_reported_increases_posterior_anti_fraud, []) :-
    diagnosis_probability(
        anti_fraud_block,
        [decline_reason_present-yes, decline_reason_kind-anti_fraud],
        P_decline_yes
    ),
    diagnosis_probability(
        anti_fraud_block,
        [decline_reason_present-no, decline_reason_kind-anti_fraud],
        P_decline_no
    ),
    assertion(P_decline_yes > P_decline_no).

% Обоснование: для сбоя шлюза явная причина отказа в ответе редка (CPT 0.10 против 0.90), тогда как
% для других диагнозов она ожидаемее. При том же HTTP 5xx вероятность gateway_sbp_failure ниже,
% если decline_reason_present=yes.
test(bayesian_dependent_decline_reported_decreases_posterior_gateway_sbp, []) :-
    diagnosis_probability(
        gateway_sbp_failure,
        [http_status_family-http_5xx, decline_reason_present-no],
        P_no_decline
    ),
    diagnosis_probability(
        gateway_sbp_failure,
        [http_status_family-http_5xx, decline_reason_present-yes],
        P_decline
    ),
    assertion(P_no_decline > P_decline).

% Обоснование: ошибка интеграции в CPT сильнее связана с validation_error (0.80), чем с anti_fraud
% (0.05). Апостериор api_integration_error выше при kind=validation_error при отсутствии прочих признаков.
test(bayesian_dependent_validation_error_increases_posterior_api_integration_vs_anti_fraud_kind, []) :-
    diagnosis_probability(
        api_integration_error,
        [decline_reason_kind-validation_error],
        P_validation
    ),
    diagnosis_probability(
        api_integration_error,
        [decline_reason_kind-anti_fraud],
        P_anti_fraud
    ),
    assertion(P_validation > P_anti_fraud).

% Обоснование: недоставленное SMS 3-D Secure гораздо чаще при ошибке пользователя (0.35), чем
% успешно отправленное (0.10). Апостериор user_payment_error выше при not_delivered, чем при sent.
test(bayesian_dependent_sms_not_delivered_increases_posterior_user_payment_vs_sent, []) :-
    diagnosis_probability(
        user_payment_error,
        [sms_3ds_status-not_delivered],
        P_bad
    ),
    diagnosis_probability(
        user_payment_error,
        [sms_3ds_status-sent],
        P_ok
    ),
    assertion(P_bad > P_ok).

% Обоснование: для user_payment_error коды 4xx в CPT чуть вероятнее (0.10), чем 5xx (0.05); при прочих
% равных апостериор user_payment_error выше при http_4xx, чем при http_5xx (зависимое событие
% «семейство HTTP» сдвигает баланс в пользу пользовательской/клиентской ошибки).
test(bayesian_dependent_http_4xx_increases_posterior_user_payment_vs_5xx, []) :-
    diagnosis_probability(
        user_payment_error,
        [http_status_family-http_4xx],
        P_4xx
    ),
    diagnosis_probability(
        user_payment_error,
        [http_status_family-http_5xx],
        P_5xx
    ),
    assertion(P_4xx > P_5xx).

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


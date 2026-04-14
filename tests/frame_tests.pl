:- begin_tests(frame_knowledge).

:- use_module('../knowledge/base_facts.pl').

test(inherits_second_level_slots) :-
    assertion(case_slot(gateway_sbp_failure, source, "Мониторинг платформы, алерты и массовые обращения клиентов.")),
    assertion(case_slot(gateway_sbp_failure, escalation_team, "Дежурная смена и команда сопровождения шлюза.")),
    assertion(case_slot(anti_fraud_block, source, "Обращение пользователя и ответ банка-эмитента.")).

test(overrides_criticality_in_child_frames) :-
    assertion(case_slot(gateway_sbp_failure, criticality, high)),
    assertion(case_slot(anti_fraud_block, criticality, high)),
    assertion(case_slot(user_payment_error, criticality, low)).

test(overrides_property_by_key) :-
    assertion(case_property(anti_fraud_block, "Маска карты", "Нужна для корреляции повторных обращений.")),
    assertion(case_property(anti_fraud_block, "ID пользователя", "Нужен для поиска истории срабатываний и связанных рисков.")),
    assertion(\+ case_property(anti_fraud_block, "ID пользователя", "Помогает проверить историю обращения пользователя.")),
    assertion(case_property(api_integration_error, "Код ответа HTTP", "Позволяет быстро отделить клиентскую ошибку от серверной.")),
    assertion(\+ case_property(api_integration_error, "Код ответа HTTP", "Базовый индикатор того, в каком слое возникла ошибка.")).

test(builds_case_info_from_frame_slots) :-
    case_info(
        gateway_sbp_failure,
        Title,
        Explanation,
        Recommendation
    ),
    assertion(Title == "Массовый сбой шлюза СБП"),
    assertion(Explanation == "Наблюдается массовый инцидент на стороне шлюза или внешнего канала СБП."),
    assertion(Recommendation == "Проверить тип банка-эквайера, место сбоя и тип ошибки в мониторинге. Зафиксировать массовость, оповестить дежурную смену и открыть инцидент на шлюз СБП.").

test(inherits_generic_slots_for_unknown_case) :-
    assertion(case_slot(unknown_situation, criticality, medium)),
    assertion(case_slot(unknown_situation, source, "Обращение в поддержку или сигнал мониторинга платежной платформы.")).

:- end_tests(frame_knowledge).

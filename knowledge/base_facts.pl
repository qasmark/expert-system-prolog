:- module(payment_support_base_facts, [
    root_node/1,
    question/3,
    node_question/2,
    node_branch/3,
    frame_parent/2,
    frame_slot/3,
    case_info/4,
    case_property/3
]).

:- use_module(library(lists)).

root_node(root).

question(
    mass_issue,
    "Проблема носит массовый характер? Введите: yes или no.",
    [yes, no]
).
question(
    http_status_family,
    "Какой класс HTTP-ответа виден в логах? Введите: http_5xx, http_4xx или http_2xx_or_timeout.",
    [http_5xx, http_4xx, http_2xx_or_timeout]
).
question(
    decline_reason_present,
    "Есть ли в ответе платежной системы явная причина отклонения? Введите: yes или no.",
    [yes, no]
).
question(
    decline_reason_kind,
    "Какая причина отклонения указана? Введите: anti_fraud, issuer_decline или validation_error.",
    [anti_fraud, issuer_decline, validation_error]
).
question(
    sms_3ds_status,
    "Какой статус у СМС-подтверждения 3-D Secure? Введите: sent, not_delivered, expired или not_requested.",
    [sent, not_delivered, expired, not_requested]
).

node_question(root, mass_issue).
node_branch(root, yes, node(mass_issue_node)).
node_branch(root, no, node(single_issue_node)).

node_question(mass_issue_node, http_status_family).
node_branch(mass_issue_node, http_5xx, leaf(gateway_sbp_failure)).
node_branch(mass_issue_node, http_2xx_or_timeout, leaf(gateway_sbp_failure)).
node_branch(mass_issue_node, http_4xx, leaf(api_integration_error)).

node_question(single_issue_node, decline_reason_present).
node_branch(single_issue_node, yes, node(reason_node)).
node_branch(single_issue_node, no, node(three_ds_node)).

node_question(reason_node, decline_reason_kind).
node_branch(reason_node, anti_fraud, leaf(anti_fraud_block)).
node_branch(reason_node, issuer_decline, leaf(user_payment_error)).
node_branch(reason_node, validation_error, leaf(api_integration_error)).

node_question(three_ds_node, sms_3ds_status).
node_branch(three_ds_node, not_delivered, leaf(user_payment_error)).
node_branch(three_ds_node, expired, leaf(user_payment_error)).
node_branch(three_ds_node, sent, leaf(api_integration_error)).
node_branch(three_ds_node, not_requested, leaf(api_integration_error)).

frame_parent(api_integration_error, integration_case).
frame_parent(anti_fraud_block, user_payment_case).
frame_parent(user_payment_error, user_payment_case).
frame_parent(gateway_sbp_failure, mass_incident_case).
frame_parent(unknown_situation, generic_support_case).

frame_slot(generic_support_case, title, "Неопределенная ситуация").
frame_slot(generic_support_case, explanation, "По текущим ответам в дереве нет подходящего листа.").
frame_slot(generic_support_case, recommendation, "Соберите недостающие признаки и при подтверждении нового сценария добавьте новый кейс в обучаемую базу.").

frame_slot(integration_case, property(merchant_id), property("ID мерчанта", "Помогает локализовать интеграцию и проверить настройки мерчанта.")).
frame_slot(integration_case, property(api_method), property("Метод API", "Нужно понять, на каком API-методе воспроизводится ошибка.")).
frame_slot(integration_case, property(http_status), property("Код ответа HTTP", "Базовый индикатор того, в каком слое возникла ошибка.")).

frame_slot(user_payment_case, property(issuer_response_code), property("Код ответа банка-эмитента", "Основной индикатор причины пользовательского отказа.")).
frame_slot(user_payment_case, property(sms_3ds_status), property("Статус СМС-подтверждения", "Позволяет отделить эмитентский отказ от проблемы 3-D Secure.")).
frame_slot(user_payment_case, property(card_mask), property("Маска карты", "Нужна для корреляции повторных обращений.")).
frame_slot(user_payment_case, property(user_id), property("ID пользователя", "Помогает проверить историю обращения пользователя.")).

frame_slot(mass_incident_case, property(issue_scope), property("Массовость", "Подтверждает, что это системный, а не точечный кейс.")).
frame_slot(mass_incident_case, property(failure_scope), property("Место сбоя", "Нужно локализовать, на каком участке цепочки проявляется инцидент.")).

frame_slot(api_integration_error, title, "Ошибка API/интеграции").
frame_slot(api_integration_error, explanation, "Система видит признаки проблемы в контракте API, формате запроса или обработке интеграционного ответа.").
frame_slot(api_integration_error, recommendation, "Проверить ID мерчанта, метод API, HTTP-код, тело запроса и сопоставить их с контрактом интеграции. Если ошибка воспроизводится, эскалировать в команду интеграции.").
frame_slot(api_integration_error, property(http_status), property("Код ответа HTTP", "Позволяет быстро отделить клиентскую ошибку от серверной.")).
frame_slot(api_integration_error, property(request_body), property("Тело запроса", "Нужно для проверки обязательных полей и формата payload.")).

frame_slot(anti_fraud_block, title, "Блокировка аккаунта антифродом").
frame_slot(anti_fraud_block, explanation, "Платеж отклоняется внутренними правилами безопасности или антифрод-модулем.").
frame_slot(anti_fraud_block, recommendation, "Уточнить ID пользователя, маску карты, причину срабатывания и сумму транзакции. Проверить антифрод-правила, историю пользователя и при необходимости передать запрос в риск-команду.").
frame_slot(anti_fraud_block, property(user_id), property("ID пользователя", "Нужен для поиска истории срабатываний и связанных рисков.")).
frame_slot(anti_fraud_block, property(trigger_reason), property("Причина срабатывания", "Ключевой классификатор для антифрод-решения.")).
frame_slot(anti_fraud_block, property(transaction_amount), property("Сумма транзакции", "Часто участвует в антифрод-правилах и порогах.")).

frame_slot(gateway_sbp_failure, title, "Массовый сбой шлюза СБП").
frame_slot(gateway_sbp_failure, explanation, "Наблюдается массовый инцидент на стороне шлюза или внешнего канала СБП.").
frame_slot(gateway_sbp_failure, recommendation, "Проверить тип банка-эквайера, место сбоя и тип ошибки в мониторинге. Зафиксировать массовость, оповестить дежурную смену и открыть инцидент на шлюз СБП.").
frame_slot(gateway_sbp_failure, property(acquirer_bank_type), property("Тип банка-эквайера", "Нужен для понимания, есть ли зависимость от конкретного провайдера.")).
frame_slot(gateway_sbp_failure, property(failure_scope), property("Место сбоя", "Позволяет отличить сбой шлюза от внутренних ошибок маршрутизации.")).
frame_slot(gateway_sbp_failure, property(error_type), property("Тип ошибки", "Уточняет технический характер инцидента.")).

frame_slot(user_payment_error, title, "Ошибка оплаты пользователя").
frame_slot(user_payment_error, explanation, "Проблема локализована на одной оплате или у ограниченного числа пользователей и чаще связана с эмитентом или 3-D Secure.").
frame_slot(user_payment_error, recommendation, "Уточнить код ответа банка-эмитента, статус СМС-подтверждения, маску карты и ID пользователя. Проверить ограничения банка, доступность 3-D Secure и дать пользователю инструкцию по повторной попытке.").

case_info(CaseId, Title, Explanation, Recommendation) :-
    inherited_frame_slot(CaseId, title, Title),
    inherited_frame_slot(CaseId, explanation, Explanation),
    inherited_frame_slot(CaseId, recommendation, Recommendation).

case_property(CaseId, Label, Hint) :-
    inherited_case_properties(CaseId, Properties),
    member(property(Label, Hint), Properties).

inherited_frame_slot(Frame, Slot, Value) :-
    frame_slot(Frame, Slot, Value),
    !.
inherited_frame_slot(Frame, Slot, Value) :-
    frame_parent(Frame, Parent),
    inherited_frame_slot(Parent, Slot, Value).

inherited_case_properties(Frame, Properties) :-
    frame_lineage(Frame, Lineage),
    foldl(merge_frame_properties, Lineage, [], PropertyPairs),
    property_values(PropertyPairs, Properties).

frame_lineage(Frame, Lineage) :-
    ( frame_parent(Frame, Parent) ->
        frame_lineage(Parent, ParentLineage),
        append(ParentLineage, [Frame], Lineage)
    ; Lineage = [Frame]
    ).

merge_frame_properties(Frame, Acc0, Acc) :-
    findall(Key-Property, frame_slot(Frame, property(Key), Property), FrameProperties),
    foldl(upsert_property, FrameProperties, Acc0, Acc).

upsert_property(Key-Property, Acc0, Acc) :-
    remove_property_key(Key, Acc0, Filtered),
    append(Filtered, [Key-Property], Acc).

remove_property_key(_, [], []).
remove_property_key(Key, [Key-_|Rest], Filtered) :-
    !,
    remove_property_key(Key, Rest, Filtered).
remove_property_key(Key, [Pair|Rest], [Pair|Filtered]) :-
    remove_property_key(Key, Rest, Filtered).

property_values([], []).
property_values([_-Property|Rest], [Property|Values]) :-
    property_values(Rest, Values).


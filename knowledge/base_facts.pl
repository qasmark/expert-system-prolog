:- module(payment_support_base_facts, [
    root_node/1,
    question/3,
    node_question/2,
    node_branch/3,
    case_info/4,
    case_property/3
]).

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

case_info(
    api_integration_error,
    "Ошибка API/интеграции",
    "Система видит признаки проблемы в контракте API, формате запроса или обработке интеграционного ответа.",
    "Проверить ID мерчанта, метод API, HTTP-код, тело запроса и сопоставить их с контрактом интеграции. Если ошибка воспроизводится, эскалировать в команду интеграции."
).
case_info(
    anti_fraud_block,
    "Блокировка аккаунта антифродом",
    "Платеж отклоняется внутренними правилами безопасности или антифрод-модулем.",
    "Уточнить ID пользователя, маску карты, причину срабатывания и сумму транзакции. Проверить антифрод-правила, историю пользователя и при необходимости передать запрос в риск-команду."
).
case_info(
    gateway_sbp_failure,
    "Массовый сбой шлюза СБП",
    "Наблюдается массовый инцидент на стороне шлюза или внешнего канала СБП.",
    "Проверить тип банка-эквайера, место сбоя и тип ошибки в мониторинге. Зафиксировать массовость, оповестить дежурную смену и открыть инцидент на шлюз СБП."
).
case_info(
    user_payment_error,
    "Ошибка оплаты пользователя",
    "Проблема локализована на одной оплате или у ограниченного числа пользователей и чаще связана с эмитентом или 3-D Secure.",
    "Уточнить код ответа банка-эмитента, статус СМС-подтверждения, маску карты и ID пользователя. Проверить ограничения банка, доступность 3-D Secure и дать пользователю инструкцию по повторной попытке."
).
case_info(
    unknown_situation,
    "Неопределенная ситуация",
    "По текущим ответам в дереве нет подходящего листа.",
    "Соберите недостающие признаки и при подтверждении нового сценария добавьте новый кейс в обучаемую базу."
).

case_property(api_integration_error, "ID мерчанта", "Помогает локализовать интеграцию и проверить настройки мерчанта.").
case_property(api_integration_error, "Метод API", "Нужно понять, на каком API-методе воспроизводится ошибка.").
case_property(api_integration_error, "Код ответа HTTP", "Позволяет быстро отделить клиентскую ошибку от серверной.").
case_property(api_integration_error, "Тело запроса", "Нужно для проверки обязательных полей и формата payload.").

case_property(anti_fraud_block, "ID пользователя", "Нужен для поиска истории срабатываний и связанных рисков.").
case_property(anti_fraud_block, "Маска карты", "Помогает проверить повторяемость блокировок по платежному инструменту.").
case_property(anti_fraud_block, "Причина срабатывания", "Ключевой классификатор для антифрод-решения.").
case_property(anti_fraud_block, "Сумма транзакции", "Часто участвует в антифрод-правилах и порогах.").

case_property(gateway_sbp_failure, "Тип банка-эквайера", "Нужен для понимания, есть ли зависимость от конкретного провайдера.").
case_property(gateway_sbp_failure, "Место сбоя", "Позволяет отличить сбой шлюза от внутренних ошибок маршрутизации.").
case_property(gateway_sbp_failure, "Тип ошибки", "Уточняет технический характер инцидента.").
case_property(gateway_sbp_failure, "Массовость", "Подтверждает, что это системный, а не точечный кейс.").

case_property(user_payment_error, "Код ответа банка-эмитента", "Основной индикатор причины пользовательского отказа.").
case_property(user_payment_error, "Статус СМС-подтверждения", "Позволяет отделить эмитентский отказ от проблемы 3-D Secure.").
case_property(user_payment_error, "Маска карты", "Нужна для корреляции повторных обращений.").
case_property(user_payment_error, "ID пользователя", "Нужен для проверки истории и связи с другими обращениями.").


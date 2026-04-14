:- module(payment_support_learned_facts, [
    question/3,
    node_question/2,
    node_branch/3,
    branch_override/3,
    case_info/4,
    case_property/3,
    learned_extension/8
]).

:- dynamic question/3.
:- dynamic node_question/2.
:- dynamic node_branch/3.
:- dynamic branch_override/3.
:- dynamic case_info/4.
:- dynamic case_property/3.
:- dynamic learned_extension/8.

question(identification_error, "Регистрация пройдена правильно?", [yes, no]).
node_question(learned_node_user_identification_error, identification_error).
node_branch(learned_node_user_identification_error, no, leaf(user_identification_error)).
node_branch(learned_node_user_identification_error, yes, leaf(user_payment_error)).
branch_override(reason_node, issuer_decline, node(learned_node_user_identification_error)).
case_info(user_identification_error, "Ошибка идентификации пользователя", "Пользователь не предоставил все данные, отсутствует СНИЛС, паспорт и т.д.", "проверьте в личном кабинете пользователдя все данные").
case_property(user_identification_error, "identification_request", "упрощенная идентификация").
learned_extension(user_identification_error, reason_node, issuer_decline, learned_node_user_identification_error, identification_error, no, yes, user_payment_error).

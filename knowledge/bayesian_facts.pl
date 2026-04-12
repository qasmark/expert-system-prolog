:- module(payment_support_bayesian_facts, [
    bayesian_symptom/1,
    diagnosis_probability/3
]).

:- use_module(library(lists)).

diagnosis(api_integration_error).
diagnosis(anti_fraud_block).
diagnosis(gateway_sbp_failure).
diagnosis(user_payment_error).

diagnosis_prior(api_integration_error, 0.30).
diagnosis_prior(anti_fraud_block, 0.20).
diagnosis_prior(gateway_sbp_failure, 0.15).
diagnosis_prior(user_payment_error, 0.35).

parent(diagnosis, mass_issue).
parent(diagnosis, http_status_family).
parent(diagnosis, decline_reason_present).
parent(diagnosis, decline_reason_kind).
parent(diagnosis, sms_3ds_status).

bayesian_symptom(Symptom) :-
    parent(diagnosis, Symptom).

cpt(mass_issue, api_integration_error, yes, 0.25).
cpt(mass_issue, api_integration_error, no, 0.75).
cpt(mass_issue, anti_fraud_block, yes, 0.05).
cpt(mass_issue, anti_fraud_block, no, 0.95).
cpt(mass_issue, gateway_sbp_failure, yes, 0.90).
cpt(mass_issue, gateway_sbp_failure, no, 0.10).
cpt(mass_issue, user_payment_error, yes, 0.10).
cpt(mass_issue, user_payment_error, no, 0.90).

cpt(http_status_family, api_integration_error, http_5xx, 0.15).
cpt(http_status_family, api_integration_error, http_4xx, 0.60).
cpt(http_status_family, api_integration_error, http_2xx_or_timeout, 0.25).
cpt(http_status_family, anti_fraud_block, http_5xx, 0.05).
cpt(http_status_family, anti_fraud_block, http_4xx, 0.20).
cpt(http_status_family, anti_fraud_block, http_2xx_or_timeout, 0.75).
cpt(http_status_family, gateway_sbp_failure, http_5xx, 0.55).
cpt(http_status_family, gateway_sbp_failure, http_4xx, 0.05).
cpt(http_status_family, gateway_sbp_failure, http_2xx_or_timeout, 0.40).
cpt(http_status_family, user_payment_error, http_5xx, 0.05).
cpt(http_status_family, user_payment_error, http_4xx, 0.10).
cpt(http_status_family, user_payment_error, http_2xx_or_timeout, 0.85).

cpt(decline_reason_present, api_integration_error, yes, 0.35).
cpt(decline_reason_present, api_integration_error, no, 0.65).
cpt(decline_reason_present, anti_fraud_block, yes, 0.90).
cpt(decline_reason_present, anti_fraud_block, no, 0.10).
cpt(decline_reason_present, gateway_sbp_failure, yes, 0.10).
cpt(decline_reason_present, gateway_sbp_failure, no, 0.90).
cpt(decline_reason_present, user_payment_error, yes, 0.55).
cpt(decline_reason_present, user_payment_error, no, 0.45).

cpt(decline_reason_kind, api_integration_error, anti_fraud, 0.05).
cpt(decline_reason_kind, api_integration_error, issuer_decline, 0.15).
cpt(decline_reason_kind, api_integration_error, validation_error, 0.80).
cpt(decline_reason_kind, anti_fraud_block, anti_fraud, 0.85).
cpt(decline_reason_kind, anti_fraud_block, issuer_decline, 0.10).
cpt(decline_reason_kind, anti_fraud_block, validation_error, 0.05).
cpt(decline_reason_kind, gateway_sbp_failure, anti_fraud, 0.05).
cpt(decline_reason_kind, gateway_sbp_failure, issuer_decline, 0.20).
cpt(decline_reason_kind, gateway_sbp_failure, validation_error, 0.75).
cpt(decline_reason_kind, user_payment_error, anti_fraud, 0.10).
cpt(decline_reason_kind, user_payment_error, issuer_decline, 0.70).
cpt(decline_reason_kind, user_payment_error, validation_error, 0.20).

cpt(sms_3ds_status, api_integration_error, sent, 0.35).
cpt(sms_3ds_status, api_integration_error, not_delivered, 0.10).
cpt(sms_3ds_status, api_integration_error, expired, 0.10).
cpt(sms_3ds_status, api_integration_error, not_requested, 0.45).
cpt(sms_3ds_status, anti_fraud_block, sent, 0.30).
cpt(sms_3ds_status, anti_fraud_block, not_delivered, 0.15).
cpt(sms_3ds_status, anti_fraud_block, expired, 0.15).
cpt(sms_3ds_status, anti_fraud_block, not_requested, 0.40).
cpt(sms_3ds_status, gateway_sbp_failure, sent, 0.25).
cpt(sms_3ds_status, gateway_sbp_failure, not_delivered, 0.20).
cpt(sms_3ds_status, gateway_sbp_failure, expired, 0.20).
cpt(sms_3ds_status, gateway_sbp_failure, not_requested, 0.35).
cpt(sms_3ds_status, user_payment_error, sent, 0.10).
cpt(sms_3ds_status, user_payment_error, not_delivered, 0.35).
cpt(sms_3ds_status, user_payment_error, expired, 0.30).
cpt(sms_3ds_status, user_payment_error, not_requested, 0.25).

diagnosis_probability(CaseId, Evidence, Probability) :-
    diagnosis(CaseId),
    diagnosis_prior(CaseId, Prior),
    evidence_likelihood(CaseId, Evidence, Likelihood),
    Numerator is Prior * Likelihood,
    findall(
        Score,
        (
            diagnosis(OtherCaseId),
            diagnosis_prior(OtherCaseId, OtherPrior),
            evidence_likelihood(OtherCaseId, Evidence, OtherLikelihood),
            Score is OtherPrior * OtherLikelihood
        ),
        Scores
    ),
    sum_list(Scores, Denominator),
    ( Denominator =:= 0.0 ->
        Probability = 0.0
    ; Probability is Numerator / Denominator
    ).

evidence_likelihood(CaseId, Evidence, Likelihood) :-
    findall(
        Probability,
        (
            member(Symptom-Value, Evidence),
            bayesian_symptom(Symptom),
            cpt(Symptom, CaseId, Value, Probability)
        ),
        Probabilities
    ),
    multiply_probabilities(Probabilities, Likelihood).

multiply_probabilities([], 1.0).
multiply_probabilities([Probability|Rest], Product) :-
    multiply_probabilities(Rest, RestProduct),
    Product is Probability * RestProduct.

base_ticket(status, opened).
base_ticket(priority, medium).
base_ticket(resolution_time, 24).

vip_ticket(a_kind_of, base_ticket).
vip_ticket(priority, high).
vip_ticket(manager, senior_support).
vip_ticket(resolution_time, 4).

tech_ticket(a_kind_of, base_ticket).
tech_ticket(department, it_operations).
tech_ticket(requires_logs, true).

api_error_ticket(a_kind_of, tech_ticket).
api_error_ticket(priority, urgent).
api_error_ticket(resolution_time, execute(calc_api_eta(Frame, Value), Frame, Value)).

'VIP-8801'(instance_of, vip_ticket).
'VIP-8801'(client_id, 777).
'VIP-8801'(problem, sbp_failure).

'API-3099'(instance_of, api_error_ticket).
'API-3099'(client_id, 102).
'API-3099'(status, in_progress).

'B2C-5510'(instance_of, base_ticket).
'B2C-5510'(problem, refund_request).

calc_api_eta(Ticket, ETA) :-
(parent(Ticket, vip_ticket) -> ETA = 2 ; ETA = 12).

parent(Frame, ParentFrame) :-
(Query =.. [Frame, a_kind_of, ParentFrame] ; Query =.. [Frame, instance_of, ParentFrame]),
call(Query).

value(Frame, Slot, Value) :-
value(Frame, Frame, Slot, Value).

value(Frame, SuperFrame, Slot, Value) :-
Query =.. [SuperFrame, Slot, Information],
call(Query),
prosess(Information, Frame, Value), !.

value(Frame, SuperFrame, Slot, Value) :-
parent(SuperFrame, ParentSuperFrame),
value(Frame, ParentSuperFrame, Slot, Value).

prosess(execute(Goal, Frame, Value), Frame, Value) :-
call(Goal).
prosess(Value, _, Value).
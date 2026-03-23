% tickets_bayes.pl

parent(vip_client, critical_priority).
parent(api_error, critical_priority).
parent(api_error, dev_needed).
parent(critical_priority, long_resolution).
parent(dev_needed, long_resolution).

p(vip_client, 0.1). % 10% клиентов - VIP
p(api_error, 0.2). % 20% всех проблем - ошибки API

p(critical_priority, [vip_client, api_error], 0.9).
p(critical_priority, [vip_client, not(api_error)], 0.5).
p(critical_priority, [not(vip_client), api_error], 0.4).
p(critical_priority, [not(vip_client), not(api_error)], 0.05).

p(dev_needed, [api_error], 0.95).
p(dev_needed, [not(api_error)], 0.01).

p(long_resolution, [critical_priority, dev_needed], 0.8).
p(long_resolution, [critical_priority, not(dev_needed)], 0.6).
p(long_resolution, [not(critical_priority), dev_needed], 0.7).
p(long_resolution, [not(critical_priority), not(dev_needed)], 0.2).

prob([X|Xs],Cond,P):-!,
    prob(X,Cond,Px),
    prob(Xs,[X|Cond],PRest),
    P is Px*PRest.
prob([],_,1):-!.
prob(X,Cond,1):-member(X,Cond),!.
prob(X,Cond,0):-member(not(X),Cond),!.
prob(not(X),Cond,P):-!, prob(X,Cond,P0), P is 1-P0.
prob(X,Cond0,P):-
    delete(Y,Cond0,Cond),
    predecessor(X,Y),!,
    prob(X,Cond,Px),
    prob(Y,[X|Cond],PyGivenX),
    prob(Y,Cond,Py),
    (Py > 0 -> P is Px * PyGivenX / Py ; P = 0).
prob(X,Cond,P):-p(X,P),!.
prob(X,Cond,P):-!,
    findall((Condi,Pi),p(X,Condi,Pi),CPlist),
    sum_probs(CPlist,Cond,P).

sum_probs([],_,0).
sum_probs([(Cond1,P1)|CondsProbs],Cond,P):-
    prob(Cond1,Cond,PC1),
    sum_probs(CondsProbs,Cond,PRest),
    P is P1*PC1+PRest.

predecessor(X,not(Y)):-!, predecessor(X,Y).
predecessor(X, Y):-parent(X,Y).
predecessor(X, Z):-parent(X,Y), predecessor(Y,Z).

member(X,[X|_]).
member(X,[_|L]):-member(X,L).
delete(X,[X|L],L).
delete(X,[Y|L],[Y|L2]):-delete(X,L,L2).
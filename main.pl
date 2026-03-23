% main.pl

:- use_module(library(lists)).
:- consult('tickets_bayes.pl').
:- consult('expert_system.pl').
:- consult('semantic_module.pl').

main :-
    writeln('--- Все модули успешно загружены! ---'),
    writeln('Для начала работы введите: start.'),
    nl.

% Автоматически выводим приветствие при загрузке
:- main.
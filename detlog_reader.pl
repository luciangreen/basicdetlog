:- module(detlog_reader, [
    read_source/2
]).

%% read_source(+File, -Terms)
%
% Read all Prolog terms from File.
% Returns a list of terms (facts, rules, directives).
read_source(File, Terms) :-
    setup_call_cleanup(
        open(File, read, Stream, [encoding(utf8)]),
        read_terms_from_stream(Stream, Terms),
        close(Stream)
    ).

read_terms_from_stream(Stream, Terms) :-
    read_term(Stream, T, [variable_names(_)]),
    (   T == end_of_file
    ->  Terms = []
    ;   Terms = [T|Rest],
        read_terms_from_stream(Stream, Rest)
    ).

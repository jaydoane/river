-module(river).

-define(DOC,"https://gist.github.com/qhool/84801ab7d326e377be0a
A farmer is travelling with his dog, a chicken, and a bag of grain. He comes to a river, which has a small ferry boat. The boat has room for the farmer, and one other item (dog, chicken, or grain). The farmer knows the dog will eat the chicken if left alone with it; likewise, the chicken will eat the grain. How does he get everything to the other side uneaten?
 
The current state of the puzzle can be represented by a string:
* f farmer
* d dog
* c chicken
* g grain
* ~ the river
 
And moves by using an arrow: xy> or <xy
 
fdcg~
fc>
dg~fc
 
Your program should take an initial state, and a sequence of moves, one per line. Compute the final state resulting from applying the moves, or stop whenever something gets eaten.
 
Bonus parts:
* generalize -- use a list of items, and disallowed pairings (e.g. c eats g)
* solve -- generate a winning sequence of moves
").

-compile(export_all). % maybe explicit exports?

-define(RIVER, $~).
-define(DOG, $d).
-define(GRAIN, $g).
-define(FARMER, $f).
-define(CHICKEN, $c).
-define(LEFT, $<).
-define(RIGHT, $>).

-define(GRAIN_EATEN, "Grain was eaten.").
-define(CHICKEN_EATEN, "Chicken was eaten.").
-define(SUCCESS, "Success!").

sample(input,1) ->
    ["fdcg~",
     "fc>",
     "<f",
     "fd>"];
sample(output,1) ->
    "g~fcd";
sample(input,2) ->
    ["fdcg~",
     "fc>",
     "<f",
     "fg>",
     "<f"];
sample(output,2) ->
    {"fd~cg","Grain was eaten."};
sample(input,3) ->
    ["fdcg~",
     "fc>",
     "<f",
     "fd>",
     "<fc",
     "fg>",
     "<f",
     "fc>"];
sample(output,3) ->
    {"~cdfg","Success!"}.


format(L,R) ->
    lists:flatten(L ++ [?RIVER] ++ R).

%% @doc Return the state as a 2-tuple splitting Line on Token
split(Line, Token) ->
    %% because string:tokens/2 doesn't return empty lists
    [L,R] = [binary_to_list(E) ||
                E <- binary:split(list_to_binary(Line), [list_to_binary([Token])])],
    {L,R}.

valid_moves(L,R) ->
    case lists:member(?FARMER, L) of
        true ->
            [string:strip([?RIGHT, ?FARMER, P]) || P <- potential_passengers(L) ++ [$\s]];
        false ->
            [string:strip([?LEFT, ?FARMER, P]) || P <- potential_passengers(R) ++ [$\s]]
    end.

potential_passengers(Shore) ->
    lists:flatten(string:tokens(Shore, [?FARMER])).


solve({L,R}, SearchPath, DeadEnds) ->
    %% case allowed_moves(L,R) of
    {{L,R}, SearchPath, DeadEnds}.


eval([Line|Lines]) ->
    case eval_moves(Lines, split(Line, ?RIVER)) of
        {{L,R}, Reason}  ->
            {format(L,R), Reason};
        {L,R} ->
            format(L,R)
    end.
            
eval_moves([], State) ->
    State;
eval_moves([Line|Lines], State) ->
    case eval_move(Line, State) of
        {invalid_move, Line} ->
            {State, {invalid_move, Line}};
        UpdatedState ->
            case eval_state(UpdatedState) of
                {done, Reason} ->
                    {UpdatedState, Reason};
                ok ->
                    eval_moves(Lines, UpdatedState)
            end
    end.

eval_move(Line, {L,R}) ->
    case lists:member(lists:sort(Line), [lists:sort(M) || M <- valid_moves(L,R)]) of
        true ->
            sort_each(
              case lists:member(?RIGHT, Line) of
                  true ->
                      {L -- Line, R ++ strip_directions(Line)};
                false ->
                      {L ++ strip_directions(Line), R -- Line}
              end);
        false ->
            {invalid_move, Line}
    end.

sort_each({L,R}) ->
    {lists:sort(L), lists:sort(R)}.

strip_directions(Line) ->
    lists:flatten(string:tokens(Line, [?LEFT, ?RIGHT])).
                

eval_state({"", _R}) ->
    {done, ?SUCCESS};
eval_state({L, R}) ->
    case lists:any(fun(S) -> d_eats_c(S) end, [L, R]) of
        true ->
            {done, ?CHICKEN_EATEN};
        false ->
            case lists:any(fun(S) -> c_eats_g(S) end, [L, R]) of
                true ->
                    {done, ?GRAIN_EATEN};
                false ->
                    ok
            end
    end.

c_eats_g(S) ->
    contains(?CHICKEN, S) andalso contains(?GRAIN, S) andalso not contains(?FARMER, S).

d_eats_c(S) ->
    contains(?DOG, S) andalso contains(?CHICKEN, S) andalso not contains(?FARMER, S).

contains(Char, Str) ->
    lists:member(Char, Str).


%%-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

river_test_() ->
    {setup,
     fun() -> ok end,
     fun(_) -> ok end,
     [
      {spawn, ?_test(?debugVal(t_split()))} 
      ,{spawn, ?_test(?debugVal(t_valid_moves()))} 
      ,{spawn, ?_test(?debugVal(t_eval_state()))} 
      ,{spawn, ?_test(?debugVal(t_eval_move()))} 
      ,{spawn, ?_test(?debugVal(t_eval()))} 
     ]}.

t_eval() ->
    ?assertEqual(lists:sort(sample(output,1)), lists:sort(eval(sample(input,1)))),
    {ExpectedState, ExpectedReason} = sample(output,2),
    {State, Reason} = eval(sample(input,2)),
    ?assertEqual(lists:sort(ExpectedState), lists:sort(State)),
    ?assertEqual(ExpectedReason, Reason),
    ?assertEqual(sample(output,3), eval(sample(input,3))).

t_eval_move() ->
    ?assertEqual({"",lists:sort("dgfc")}, eval_move("cf>", {"fc", "dg"})),
    ?assertEqual({invalid_move, "cf<"}, eval_move("cf<", {"fc", "dg"})).

t_eval_state() ->
    ?assertEqual({done, ?SUCCESS}, eval_state({"", "fdcg"})),
    ?assertEqual({done, ?GRAIN_EATEN}, eval_state({"fd", "cg"})),
    ?assertEqual({done, ?CHICKEN_EATEN}, eval_state({"dc", "fg"})).

t_valid_moves() ->
    ?assertEqual([">fc",">fg",">fd",">f"], valid_moves("fcgd", "")),
    ?assertEqual(["<fc","<f"], valid_moves("gd", "fc")),
    ?assertEqual([">f"], valid_moves("f", "cgd")).

t_split() ->
    ?assertEqual({"fdcg",[]}, split("fdcg~", ?RIVER)).

%%-endif.

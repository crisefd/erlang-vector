-module(vector).
-export([empty/0, size/1, random/2, sequence/1, fill/2, concat/2,
         add/2, insert/3, delete/2, addAll/2, set/3, nth/2]).

%-define(BITS, 1).
%-define(BIT_MASK, 16#01).
%-define(NODE_SIZE, 2).

%-define(BITS, 2).
%-define(BIT_MASK, 16#03).
%-define(NODE_SIZE, 4).

-define(BITS, 5).
-define(BIT_MASK, 16#1F).
-define(NODE_SIZE, 32).

empty() ->
   {vector, 0, ?BITS, {}, {}}.


random(N, MaxRand) ->
   fill(N, fun(_Idx) -> random:uniform(MaxRand) end).

sequence(N) ->
   fill(N, fun(Idx) -> Idx end).

fill(N, Fn) when is_function(Fn) ->
   fill(N, empty(), Fn);
fill(N, Term) ->
   fill(N, fun(_) -> Term end).

fill(N, Vector, Fn) ->
   fill(N, Vector, Fn, 0).

fill(N, Vector, _, N) ->
   Vector;
fill(N, Vector, Fn, Idx) ->
   fill(N, add(Vector, Fn(Idx)), Fn, Idx+1).


%% Naive implementation to be improved...
addAll(Vector, []) ->
   Vector;
addAll(Vector, [Value|Tail]) ->
   addAll(add(Vector, Value), Tail).

concat(Vector1, Vector2) ->
   concat(Vector1, Vector2, 0).

concat(Vector1, {vector, Size, _, _, _}, Size) ->
   Vector1;
concat(Vector1, Vector2, N) ->
   concat(add(Vector1, nth(N, Vector2)), Vector2, N+1). 

insert(Size, Vector={vector, Size, _, _, _}, Value) ->
   add(Vector, Value);
insert(N, Vector, Value) ->
   insert(N+1, set(N, Vector, Value), nth(N, Vector)).

delete(N, Vector) ->
   delete(N, Vector, 0).

delete(_, Vector={vector, Size, _, _, _}, Idx) when Idx >= Size ->
   Vector; 
delete(N, Vector, Idx) when Idx =:=  N ->
   delete(N, Vector, Idx+1);
delete(N, Vector, Idx) when Idx < N ->
   delete(N, add(Vector, nth(Idx, Vector)), Idx+1).
%% ...Naive implementation to be improved



add({vector, Size, Shift, Root, Tail}, Value) when erlang:size(Tail)<?NODE_SIZE ->
   {vector, Size+1, Shift, Root, erlang:append_element(Tail, Value)};
add({vector, Size, Shift, Root, Tail}, Value) when erlang:size(Tail)=:=?NODE_SIZE ->
   {NewShift, NewRoot} = push_tail_root(Size, Shift, Root, Tail),
   {vector, Size+1, NewShift, NewRoot, {Value}}.

push_tail_root(Size, Shift, Root, Tail) when (Size bsr ?BITS) > (1 bsl Shift) ->
   {Shift+?BITS, {Root, new_path(Shift, Tail)}};
push_tail_root(Size, Shift, Root, Tail) ->
   {Shift, push_tail(Size, Shift, Root, Tail)}.

push_tail(Size, Shift, Parent, Tail) ->
   SubIdx = ((Size-1) bsr Shift) band ?BIT_MASK,
   if 
      (Shift =:= ?BITS) ->
         erlang:append_element(Parent, Tail);
      (SubIdx =:= erlang:size(Parent)) ->
         erlang:append_element(Parent, new_path(Shift-?BITS, Tail));
      (SubIdx < erlang:size(Parent)) ->
         setnode(SubIdx, Parent, 
             push_tail(Size, Shift-?BITS, getnode(SubIdx, Parent), Tail))
   end.

new_path(0, Node) -> 
   Node;
new_path(Shift, Node) -> 
   {new_path(Shift-?BITS, Node)}.


set(N, {vector, Size, Shift, Root, Tail}, Value) when N >=0, N < Size ->
   if
      (N >= ((Size-1 bsr ?BITS) bsl ?BITS) ) ->
         {vector, Size, Shift, Root, setnode((N band ?BIT_MASK), Tail, Value)};
      true ->
         {vector, Size, Shift, setnode(N, Shift, Root, Value), Tail}
   end;
set(_, _, _) ->
   error(badarg).
  
setnode(N, 0, Node, Value) ->
  SubIdx = N band ?BIT_MASK,
  setnode( SubIdx, Node, Value); 
setnode(N, Shift, Parent, Value) ->
  SubIdx = (N bsr Shift) band ?BIT_MASK,
  setnode( SubIdx, Parent, setnode(N, Shift-?BITS, getnode(SubIdx, Parent), Value)). 

setnode(N, Parent, Child) ->
  erlang:setelement(N+1, Parent, Child).

getnode(N, Parent) ->
  erlang:element(N+1, Parent).


size({vector, Size, _, _, _}) -> Size.

nth(N, Vector={vector, Size, _, _, _}) when N >= 0, N < Size ->
  getnode((N band ?BIT_MASK), node_for(N, Vector));
nth(_, _) ->
   error(badarg).

node_for(N, {vector, Size, _, _, Tail}) when N >= ((Size-1 bsr ?BITS) bsl ?BITS) ->
   Tail;
node_for(N, {vector, _, Shift, Root, _}) ->
   node_for(N, Shift, Root).

node_for(_, 0, Node) ->
   Node;
node_for(N, Shift, Node) ->
  SubIdx = (N bsr Shift) band ?BIT_MASK,
  node_for(N, Shift-?BITS,  getnode(SubIdx, Node)).
 


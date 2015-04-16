-module(http2_frame_headers).

-include("http2.hrl").

-behaviour(http2_frame).

-export([read_binary/2,send/3]).

-spec read_binary(binary(), frame_header()) ->
    {ok, payload(), binary()} | {error, term()}.
read_binary(Bin, H = #frame_header{length=L}) ->
    <<PayloadBin:L/binary,Rem/bits>> = Bin,
    Data = http2_padding:read_possibly_padded_payload(PayloadBin, H),
    {Priority, HeaderFragment} = case is_priority(H) of
        true ->
            http2_frame_priority:read_priority(Data);
        false ->
            {undefined, Data}
    end,

    Payload = #headers{
                 priority=Priority,
                 block_fragment=HeaderFragment
                },

    lager:debug("HEADERS payload: ~p", [Payload]),
    {ok, Payload, Rem}.

is_priority(#frame_header{flags=F}) when ?IS_FLAG(F, ?FLAG_PRIORITY) ->
    true;
is_priority(_) ->
    false.

%% TODO: Pretty hardcoded and gross
send({Transport, Socket}, StreamId, Data) ->
    L = byte_size(Data),
    Transport:send(Socket, [<<L:24,?HEADERS:8,?FLAG_END_HEADERS:8,0:1,StreamId:31>>,Data]).
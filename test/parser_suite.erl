-module(parser_suite).
-include_lib("eunit/include/eunit.hrl").
-include("../headers/settings.hrl").
-include("../headers/asserts.hrl").

% json_to_map__1_test() ->
%   ok.

% map_to_json__1_test() ->
%   ?match("{\"a\":2,\"b\":3}",parser:map_to_json(#{a=>2,b=>3})).

float_to_bin_should_parse_single_float__test() ->
  <<63,192,0,0>> = parser:float_to_bin(1.5).

float_to_bin_should_parse_single_integer__test() ->
  <<63,128,0,0>> = parser:float_to_bin(1).

float_to_bin_should_parse_list_of_numbers__test() ->
  <<63,192,0,0,63,128,0,0>> = parser:float_to_bin([1.5,1]).
-module(uaa_jwt).

-export([add_signing_key/3,
         decode_and_verify/1,
         get_jwk/1,
         verify_signing_key/2,
         signing_keys/0]).

-include_lib("jose/include/jose_jwk.hrl").


-type key_type() :: json | pem | map.

-spec add_signing_key(binary(), key_type(), binary() | map()) -> {ok, map()} | {error, term()}.

add_signing_key(KeyId, Type, Value) ->
    case verify_signing_key(Type, Value) of
        ok ->
            NewSigningKeys = maps:put(KeyId, {Type, Value}, signing_keys()),
            {ok, application:set_env(uaa_jwt, signing_keys, NewSigningKeys)};
        {error, _} = Err ->
            Err
    end.


-spec decode_and_verify(binary()) -> {boolean(), map()} | {error, term()}.
decode_and_verify(Token) ->
    case uaa_jwt_jwt:get_key_id(Token) of
        {ok, KeyId} ->
            case get_jwk(KeyId) of
                {ok, JWK} ->
                    uaa_jwt_jwt:decode_and_verify(JWK, Token);
                {error, _} = Err ->
                    Err
            end;
        {error, _} = Err ->
            Err
    end.


-spec get_jwk(binary()) -> {ok, map()} | {error, term()}.
get_jwk(KeyId) ->
    Keys = signing_keys(),
    case maps:get(KeyId, Keys, undefined) of
        undefined ->
            {error, key_not_found};
        {Type, Value} ->
            case Type of
                json     -> uaa_jwt_jwk:make_jwk(Value);
                pem      -> uaa_jwt_jwk:from_pem(Value);
                pem_file -> uaa_jwt_jwk:from_pem_file(Value);
                map      -> uaa_jwt_jwk:make_jwk(Value);
                _        -> {error, unknown_signing_key_type}
            end
    end.

verify_signing_key(Type, Value) ->
    Verified = case Type of
        json     -> uaa_jwt_jwk:make_jwk(Value);
        pem      -> uaa_jwt_jwk:from_pem(Value);
        pem_file -> uaa_jwt_jwk:from_pem_file(Value);
        map      -> uaa_jwt_jwk:make_jwk(Value);
        _         -> {error, unknown_signing_key_type}
    end,
    case Verified of
        {ok, Key} ->
            case jose_jwk:from(Key) of
                #jose_jwk{}     -> ok;
                {error, Reason} -> {error, Reason}
            end;
        Err -> Err
    end.

signing_keys() ->
    application:get_env(uaa_jwt, signing_keys, #{}).
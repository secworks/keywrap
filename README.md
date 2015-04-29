# keywrap #

RFC 3394 keywrap cipher mode implemented in Verilog 2001.

## Introduction ##

Shared secrets such as Cryptographic keys needs to be protected when
transported or stored. Key wrapping mechanisms are used to to create
such a protection by wrapping the keys with the aid of a master secret.

There are a few algorithms for implementing key wrapping. The Advanced
Encryption Standard (AES) Key Wrap Algorithm (keywrap) specified in RFC
3394 ( https://tools.ietf.org/html/rfc3394 )is one such method.


## Implementation details ##

The implementation does not contain its own internal storage of
unwrapped keys, but expect to be fed data to be wrapped or unwrapped.


## Implementation results ##

Nothing here yet.


## Status ##

### (2015-04-29) ###

Core development started.

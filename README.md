<!--
SPDX-FileCopyrightText: 2019 Alex Beregszaszi
SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>

SPDX-License-Identifier: Apache-2.0
-->

# BLAKE2 _(blake2-solidity)_

This is a Solidity library aiming to implement BLAKE2.

Ethereum only offers a precompiled contract that provides the “F” compression
function, which is the central component of BLAKE2. Implementing BLAKE2 on top
of it is relatively easy, but not completely straightforward, hence this library.

Currently only BLAKE2b is implemented.

Supported features:

- [x] Input data length between 0 and 2^24 - 1
- [x] Digest length between 1 and 64
- [ ] Salt
- [ ] Personalisation
- [ ] Keyed MAC
- [ ] Tree hashing


## Usage

The library provides a single method: `hash(out_len, data)`.
Output length will typically be 64, as it is the most popular choice in
the wild, but can be anything between 1 and 64.

### Development

1. Install [Truffle](https://www.trufflesuite.com/docs/truffle/getting-started/installation).
2. Install `go-ethereum` (version >= 1.9.3).
3. Start dev node: `geth --dev --rpc`.
4. Run `truffle test`.


## API

* `Blake2b.hash(uint out_len, bytes data) -> bytes(out_len)`


## References

- Official specification: https://blake2.net/blake2.pdf
- RFC7693 (contains a shorter, but less comprehensive description): https://tools.ietf.org/html/rfc7693
- Test vectors: https://github.com/BLAKE2/BLAKE2/tree/master/testvectors
- EIP-152 (Ethereum specific application): https://eips.ethereum.org/EIPS/eip-152

[EIP-152]: https://eips.ethereum.org/EIPS/eip-152


## License

[Apache 2.0] © [@axic] & [Serokell]

[Apache 2.0]: https://spdx.org/licenses/Apache-2.0.html
[@axic]: https://github.com/axic
[Serokell]: https://serokell.io/

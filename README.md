<!--
SPDX-FileCopyrightText: 2019 Alex Beregszaszi
SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>

SPDX-License-Identifier: Apache-2.0
-->

# blake2-solidity

This is a Solidity library aiming to implement BLAKE2.

Currently it tries to only support BLAKE2B using the [EIP-152] precompile.

## Usage

### Development

1. Install [Truffle](https://www.trufflesuite.com/docs/truffle/getting-started/installation).
2. Install `go-ethereum` (version >= 1.9.3).
3. Start dev node: `geth --dev --rpc`.
4. Run `truffle test`.

## References

- Official specification: https://blake2.net/blake2.pdf
- RFC7693 (contains a shorter, but less comprehensive description): https://tools.ietf.org/html/rfc7693
- Test vectors: https://github.com/BLAKE2/BLAKE2/tree/master/testvectors
- EIP-152 (Ethereum specific application): https://eips.ethereum.org/EIPS/eip-152

## Maintainer(s)

- Alex Beregszaszi [@axic]

## License

Apache-2.0

[EIP-152]: https://eips.ethereum.org/EIPS/eip-152
[@axic]: https://github.com/axic

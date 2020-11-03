// SPDX-FileCopyrightText: 2019 Alex Beregszaszi
// SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
//
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

library Blake2b {
    uint256 constant public BLOCK_SIZE = 128;
    uint256 constant public WORD_SIZE = 32;
    // And we rely on the fact that BLOCK_SIZE % WORD_SIZE == 0

    // Initialise the state with a given `key` and required `out_len` hash length.
    // This is a bit misleadingly called state as it not only includes the Blake2 state,
    // but every field needed for the "blake2 f function precompile".
    //
    // This is a tightly packed buffer of:
    // - rounds: 32-bit BE
    // - h: 8 x 64-bit LE
    // - m: 16 x 64-bit LE
    // - t: 2 x 64-bit LE
    // - f: 8-bit
    function init(uint out_len)
        private
        pure
        returns (bytes memory state)
    {
        // This is entire state transmitted to the precompile.
        // It is byteswapped for the encoding requirements, additionally
        // the IV has the initial parameter block 0 XOR constant applied, but
        // not the key and output length.
        state = hex"0000000c08c9bdf267e6096a3ba7ca8485ae67bb2bf894fe72f36e3cf1361d5f3af54fa5d182e6ad7f520e511f6c3e2b8c68059b6bbd41fbabd9831f79217e1319cde05b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        // Update parameter block 0 with key length and output length.
        uint key_len = 0;
        assembly {
            let ptr := add(state, 36)
            let tmp := mload(ptr)
            let p0 := or(shl(240, key_len), shl(248, out_len))
            tmp := xor(tmp, p0)
            mstore(ptr, tmp)
        }

        // TODO: support salt and personalization
    }

    // This calls the blake2 precompile ("function F of the spec").
    // It expects the state was updated with the next block. Upon returning the state will be updated,
    // but the supplied block data will not be cleared.
    function call_function_f(bytes memory state)
        private
        view
    {
        assembly {
            let state_ptr := add(state, 32)
            if iszero(staticcall(not(0), 0x09, state_ptr, 0xd5, add(state_ptr, 4), 0x40)) {
                revert(0, 0)
            }
        }
    }

    function update_finalise(bytes memory state, bytes memory data)
        private
        view
    {
        // NOTE [input size]
        // Technically, this can be 128 bits, but we need to manually convert
        // it from big-endian to little-endian, which is boring, so, hopefully,
        // 24 bits should be more than enough.
        uint input_counter = 0;
        require(data.length <= (1 << 24) - 1);

        // This is the memory location where the input data resides.
        uint inp_ptr;
        assembly {
            inp_ptr := add(data, 32)
        }

        // This is the memory location where the "data block" starts for the precompile.
        uint msg_ptr;
        assembly {
            // The `rounds` field is 4 bytes long and the `h` field is 64-bytes long.
            // Also the length stored in the bytes data type is 32 bytes.
            msg_ptr := add(state, 100)
        }

        uint remains = data.length;
        do {
            uint out_ptr = msg_ptr;

            // Copy full words first.
            while (remains >= WORD_SIZE && out_ptr < msg_ptr + BLOCK_SIZE) {
                assembly {
                    mstore(out_ptr, mload(inp_ptr))
                }
                inp_ptr += WORD_SIZE;
                out_ptr += WORD_SIZE;
                remains -= WORD_SIZE;
            }
            input_counter += out_ptr - msg_ptr;

            // Now copy the remaining <32 bytes.
            if (remains > 0 && out_ptr < msg_ptr + BLOCK_SIZE) {
                uint mask = (1 << (8 * (WORD_SIZE - remains))) - 1;
                assembly {
                    mstore(out_ptr, and(mload(inp_ptr), not(mask)))
                }
                // inp_ptr += remains;  // No need to udpate as we are done here
                out_ptr += WORD_SIZE;
                input_counter += remains;
                remains = 0;
            }

            // If this block is the last one.
            if (remains == 0) {
                // Pad.
                while (out_ptr < msg_ptr + BLOCK_SIZE) {
                    assembly {
                        mstore(out_ptr, 0)
                    }
                    out_ptr += WORD_SIZE;
                }

                // Set the last block indicator.
                assembly {
                    mstore8(add(state, 244), 1)
                }
            }

            // Set length field (little-endian) for maximum of 24-bits.
            assembly {
                mstore8(add(state, 228), and(input_counter, 0xff))
                mstore8(add(state, 229), and(shr(8, input_counter), 0xff))
                mstore8(add(state, 230), and(shr(16, input_counter), 0xff))
            }

            // Call the precompile
            call_function_f(state);
        } while (remains > 0);
    }

    // Compute a hash of bytes.
    function hash(uint out_len, bytes memory data)
        public
        view
        returns (bytes memory output)
    {
        require(out_len > 0 && out_len <= 64);
        bytes memory state = init(out_len);

        update_finalise(state, data);

        output = new bytes(out_len);

        // We’ll just treat cases indivifually, because we can.
        if (out_len < 32) {
            uint mask = (1 << (8 * (WORD_SIZE - out_len))) - 1;
            assembly {
                let out_ptr := add(output, 32)
                let out_word := and(mload(add(state, /*32 + 4 =*/ 36)), not(mask))
                let orig_word := and(mload(out_ptr), mask)
                mstore(out_ptr, or(out_word, orig_word))
            }
        } else {
            // Copy first word.
            assembly {
                mstore(add(output, 32), mload(add(state, /*32 + 4 =*/ 36)))
            }
            if (out_len < 64) {
                uint mask = (1 << (8 * (2 * WORD_SIZE - out_len))) - 1;
                assembly {
                    let out_ptr := add(output, /*32 + 32 =*/ 64)
                    let out_word := and(mload(add(state, /*32 + 4 + 32 =*/ 68)), not(mask))
                    let orig_word := and(mload(out_ptr), mask)
                    mstore(out_ptr, or(out_word, orig_word))
                }
            } else {
                assembly {
                    mstore(add(output, /*32 + 32 =*/ 64), mload(add(state, /*32 + 4 + 32 =*/ 68)))
                }
            }
        }
    }
}

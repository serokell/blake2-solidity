// SPDX-FileCopyrightText: 2019 Alex Beregszaszi
// SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
//
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

library Blake2b {
    uint256 constant public BLOCK_SIZE = 128;

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
        require(data.length <= (2 << 24) - 1);

        // This is the memory location where the "data block" starts for the precompile.
        uint state_ptr;
        assembly {
            // The `rounds` field is 4 bytes long and the `h` field is 64-bytes long.
            // Also the length stored in the bytes data type is 32 bytes.
            state_ptr := add(state, 100)
        }

        // This is the memory location where the input data resides.
        uint data_ptr;
        assembly {
            data_ptr := add(data, 32)
        }

        uint len = data.length;
        do {
            if (len < BLOCK_SIZE) {
                // Need to pad data with zeroes.
                // How many whole 32-byte chunks the data occupies?
                uint chunks = len / BLOCK_SIZE;

                // Pad the rest
                // A 128-byte block consist of 4 32-byte chunks.
                for (uint i = chunks; i < 4; ++i) {
                    uint offset = 32 * i;
                    assembly {
                        mstore(add(state_ptr, offset), 0)
                    }
                }
            }

            // Now copy over whole 32-byte blocks (but no more than 4 of them)
            uint offset = 0;
            for (offset; offset < BLOCK_SIZE && len >= 32; offset += 32) {
                assembly {
                    mstore(add(state_ptr, offset), mload(data_ptr))
                    data_ptr := add(data_ptr, 32)
                }
                len -= 32;
            }

            // Now copy over the reamining individual bytes
            uint available = BLOCK_SIZE - offset;
            uint remaining = available <= len ? available : len;  // remaining < 32
            // [begin] FIXME: I am stupid and I have no idea how else to do this
            bytes memory tmp = new bytes(32);  // I hope it is zero-initialised...
            uint data_off;
            assembly {
                data_off := sub(data_ptr, data)
                data_off := sub(data_off, 32)
            }
            for (uint i = 0; i < remaining; ++i) {
                tmp[i] = data[data_off + i];
            }
            assembly {
                mstore(add(state_ptr, offset), mload(add(tmp, 32)))
                data_ptr := add(data_ptr, remaining)
            }
            // [end] FIXME

            input_counter += offset + remaining;
            len -= remaining;

            // Set length field (little-endian) for maximum of 24-bits.
            assembly {
                mstore8(add(state, 228), and(input_counter, 0xff))
                mstore8(add(state, 229), and(shr(8, input_counter), 0xff))
                mstore8(add(state, 230), and(shr(16, input_counter), 0xff))
            }

            // Set the last block indicator.
            // Only if we've processed all input.
            if (len == 0) {
                assembly {
                    // Writing byte 212 here.
                    mstore8(add(state, 244), 1)
                }
            }

            // Call the precompile
            call_function_f(state);
        } while (len > 0);
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

        bytes memory whole_output = new bytes(out_len > 32 ? 64 : 32);
        assembly {
            mstore(add(whole_output, 32), mload(add(state, 36)))
        }
        if (out_len > 32) {
            assembly {
                mstore(add(whole_output, 64), mload(add(state, 68)))
            }
        }
        if (out_len == 32 || out_len == 64) {
            output = whole_output;
        } else {
            output = new bytes(out_len);
            for (uint i = 0; i < out_len; ++i) {
                output[i] = whole_output[i];
            }
        }
    }
}

package db

import "base:intrinsics"

@(private = "file")
Fuzzy_Search_Proc :: proc(text: string, query: string, mask: [256]u64) -> bool

fuzzy_search: Fuzzy_Search_Proc

@(init)
init_fuzzy_search :: proc "contextless" () {
	when ODIN_ARCH == .amd64 {
		if .avx2 in info.cpu_features() {
			fuzzy_search = bitap_search_avx2
		} else {
			fuzzy_search = bitap_search_scalar
		}
	} else when ODIN_ARCH == .arm64 && ODIN_OS == .Darwin {
		fuzzy_search = bitap_search_asimd
	} else {
		fuzzy_search = bitap_search_scalar
	}
}

prepare_mask :: proc(query: string) -> [256]u64 {
	mask: [256]u64
	for i in 0 ..< len(query) {
		mask[query[i]] |= (1 << u64(i))
	}
	return mask
}

u8x16 :: #simd[16]u8

@(private = "file")
@(enable_target_feature = "neon")
bitap_search_asimd :: proc(text: string, query: string, mask: [256]u64) -> bool {
	if query == "" do return true

	n := len(text)
	if n == 0 do return false

	// NEON prefilter: reject text missing any required query byte.
	// Scans 16 bytes per NEON instruction.
	seen: [256]bool
	raw_text := raw_data(text)

	for qi in 0 ..< len(query) {
		qb := query[qi]
		if seen[qb] do continue
		seen[qb] = true

		needle := u8x16{qb, qb, qb, qb, qb, qb, qb, qb, qb, qb, qb, qb, qb, qb, qb, qb}
		found := false

		i := 0
		for ; i + 16 <= n; i += 16 {
			chunk := intrinsics.unaligned_load(cast(^u8x16)(cast(uintptr)raw_text + uintptr(i)))
			eq := intrinsics.simd_lanes_eq(chunk, needle)
			if intrinsics.simd_reduce_or(eq) != 0 {
				found = true
				break
			}
		}

		if !found {
			for ; i < n; i += 1 {
				if (cast([^]u8)raw_text)[i] == qb {
					found = true
					break
				}
			}
		}

		if !found do return false
	}

	// Scalar bitap core (state has sequential dependency)
	state: u64
	match_bit := u64(1) << u64(len(query) - 1)

	for i in 0 ..< len(text) {
		c := text[i]
		state = state | (((state << 1) | 1) & mask[c])

		if state & match_bit != 0 {
			return true
		}
	}

	return false
}

@(private = "file")
@(enable_target_feature = "avx2")
bitap_search_avx2 :: proc(text: string, query: string, mask: [256]u64) -> bool {
	if query == "" do return true

	state: u64
	match_bit := u64(1) << u64(len(query) - 1)

	for i in 0 ..< len(text) {
		c := text[i]
		state = state | (((state << 1) | 1) & mask[c])

		if state & match_bit != 0 {
			return true
		}
	}

	return false
}

@(private = "file")
bitap_search_scalar :: proc(text: string, query: string, mask: [256]u64) -> bool {
	if query == "" do return true

	state: u64
	match_bit := u64(1) << u64(len(query) - 1)

	for i in 0 ..< len(text) {
		c := text[i]
		state = state | (((state << 1) | 1) & mask[c])

		if state & match_bit != 0 {
			return true
		}
	}

	return false
}


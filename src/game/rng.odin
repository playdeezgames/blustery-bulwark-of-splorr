package game

// A small deterministic generator (splitmix64), so a floor made from a seed is the same on wasm and
// native and the same every time it is regenerated. Never all-zero trouble: splitmix has no bad state.

Rng :: struct {
	state: u64,
}

rng_next :: proc(r: ^Rng) -> u64 {
	r.state += 0x9E3779B97F4A7C15
	z := r.state
	z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ~ (z >> 27)) * 0x94D049BB133111EB
	return z ~ (z >> 31)
}

// A whole number in [0, n); n must be positive and fit in an int on wasm (32 bits).
rng_int :: proc(r: ^Rng, n: int) -> int {
	assert(n > 0)
	return int(rng_next(r) % u64(n))
}

// A whole number in [lo, hi].
rng_range :: proc(r: ^Rng, lo, hi: int) -> int {
	return lo + rng_int(r, hi - lo + 1)
}

// The seed of one floor of one character: the character's seed mixed with the floor number.
floor_seed :: proc(seed: u64, floor: int) -> u64 {
	r := Rng{seed ~ (u64(floor) * 0xD1B54A32D192ED03)}
	return rng_next(&r)
}

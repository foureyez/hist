package db

import "core:log"
import "core:testing"
import "core:time"

BENCH_ITERS :: 100_000

@(test)
test_fuzzy_search_match :: proc(t: ^testing.T) {
	query := "test"
	text := "testing"
	mask := prepare_mask(query)
	testing.expect(t, fuzzy_search(text, query, mask))
}

@(test)
bench_fuzzy_search_short :: proc(t: ^testing.T) {
	query := "git"
	text := "git commit -m 'fix bug'"
	mask := prepare_mask(query)

	start := time.now()
	for _ in 0 ..< BENCH_ITERS {
		_ = fuzzy_search(text, query, mask)
	}
	elapsed := time.diff(start, time.now())
	ns_per_op := time.duration_nanoseconds(elapsed) / BENCH_ITERS
	log.infof("short: %d ns/op (%d iters)", ns_per_op, BENCH_ITERS)
}

@(test)
bench_fuzzy_search_long :: proc(t: ^testing.T) {
	query := "docker"
	text := "docker compose -f docker-compose.prod.yml up --build --force-recreate -d && docker logs -f app"
	mask := prepare_mask(query)

	start := time.now()
	for _ in 0 ..< BENCH_ITERS {
		_ = fuzzy_search(text, query, mask)
	}
	elapsed := time.diff(start, time.now())
	ns_per_op := time.duration_nanoseconds(elapsed) / BENCH_ITERS
	log.infof("long: %d ns/op (%d iters)", ns_per_op, BENCH_ITERS)
}

@(test)
bench_fuzzy_search_nomatch :: proc(t: ^testing.T) {
	query := "zzzzz"
	text := "git push origin main --force-with-lease"
	mask := prepare_mask(query)

	start := time.now()
	for _ in 0 ..< BENCH_ITERS {
		_ = fuzzy_search(text, query, mask)
	}
	elapsed := time.diff(start, time.now())
	ns_per_op := time.duration_nanoseconds(elapsed) / BENCH_ITERS
	log.infof("nomatch: %d ns/op (%d iters)", ns_per_op, BENCH_ITERS)
}


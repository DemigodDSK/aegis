# Aegis test vectors

Provenance and integrity record for the Known-Answer Test (KAT)
files used by the Aegis test suite.

Every file in this directory is committed verbatim (no
post-processing) and pinned to a specific upstream commit. The
SHA-256 below was computed with macOS `shasum -a 256` on the
file as it sits on disk.

If you update a vector file, also update its row here. CI does
not currently re-verify these checksums automatically — issue
TBD will add a CI job that does.

## ML-KEM-768 — NIST FIPS 203

NIST CAVP / ACVP-derived test vectors for ML-KEM-768, fetched from
the BoringSSL test corpus where they are mirrored verbatim from the
NIST ACVP server (`Algorithm: ML-KEM`, `revision: FIPS203`).

| File | Source | Pinned commit | SHA-256 |
|---|---|---|---|
| `mlkem768_nist_keygen_tests.txt` | `google/boringssl @ crypto/mlkem/mlkem768_nist_keygen_tests.txt` | [`500fa1f9`](https://github.com/google/boringssl/blob/500fa1f9d274d06ddfc112e1815ad5dc5ce92234/crypto/mlkem/mlkem768_nist_keygen_tests.txt) | `4bcc6fb5248cbade57e223d19f290f70f2eee8fa9bfb399dbee33fe3692cce36` |
| `mlkem768_nist_decap_tests.txt` | `google/boringssl @ crypto/mlkem/mlkem768_nist_decap_tests.txt` | [`500fa1f9`](https://github.com/google/boringssl/blob/500fa1f9d274d06ddfc112e1815ad5dc5ce92234/crypto/mlkem/mlkem768_nist_decap_tests.txt) | `3ac2e70dead0093a0b1c1c7d551452187e43dbc3f0d3aeaa7a75175abbff2ce7` |

The decap tests file is shipped in this repo for completeness and
auditability; Apple's CryptoKit `MLKEM768.PrivateKey` does not
accept a raw FIPS 203 `dk` byte representation as input (its
`integrityCheckedRepresentation` form is seed + HMAC, not the
expanded key), so the decap vectors are not currently consumed by
a Swift test. Sprint 4 forward-secrecy work may revisit decap-KAT
coverage if we add an alternate key import path.

## X-Wing — IETF draft-connolly-cfrg-xwing-kem

| File | Source | Pinned commit | SHA-256 |
|---|---|---|---|
| `xwing-test-vectors.json` | `dconnolly/draft-connolly-cfrg-xwing-kem @ spec/test-vectors.json` | [`5cb311dc`](https://github.com/dconnolly/draft-connolly-cfrg-xwing-kem/blob/5cb311dc7c7761c2b82d2f4a0037da2c2c7af8f3/spec/test-vectors.json) | `409efe197550b22985b4a0419418a0c5f2c2b193426c55bd998399ec8d3e614d` |

Each entry contains `seed`, `eseed`, `ss`, `sk`, `pk`, `ct`. The
Aegis test suite consumes `seed` (32 bytes) for KeyGen and
`(seed, ct, ss)` for Decap. We do not test Encap directly because
Apple's `XWingMLKEM768X25519.PublicKey.encapsulate()` does not
accept caller-supplied randomness — the `eseed` field in the JSON
is unused.

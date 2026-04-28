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

## ML-DSA-65 — NIST FIPS 204

| File | Source | Pinned commit | SHA-256 |
|---|---|---|---|
| `mldsa_nist_keygen_65_tests.txt` | `google/boringssl @ crypto/mldsa/mldsa_nist_keygen_65_tests.txt` | [`48d150f5`](https://github.com/google/boringssl/blob/48d150f5940a3fd1a41cd0ce067887efa97fb2be/crypto/mldsa/mldsa_nist_keygen_65_tests.txt) | `2a88427a6e7e225626c38e4e520fed372a41fd067c680cbce9ac20bc8ae0b4e9` |
| `mldsa_65_wycheproof_verify_test.json` | `google/boringssl @ third_party/wycheproof_testvectors/mldsa_65_verify_test.json` | [`72cb1bdc`](https://github.com/google/boringssl/blob/72cb1bdce029ce3df0710607975d4a26dd62058c/third_party/wycheproof_testvectors/mldsa_65_verify_test.json) | `45372a71c3d19eaba50d65859d66a36257ebbb7cfb156229930848f99f6b3c78` |

KeyGen file is the BoringSSL mirror of NIST ACVP `ML-DSA-keyGen-FIPS204`
vectors — 25 entries. Each is `(seed, pub, priv)`; we verify
that the seed → pub derivation in CryptoKit matches NIST.

Wycheproof verify file is Project Wycheproof's targeted-edge-case
suite for ML-DSA-65 signature verification — 24 groups × ~7
tests each = 160 total verifications. Each group ships a single
`publicKey` (raw FIPS 204 format) plus a list of `(msg, sig,
result)` triples where `result ∈ {valid, invalid, acceptable}`.
We confirm `MLDSA65Signature.isValidSignature` returns `true` on
`valid` cases and either returns `false` or throws on `invalid`
cases. `acceptable` cases pass either way (Wycheproof's
"implementation-defined" outcomes).

We deliberately do NOT ship `mldsa_nist_siggen_65_tests.txt`:
NIST's SigGen vectors give `(sk, msg, signature)` triples in
the raw 4032-byte FIPS 204 sk format, which Apple's CryptoKit
API does not accept as input. Wycheproof's verify suite
provides equivalent coverage in a usable shape.

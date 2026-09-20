# Implementation-record guidance

- `STATUS.md` is the concise plan index; `handoffs/NN.md` is the durable execution report; `decisions.md` and `research.md` hold ongoing D/R records.
- Record exact commands, selected developer directory, destination IDs, result, and durable evidence location. A compile-only result is not a test pass.
- Separate code status, automated verification, and human acceptance. Use `NOT RUN` for unavailable hardware, simulator, reviewer, or observation; include reproducible setup/actions/expected evidence.
- Decision entries retain D IDs, source decision, implementation choice, reason, evidence, and open questions. Research entries retain R IDs, owner role, evidence needed, status, blockers, and evidence links.
- Keep R01–R07 `OPEN` until their stated physical, measured, or reviewer evidence exists. Synthetic tests alone do not close device gates.
- Do not store participant images, face crops, landmarks, identifying face data, secrets, DerivedData, or result bundles in the repository.

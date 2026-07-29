## Ground Truth

- **Fixtures / dataset**: <!-- ... -->
- **How constructed**: <!-- ... -->
- **Why the expected outcome is known independently**: <!-- ... -->
- **Reproduce with**: `<!-- one command from a clean checkout -->`

## Fixture Construction

Each integration-failure fixture MUST assert all five:

| Fixture | Base passes | A alone | B alone | Merge clean | A+B fails | Deterministic |
| --- | --- | --- | --- | --- | --- | --- |
| <!-- ... --> | <!-- ✓ --> | <!-- ✓ --> | <!-- ✓ --> | <!-- ✓ --> | <!-- ✓ --> | <!-- ✓ --> |

## Metrics

| Metric | Definition | Computation |
| --- | --- | --- |
| Actionable precision | <!-- ... --> | <!-- ... --> |
| Recall on known fixtures | <!-- ... --> | <!-- ... --> |
| False warnings per agent session | <!-- ... --> | <!-- ... --> |
| Median lead time vs existing pipeline | <!-- ... --> | <!-- ... --> |
| Compute overhead | <!-- ... --> | <!-- ... --> |

## Thresholds

| Metric | Bar | Rationale |
| --- | --- | --- |
| <!-- ... --> | <!-- ... --> | <!-- ... --> |

## Overhead Budget

- **Wall clock**: <!-- ... -->
- **CPU**: <!-- ... -->
- **Memory**: <!-- ... -->
- **Cache hit rate**: <!-- ... -->

## Anti-Metrics

- <!-- e.g. stars, downloads, sign-ups — not evidence of correctness -->

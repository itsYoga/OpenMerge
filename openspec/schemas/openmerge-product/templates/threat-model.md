## Assets

- <!-- what an attacker wants -->

## Trust Assumptions

| Input | Trusted? | Rationale |
| --- | --- | --- |
| Repository contents | no | <!-- ... --> |
| Branch-supplied config / hooks | no | <!-- ... --> |
| Agent-generated code | no | <!-- ... --> |

## Threat Inventory

### T-<!-- n -->: <!-- title -->
- **Attacker capability**: <!-- ... -->
- **Attack path**: <!-- ... -->
- **Impact**: <!-- ... -->
- **Mitigation**: <!-- ... -->
- **Proven by**: <!-- the test or check name -->

<!-- Required coverage: shell injection via paths and branch names; secret
leakage into logs and evidence; malicious branch-supplied hooks or config;
dependency install and build scripts; resource exhaustion (CPU, memory, disk,
fds, fork); sandbox escape; network exfiltration; symlink and path traversal
during snapshot materialisation; poisoned cache entries. -->

## Sandbox Contract

| Control | Default |
| --- | --- |
| Network | <!-- ... --> |
| Filesystem mounts | <!-- ... --> |
| Credential inheritance | <!-- ... --> |
| CPU / memory / disk quota | <!-- ... --> |
| Timeout | <!-- ... --> |
| Process-tree termination | <!-- ... --> |

## Trust Modes

| Mode | Permits | Opt-in mechanism |
| --- | --- | --- |
| <!-- ... --> | <!-- ... --> | <!-- ... --> |

## Secret Handling

- **Where secrets can appear**: <!-- ... -->
- **Redaction**: <!-- ... -->
- **Verified by**: <!-- test name -->

## Abuse Cases

- **Careless legitimate user**: <!-- ... -->
- **Product as attack amplifier**: <!-- ... -->

## Residual Risk

- <!-- not mitigated, and why that is acceptable -->

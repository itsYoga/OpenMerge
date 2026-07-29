## Context

<!-- Current state, constraints, what already exists. -->

## Component Map

<!-- Components, responsibilities, dependency direction. -->

### Forbidden Dependencies
- <!-- component A --> MUST NOT depend on <!-- component B --> — because <!-- ... -->

## Trust Boundaries

<!-- Where untrusted input crosses into trusted execution. -->

## Data Model

### <!-- entity -->
- **Identity**: <!-- how the id is derived; if content-addressed, exactly what is hashed -->
- **Fields**: <!-- ... -->

## Data Ownership and Lifecycle

| State | Written by | Location | Retention / GC | Leaves the machine? |
| --- | --- | --- | --- | --- |
| <!-- ... --> | <!-- ... --> | <!-- ... --> | <!-- ... --> | <!-- ... --> |

## Protocols

- **Wire format**: <!-- ... -->
- **Versioning rule**: <!-- ... -->
- **On version mismatch**: <!-- ... -->

## Execution Flows

### <!-- flow name -->
<!-- stage → stage, with a latency budget per stage -->

## Concurrency

- **Parallel**: <!-- ... -->
- **Serialized**: <!-- ... -->
- **Stale-work cancellation**: <!-- ... -->
- **Single-instance ownership**: <!-- ... -->

## Caching

| Cache | Key | Invalidated by | Why it is correct |
| --- | --- | --- | --- |
| <!-- ... --> | <!-- ... --> | <!-- ... --> | <!-- ... --> |

## Crash Recovery

- **Durable**: <!-- ... -->
- **Rebuilt**: <!-- ... -->
- **Guarantee after unclean shutdown**: <!-- ... -->

## Compatibility

<!-- On-disk state and protocol, forward and backward. -->

## Rejected Alternatives

### <!-- alternative -->
- **Rejected because**: <!-- ... -->

# INTERFACES

**Append-only. Never delete or rewrite another agent's entry. Never edit an entry that is not yours.**

This is the only channel between the SYSTEMS agent and the WORLD agent. If you need something in the other agent's territory, you write it here and you tell the human. You do not reach across.

## Format

```
### [YYYY-MM-DD] FROM: <agent> TO: <agent>
**Request:** what you need
**Why:** why you need it
**Proposed API:** the exact signature/name/convention you want, if applicable
**Blocking:** yes/no
**Status:** OPEN | ACCEPTED | REJECTED | DONE
```

Only the receiving agent updates `Status`. Only the human resolves a `REJECTED`.

---

## Standing contracts (do not modify, these live in ARCHITECTURE.md)

- **Grip classes** are derived from material names: `mat_<name>_grip_solid|crumbling|slick|hot`. WORLD authors. SYSTEMS reads.
- **Physics layers** are fixed in ARCHITECTURE §19.
- **EventBus signals** are fixed in ARCHITECTURE §19. WORLD may connect. WORLD may not add.
- **The character contract** is in ARCHITECTURE §16. Nau's mesh is a placeholder. Nothing couples to it.
- **`project.godot`** is SYSTEMS-owned.

---

## Log

*(empty)*

"""Sample for scripts/check.lua. The unused import is deliberate (ruff reports it)."""
import os


def greet(name: str, times: int = 1) -> str:
    return ", ".join(f"hello {name}" for _ in range(times))


print(greet("world", 2))

from pathlib import Path


def to_digits(n: int):
    return [int(d) for d in str(n)]

def to_int(digits: list[int]) -> int:
    return int("".join(str(d) for d in digits))


def load_input(script_file: str) -> list[str]:
    input_path = Path(script_file).parent / "input.txt"
    with open(input_path, "r") as f:
        return [stripped for line in f.readlines() if (stripped := line.strip())]

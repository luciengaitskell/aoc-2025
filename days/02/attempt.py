from days.lib.input import to_digits


def palindromic_n_digits(start: list[int], end: list[int]):
    assert len(start) == len(end)
    N = len(start)
    assert N % 2 == 0

    potential_ranges = zip(start[: N // 2], end[: N // 2])
    print(list(potential_ranges))


def find_palindromes(start: int, end: int):
    assert start <= end

    start_digits = to_digits(start)
    end_digits = to_digits(end)

    palindromic_n_digits(start_digits, end_digits)


if __name__ == "__main__":
    find_palindromes(134564, 585159)

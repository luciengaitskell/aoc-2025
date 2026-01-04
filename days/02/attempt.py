from days.lib.input import to_digits, to_int, load_input


def num_palindromes_n_digits(digit_count: int):
    assert digit_count % 2 == 0
    half = digit_count // 2
    return 9 * (10 ** (half - 1))  # First digit can't be zero


def num_palindromes_n_digits_before(start: int):
    digits = to_digits(start)
    N = len(digits)
    assert N >= 2
    assert N % 2 == 0

    half = N // 2

    count = to_int(digits[:half]) - to_int([1] + [0] * (half - 1))
    if to_int(digits[:half]) < to_int(digits[half:]):
        count += 1

    return count


def num_palindromes_n_digits_above(end: int):
    digits = to_digits(end)
    N = len(digits)
    assert N >= 2
    assert N % 2 == 0

    half = N // 2

    count = to_int([9] * half) + 1 - to_int(digits[:half])
    if to_int(digits[:half]) <= to_int(digits[half:]):
        count -= 1

    return count


def palindromic_n_digits(start: list[int] | None, end: list[int] | None):
    assert start is None or end is None or len(start) == len(end)
    assert start is not None or end is not None

    if start is not None:
        N = len(start)
    elif end is not None:
        N = len(end)
    else:
        raise ValueError("Either start or end must be provided")
    assert N % 2 == 0

    total = num_palindromes_n_digits(N)
    before = num_palindromes_n_digits_before(to_int(start)) if start else 0
    above = num_palindromes_n_digits_above(to_int(end)) if end else 0
    print(
        f"Total palindromes with {N} digits: {total}, before: {before}, above: {above}"
    )
    return total - before - above


def find_palindromes(start: int, end: int):
    assert start <= end

    start_digits = to_digits(start)
    end_digits = to_digits(end)

    count = 0

    for digit_count in range(len(start_digits), len(end_digits) + 1):
        if digit_count % 2 != 0:
            continue

        if digit_count == len(start_digits):
            s_digits = start_digits
        else:
            s_digits = None

        if digit_count == len(end_digits):
            e_digits = end_digits
        else:
            e_digits = None

        count += palindromic_n_digits(s_digits, e_digits)

    return count


if __name__ == "__main__":
    # print(find_palindromes(1188511880, 1188511890))
    # print(palindromic_n_digits(to_digits(565653), to_digits(565659)))
    # dig = to_digits(100001)
    # print(palindromic_n_digits(dig, dig))
    # 3*3 + 1*10*10
    # 8*8 + 7*10*10

    input_data = load_input(__file__)
    data_line = next(iter(input_data))
    ranges = data_line.split(",")

    total = 0
    for r in ranges:
        start_s, end_s = r.split("-")
        start = int(start_s)
        end = int(end_s)
        total += (result := find_palindromes(start, end))
        print(f"Range {start}-{end} has {result} palindromic numbers")

    print(f"Total palindromic numbers in all ranges: {total}")

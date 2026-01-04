from days.lib.input import to_digits, to_int, load_input

def num_invalid_ids_n_digits_between(start: int, end: int):
    assert start <= end

    digits_start = to_digits(start)
    digits_end = to_digits(end)
    N = len(digits_start)
    assert N == len(digits_end)
    assert N % 2 == 0

    half = N // 2

    count = to_int(digits_end[:half]) - to_int(digits_start[:half])
    if to_int(digits_end[:half]) > to_int(digits_end[half:]):
        count -= 1
    if to_int(digits_start[:half]) >= to_int(digits_start[half:]):
        count += 1

    return count


def invalid_ids_n_digits(start: list[int] | None, end: list[int] | None):
    assert start is None or end is None or len(start) == len(end)
    assert start is not None or end is not None

    if start is not None:
        N = len(start)
    elif end is not None:
        N = len(end)
    else:
        raise ValueError("Either start or end must be provided")
    assert N % 2 == 0

    if start is None:
        start = [1] + [0] * (N - 1)
    if end is None:
        end = [9] * N

    start_int = to_int(start)
    end_int = to_int(end)

    total = num_invalid_ids_n_digits_between(start_int, end_int)
    print(f"Total invalid IDs between {start_int}-{end_int}: {total}")
    return total


def find_invalid_ids(start: int, end: int):
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

        count += invalid_ids_n_digits(s_digits, e_digits)

    return count


if __name__ == "__main__":
    # print(find_invalid_ids(1188511880, 1188511890))
    # print(invalid_ids_n_digits(to_digits(565653), to_digits(565659)))
    # dig = to_digits(100001)
    # print(invalid_ids_n_digits(dig, dig))
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
        total += (result := find_invalid_ids(start, end))

    print(f"Total invalid IDs in all ranges: {total}")

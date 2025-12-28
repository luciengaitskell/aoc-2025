import numpy as np
from days.lib.input import to_digits, load_input


def max_number(digits: list[int], out_digits: int) -> int:
    assert len(digits) >= 2

    left_digit = np.argmax(digits[: -(out_digits - 1)])

    if out_digits == 2:
        right_digits = max(digits[left_digit + 1 :])
    else:
        right_digits = max_number(digits[left_digit + 1 :], out_digits - 1)

    return digits[left_digit] * (10 ** (out_digits - 1)) + right_digits


def solve_part1(nums: list[int]) -> int:
    return sum(max_number(to_digits(num), 2) for num in nums)

def solve_part2(nums: list[int]) -> int:
    return sum(max_number(to_digits(num), 12) for num in nums)


if __name__ == "__main__":
    input_data = load_input(__file__)
    numbers = [int(line) for line in input_data]
    print(solve_part2(numbers))

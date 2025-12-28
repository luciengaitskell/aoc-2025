import numpy as np
from days.lib.input import to_digits, load_input


def max_two_digit(num: int) -> int:
    digits = to_digits(num)
    assert len(digits) >= 2

    left_digit = np.argmax(digits[:-1])

    return digits[left_digit] * 10 + max(digits[left_digit + 1 :])


def solve(nums: list[int]) -> int:
    return sum(max_two_digit(num) for num in nums)


if __name__ == "__main__":
    input_data = load_input(__file__)
    numbers = [int(line) for line in input_data]
    print(solve(numbers))

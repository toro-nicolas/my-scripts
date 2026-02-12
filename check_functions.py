#!/bin/python3

import argparse
import shutil
import subprocess



RESET = "\033[0m"
ENDL = RESET + "\n\r"
BLACK = "\033[0;30m"
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
BLUE = "\033[0;34m"
MAGENTA = "\033[0;35m"
CYAN = "\033[0;36m"
WHITE = "\033[0;37m"
LIGHT_GREY = "\033[0;37m"
DARK_GREY = "\033[0;90m"
BOLD = "\033[1m"
ITALIC = "\033[3m"
UNDERLINE = "\033[4m"



def get_functions(bin_path):
    nm_process = subprocess.run(['nm', bin_path], stdout=subprocess.PIPE)
    if nm_process.returncode != 0:
        print("ERROR: 'nm' failed. Please ensure the binary file exists and is valid.")
        exit(1)

    result = {}
    lines = nm_process.stdout.decode().split('\n')
    tmp = [line.split(' ')[-1] for line in lines if ' U ' in line]
    tmp = [function.split(' ')[-1] for function in tmp if not function.startswith('__')]

    for function in tmp:
        if '@' not in function:
            if "unknown" not in result.keys():
                result["unknown"] = [function]
            else:
                result["unknown"].append(function)
            continue

        tmp_function = function.split('@')
        if tmp_function[1].split('_')[0] not in result.keys():
            result[tmp_function[1].split('_')[0]] = [tmp_function[0]]
        else:
            result[tmp_function[1].split('_')[0]].append(tmp_function[0])

    return result


def display_functions(functions):
    print(f"{BOLD}{UNDERLINE}Functions found in the binary:{RESET}")
    unknown_functions = None
    for key, value in functions.items():
        if key == "unknown":
            unknown_functions = value
        else:
            print(f"{BOLD}Functions from {key}:{RESET}")
            for func in value:
                print(f"    - {func}")
    if unknown_functions:
        print(f"{BOLD}Functions from unknown libraries:{RESET}")
        for func in unknown_functions:
            print(f"    - {func}")


def parse_file(file_path):
    try:
        with open(file_path, 'r') as file:
            lines = [line.strip() for line in file.readlines()]

        result = {"*": False, "functions": []}
        for line in lines:
            if line.startswith("#") or not line or line == "":
                continue
            if line == "*":
                result["*"] = True
                continue
            if line.startswith("*"):
                result[line[1:].strip()] = True
            else:
                result["functions"].append(line.strip())

        return result

    except FileNotFoundError:
        print(f"ERROR: file '{file_path}' not found.")
        exit(1)


def check_functions(functions, authorized, banned):
    forbidden = []
    for lib, functions_list in functions.items():
        for function in functions_list:

            if banned["*"] == True or lib in banned.keys():
                if function not in authorized["functions"]:
                    forbidden.append(function)
                continue

            if authorized["*"] == True or lib in authorized.keys():
                if function in banned["functions"]:
                    forbidden.append(function)
                continue

            if function in banned["functions"] or function not in authorized["functions"]:
                forbidden.append(function)

    if forbidden:
        print(f"{RED}{BOLD}Forbidden functions found:{RESET}")
        print(f"{RED}{forbidden}{RESET}")
        exit(1)
    else:
        print(f"{GREEN}{BOLD}No forbidden functions found.{RESET}")
        exit(0)


def main():
    if shutil.which("nm") is None:
        print("ERROR: 'nm' tool is not installed. Please install it to use this script.")
        exit(1)

    parser = argparse.ArgumentParser(description="Check for functions dependencies in a binary file")
    parser.add_argument("binary",
        help="Path to the binary file to analyze")
    parser.add_argument("-a", "--authorized", default="authorized.txt",
        help="Path to the authorized functions file (default: authorized.txt)")
    parser.add_argument("-b", "--banned", default="banned.txt",
        help="Path to the banned functions file (default: banned.txt)")
    args = parser.parse_args()

    functions = get_functions(args.binary)
    display_functions(functions)
    authorized = parse_file(args.authorized)
    banned = parse_file(args.banned)
    check_functions(functions, authorized, banned)


if __name__ == "__main__":
    main()
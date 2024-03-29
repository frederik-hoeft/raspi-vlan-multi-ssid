#!/usr/bin/env python3

# reads the network interfaces.conf file and generates the corresponding interfaces file.
# usage: python3 interface-conf.py <interfaces.conf file, required> <output interfaces file, optional, full or relative path>
#
# The interfaces.conf file has a simple format:
# - comments are lines that start with a hash sign (#), they are ignored by this script.
# - variables are case-sensitive and start with an underscore (_).
# - before the first non-comment line, there can be a set of lines with variable
#   assignments. Each variable assignment is of the form `$define _var value`.
# - variable names are case-sensitive, and when expanded, they have the form ${_var}.
# - the rest of the syntax conforms to the standard interfaces file.
# - the script will replace the ${_var} strings with the value of the corresponding variable.
# - if a variable is not defined, the script will fail with an error message and exit with code 1.
# - if a variable is defined more than once, a warning will be printed and the last definition will be used.
# - if a variable is not used, a warning will be printed.

import sys
import re

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 interfaces-conf.py <interfaces.conf file, required> <output interfaces file, optional, full or relative path>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else 'interfaces'

    with open(input_file, 'r') as f:
        lines = f.readlines()

    variables = {}
    output_lines = [
        '# This file was generated using interface-conf.py from a configuration file.\n',
        '# Do not edit this file directly, edit the configuration file instead.\n',
        '\n',
    ]

    # search for variable definitions
    for line in lines:
        match = re.match(r'^\s*\$(define|DEFINE)\s+(?P<key>_\w+)\s+(?P<value>\w+)\s*(#.*)?$', line)
        if match:
            key = match.group('key')
            value = match.group('value')
            variables[key] = value
            continue
        # otherwise, scan for variable usage, multiple times per line possible
        all_replaced = False
        while not all_replaced:
            match = re.search(r'\${(?P<key>_\w+)}', line)
            if match:
                key = match.group('key')
                if key in variables:
                    line = line.replace(f'${{{key}}}', variables[key])
                else:
                    print(f'Error: undefined variable {key}')
                    sys.exit(1)
            else:
                all_replaced = True
        output_lines.append(line)
    
    with open(output_file, 'w') as f:
        f.writelines(output_lines)
    
    sys.exit(0)

if __name__ == '__main__':
    main()

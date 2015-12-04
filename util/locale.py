import glob
import os
import sys
import yaml

strings_template = "ep.locales.%s.strings = {\n%s\n}"

def construct_strings(locale, filename):
    with open(filename) as openfile:
        strings = yaml.load(openfile.read())

    lines = []
    for key, value in strings.iteritems():
        lines.append('''  ["%s"] = "%s",''' % (
            key.replace('"', r'\"'), value.replace('"', r'\"')))

    return strings_template % (locale, '\n'.join(lines))

def construct_localization(candidate, target):
    with open(candidate) as openfile:
        source = openfile.read()

    string_file = candidate.replace('.lua', '.yaml')
    if os.path.exists(string_file):
        locale = os.path.basename(candidate[:-4])
        source += '\n' + construct_strings(locale, string_file)

    with open(target, 'w') as openfile:
        openfile.write(source)

def construct_localizations(source_directory, target_directory):
    for candidate in glob.glob(os.path.join(source_directory, '*.lua')):
        target = os.path.join(target_directory, os.path.basename(candidate))
        construct_localization(candidate, target)

if __name__ == '__main__':
    construct_localizations(sys.argv[1], sys.argv[2])

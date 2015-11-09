import logging
import re
import sys
from glob import glob
from os import path
from pprint import pprint

from lepl import *
from lxml.etree import Element, tostring

#logging.basicConfig(level=logging.DEBUG)

proper_header = """<Ui xmlns="http://www.blizzard.com/wow/ui" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
  xsi:schemaLocation="http://www.blizzard.com/wow/ui/C:\Projects\WoW\Bin\Interface\FrameXML\UI.xsd">
"""

frame_types = ['Button', 'CheckButton', 'ColorSelect', 'EditBox', 'Frame',
    'ScrollFrame', 'ScrollingMessageFrame', 'Slider']
implicit_flags = ['enableMouse', 'hidden', 'setAllPoints', 'virtual']

anchor_macros = ['bottomleft', 'bottomright', 'center', 'left', 'right', 'top', 'topleft', 'topright']
layer_macros = ['artwork', 'background', 'border', 'overlay']

def _evaluate_macro(macro, block, children):
    args = block.get('__args__', [])
    if macro in anchor_macros:
        point = macro.upper()
        if 'x' in block or 'y' in block:
            block['type'] = 'AbsDimension'
            return ({'type': 'Anchor', 'point': point}, [
                ({'type': 'Offset'}, [(block, [])])
            ])
        elif args:
            block = {'type': 'AbsDimension', 'x': args[0]}
            if len(args) >= 2:
                block['y'] = args[1]
            return ({'type': 'Anchor', 'point': point}, [
                ({'type': 'Offset'}, [(block, [])])
            ])
        else:
            return ({'type': 'Anchor', 'point': point}, [])
    elif macro in layer_macros:
        return ({'type': 'Layer', 'level': macro.upper()}, children)
    elif macro == 'anchor':
        anchor = {'type': 'Anchor'}
        for key in ('point', 'relativePoint', 'relativeTo'):
            if key in block:
                anchor[key] = block[key]
        dimension = {}
        if 'x' in block:
            dimension['x'] = block['x']
        if 'y' in block:
            dimension['y'] = block['y']
        children = []
        if dimension:
            dimension['type'] = 'AbsDimension'
            children.append(({'type': 'Offset'}, [(dimension, [])]))
        return (anchor, children)
    elif macro == 'color':
        if not (3 <= len(args) <= 4):
            raise ValueError()
        block.update(type='Color', r=args[0], g=args[1], b=args[2])
        if len(args) == 4:
            block['a'] = args[3]
        return (block, [])
    elif macro == 'hitrectinsets':
        if len(args) != 4:
            raise ValueError()
        return ({'type': 'HitRectInsets'}, [({'type': 'AbsInset', 'left': args[0], 'right': args[1],
            'top': args[2], 'bottom': args[3]}, [])])
    elif macro in ('normalfont', 'highlightfont'):
        block['type'] = block['type'][1:]
        if 'inherits' in block:
            if 'style' not in block:
                block['style'] = block['inherits']
            del block['inherits']
        for arg in args:
            if arg in ('LEFT', 'CENTER', 'RIGHT'):
                if 'justifyH' not in block:
                    block['justifyH'] = arg
            elif arg in ('TOP', 'MIDDLE', 'BOTTOM'):
                if 'justifyV' not in block:
                    block['justifyV'] = arg
        return (block, [])
    elif macro == 'pushedtextoffset':
        block['type'] = 'AbsDimension'
        if len(args) == 2 and 'x' not in block and 'y' not in block:
            block.update(x=args[0], y=args[1])
        return ({'type': 'PushedTextOffset'}, [(block, [])])
    elif macro == 'size':
        block['type'] = 'AbsDimension'
        if args and 'x' not in block and 'y' not in block:
            block['x'] = args[0]
            if len(args) >= 2:
                block['y'] = args[1]
        return ({'type': 'Size'}, [(block, [])])
    elif macro == 'texcoords':
        if len(args) != 4:
            raise ValueError()
        return ({'type': 'TexCoords', 'left': args[0], 'right': args[1], 'top': args[2], 'bottom': args[3]}, [])
    elif macro == 'textinsets':
        if len(args) != 4:
            raise ValueError('textinsets')
        return ({'type': 'TextInsets'}, [({'type': 'AbsInset', 'left': args[0], 'right': args[1],
            'top': args[2], 'bottom': args[3]}, [])])
    else:
        raise ValueError(macro)

colon = ~Token(':')
comma = ~Token(',')

double_quoted_string = Token(r'"[^"]*"') > (lambda v: v[0].strip('"'))
integer = Token(Integer())
real = Token(Real())
single_quoted_string = Token(r"'[^']*'") > (lambda v: v[0].strip("'"))
token = Token(Regexp('[!%\$A-Za-z_][A-Za-z0-9_]*'))

value = double_quoted_string | integer | real | single_quoted_string | token
keyvalue = token & colon & value > (lambda v: (v[0], v[1]))

parent = ~Token('\^') & token > (lambda v: ('parent', v[0]))
parentkey = ~Token('\.') & token > (lambda v: ('parentKey', v[0]))
flag = Token(Any('+-')) & token > (lambda v: (v[1], 'true' if v[0] == '+' else 'false'))

def _is_number(value):
    try:
        int(value)
    except ValueError:
        try:
            float(value)
        except ValueError:
            return False
    return True

def _parse_arguments(tokens):
    arguments = {}
    if not tokens:
        return arguments
    if isinstance(tokens[0], basestring) and tokens[0] not in implicit_flags and not _is_number(tokens[0]):
        arguments['inherits'] = tokens.pop(0)
    for token in tokens:
        if isinstance(token, tuple):
            arguments[token[0]] = token[1]
        elif token in implicit_flags:
            arguments[token] = 'true'
        else:
            if '__args__' not in arguments:
                arguments['__args__'] = []
            arguments['__args__'].append(token)
    return arguments

candidates = flag | keyvalue | parent | parentkey | token | value
arguments = ~Token('\(') & Extend(candidates[:, comma]) & ~Token('\)') > _parse_arguments
declaration = token[1:] & arguments[0:1]

assignment_line = Line(Token('%[A-Za-z]+') & ~Token('=') & value) > (lambda v: {v[0]: v[1]})
blank_line = ~Line(Empty(), indent=False)
comment_line = ~Line(Token('#.*'), indent=False)
declaration_line = Line(declaration)
script_line = Line(Token('\*[^\n]*'))

def _parse_block(tokens):
    block = {'type': tokens[0]}
    print 'parsing ' + tokens[0]
    i = 1
    if len(tokens) > i and isinstance(tokens[i], basestring) and not tokens[i].startswith('*'):
        block['name'] = tokens[i]
        print '  name = ' + block['name']
        i += 1
    if len(tokens) > i and isinstance(tokens[i], dict):
        block.update(tokens[i])
        i += 1
    if len(tokens) > i and isinstance(tokens[i], basestring) and tokens[i].startswith('*'):
        block['script'] = '\n'.join(token.lstrip('*') for token in tokens[i:])
        return (block, [])
    children = tokens[i:]
    if block['type'].startswith('!'):
        macro = block['type'].lstrip('!').lower()
        block, children = _evaluate_macro(macro, block, children)
    if children and block['type'] != 'ScrollChild':
        anchors, frames, layers, scripts, remaining = [], [], [], [], []
        for child in children:
            type = child[0]['type']
            if type == 'Anchor':
                anchors.append(child)
            elif type in frame_types:
                frames.append(child)
            elif type == 'Layer':
                layers.append(child)
            elif type.startswith('On'):
                scripts.append(child)
            else:
                remaining.append(child)
        if anchors:
            remaining.append(({'type': 'Anchors'}, anchors))
        if frames:
            remaining.append(({'type': 'Frames'}, frames))
        if layers:
            remaining.append(({'type': 'Layers'}, layers))
        if scripts:
            remaining.append(({'type': 'Scripts'}, scripts))
        children = remaining
    return (block, children)

block = Delayed()
line = Or(
    blank_line,
    block,
    comment_line,
    declaration_line > _parse_block,
    script_line
)
block += (Line(declaration & colon) & Block(line[1:])) > _parse_block

lines = assignment_line | line

source = lines[:] & Eos()
source.config.no_memoize()
source.config.compile_to_dfa()
source.config.lines(block_policy=to_right)
parser = source.get_parse()

def construct_element(block, children):
    element = Element(block.pop('type'))
    for key, value in block.iteritems():
        if key not in ('__args__', 'script'):
            element.set(key, value)
    for child in children:
        element.append(construct_element(*child))
    if 'script' in block:
        element.text = '\n%s\n' % block['script']
    return element

script_pattern = re.compile(r'(?ms)(^[ ]*<On[^>]+>.*?<\/On[^>]+>)')
def _format_script(match):
    script = match.group(1)
    indent = ' ' * script.find('<')
    lines = script.split('\n')
    for i in range(1, len(lines) - 1):
        lines[i] = indent + '  ' + lines[i]
    lines[-1] = indent + lines[-1]
    return '\n'.join(lines)

def construct(source):
    assignments = {}
    ui = Element('Ui')
    for element in parser(source):
        if isinstance(element, dict):
            assignments.update(element)
        else:
            ui.append(construct_element(*element))

    xml = tostring(ui, pretty_print=True)
    xml = script_pattern.sub(_format_script, xml)

    for key, value in assignments.iteritems():
        xml = xml.replace(key, value)

    header, body = xml.split('\n', 1)
    return proper_header + body

def parse(source_filename, xml_filename):
    with open(source_filename) as openfile:
        source = openfile.read()

    xml = construct(source)
    with open(xml_filename, 'w+') as openfile:
        openfile.write(xml)

def process_file(source_file, target_dir):
    xmlfile = path.join(target_dir, path.basename(source_file).replace('.wx', '.xml'))
    parse(source_file, xmlfile)

def process_files(source_dir, target_dir):
    for candidate in glob(path.join(source_dir, '*.wx')):
        process_file(candidate, target_dir)

if __name__ == '__main__':
    if len(sys.argv) == 3:
        source, target = sys.argv[1], sys.argv[2]
        if source.endswith('.wx'):
            process_file(source, target)
        else:
            process_files(source, target)

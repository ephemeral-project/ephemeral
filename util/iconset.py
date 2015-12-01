import os
import sys
import yaml

categories = [
    ('belts', 'bl'),
    ('boots', 'bt'),
    ('bracers', 'br'),
    ('chestpieces', 'cp'),
    ('cloaks', 'cl'),
    ('helms', 'hm'),
    ('gauntlets', 'gt'),
    ('jewelry', 'jy'),
    ('misc_armor', 'rm'),
    ('pants', 'pt'),
    ('shields', 'sd'),
    ('shoulders', 'sh'),
    ('containers', 'cn'),
    ('devices', 'dv'),
    ('drinks', 'dr'),
    ('food', 'fd'),
    ('keys', 'ky'),
    ('misc_items', 'im'),
    ('paraphernalia', 'pp'),
    ('potions', 'po'),
    ('regalia', 'rg'),
    ('trophies', 'tp'),
    ('tools', 'tl'),
    ('writings', 'wt'),
    ('essences', 'ec'),
    ('fabrics', 'fb'),
    ('herbs', 'hb'),
    ('ingredients', 'ig'),
    ('misc_materials', 'mm'),
    ('minerals', 'mn'),
    ('abilities', 'ab'),
    ('animals', 'an'),
    ('arcane', 'ac'),
    ('elemental', 'el'),
    ('holy', 'hy'),
    ('misc_symbols', 'sm'),
    ('nature', 'nt'),
    ('shadow', 'sa'),
    ('ammunition', 'au'),
    ('axes', 'ax'),
    ('maces', 'mc'),
    ('misc_weapons', 'wm'),
    ('polearms', 'pr'),
    ('ranged', 'ra'),
    ('staves', 'sv'),
    ('swords', 'sw'),
    ('wands', 'wn'),
]

toc_template = """## Interface: 60200
## Title: %(title)s
## Version: %(version)s
## Dependencies: ephemeral
## LoadOnDemand: 1
## X-Ephemeral-Compatibility: 20000
## X-Ephemeral-Module[1]: name=%(module)s, path=%(path)s, version=%(version)s
## X-Ephemeral-Module[1]-Components: iconset:%(token)s=%(path)s
iconset.lua
"""

module_template = """
%(path)s = {
  name = '%(module)s',
  version = %(version)s,
  token = '%(token)s',
  title = '%(title)s',
  official = %(official)s,
  prefixes = {
%(prefixes)s
  },
  sequence = {
%(sequence)s
  },
  icons = {
%(icons)s
  }
}
"""

module_templates = {
    False: module_template,
    True: """%(path)s={name='%(module)s',version=%(version)s,token='%(token)s',title='%(title)s',official=%(official)s,prefixes={%(prefixes)s},sequence={%(sequence)s},icons={%(icons)s}}""",
}

prefix_templates = {
    False: "    ['%02d'] = '%s',",
    True: "['%02d']='%s',",
}

sequence_templates = {
    False: "    {'%s', '%s', %d, %d},",
    True: "{'%s','%s',%d,%d},",
}

icon_templates = {
    False: "    %s = '%s',",
    True: "%s='%s',",
}

joiners = {
    False: '\n',
    True: '',
}

class Builder(object):
    def __init__(self, source_filename, addons_directory, packed=False):
        self.addons_directory = addons_directory
        self.packed = packed
        self.source_filename = source_filename

        self.icons = []
        self.prefixes = [None]
        self.sequence = []

    def build(self):
        with open(self.source_filename) as openfile:
            self.specification = yaml.load(openfile.read())

        self.token = self.specification['token']

        self.common_prefix = self.specification.get('common_prefix')
        if self.common_prefix:
            self.prefixes.append(self.common_prefix)
        
        self.candidate_prefixes = self.specification.get('candidate_prefixes', [])
        self.candidate_prefixes.sort(key=lambda v: len(v), reverse=True)

        for category, icons in self._collate_icons():
            self._construct_icons(category, icons)

        prefixes = []
        for i, prefix in enumerate(self.prefixes[1:]):
            if self.common_prefix and prefix != self.common_prefix:
                prefix = self.common_prefix + prefix
            prefixes.append(prefix_templates[self.packed] % (i + 1, prefix))

        sequence = []
        for item in self.sequence:
            sequence.append(sequence_templates[self.packed] % item)

        icons = []
        for icon in self.icons:
            icons.append(icon_templates[self.packed] % icon)

        joiner = joiners[self.packed]
        module = module_templates[self.packed] % {
            'path': self.specification['path'],
            'module': self.specification['module'],
            'version': self.specification['version'],
            'token': self.token,
            'title': self.specification['title'],
            'official': ('true' if self.specification.get('official') else 'false'),
            'prefixes': joiner.join(prefixes),
            'sequence': joiner.join(sequence),
            'icons': joiner.join(icons),
        }

        addon_directory = self.specification['addon_directory']

        target_directory = os.path.join(self.addons_directory, addon_directory)
        if not os.path.exists(target_directory):
            os.mkdir(target_directory)

        iconset_filename = os.path.join(target_directory, 'iconset.lua')
        with open(iconset_filename, 'w') as openfile:
            openfile.write(module.lstrip())

        toc_content = toc_template % {
            'title': self.specification['addon_name'],
            'version': self.specification['version'],
            'module': self.specification['module'],
            'path': self.specification['path'],
            'token': self.token,
        }

        toc_filename = os.path.join(target_directory, addon_directory + '.toc')
        with open(toc_filename, 'w') as openfile:
            openfile.write(toc_content)

    def _collate_icons(self):
        icons, path_prefix = [], self.specification.get('path_prefix', '')
        for name, category in categories:
            items = self.specification['icons'].get(name)
            if items:
                icons.append((category, items))
        else:
            return icons

    def _construct_icons(self, category, icons):
        for i, icon in enumerate(icons):
            self.icons.append(('%s%s%d' % (category, self.token, i + 1), self._add_prefix(icon)))
        self.sequence.append((category, self.token, 1, len(icons)))

    def _add_prefix(self, icon):
        for candidate in self.candidate_prefixes:
            if icon.startswith(candidate):
                if candidate not in self.prefixes:
                    self.prefixes.append(candidate)
                return '%02d%s' % (self.prefixes.index(candidate), icon[len(candidate):])
        if self.common_prefix:
            return '%02d%s' % (self.prefixes.index(self.common_prefix), icon)
        else:
            return '00%s' % icon

if __name__ == '__main__':
    source = sys.argv[1]
    target = sys.argv[2]

    packed = False
    if len(sys.argv) == 4 and sys.argv[3].lower() == 'pack':
        packed = True

    Builder(source, target, packed).build()

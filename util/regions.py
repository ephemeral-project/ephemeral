import csv
import sys

source = sys.argv[1]
target = sys.argv[2]

regions = []
zones = {}
specials = {}

for row in csv.reader(open(source)):
    try:
        id = int(row[0])
    except ValueError:
        continue

    mapid = int(row[1])
    lvlid = (int(row[2]) if row[2] else 0)
    name = row[3]
    subzone = row[4]
    scale = float(row[6])

    attrs = ['mp=%d' % mapid]
    if lvlid is not None and lvlid != 0:
        attrs.append('lv=%d' % lvlid)
    if subzone:
        attrs.append('sz="%s"' % subzone)

    attrs.append('nm="%s"' % name)
    attrs.append('sc=%0.2f' % scale)

    regions.append("    [%d] = {%s}," % (id, ', '.join(attrs)))

    if subzone:
        if mapid not in specials:
            specials[mapid] = []
        specials[mapid].append("['%s']=%d" % (subzone, id))
    else:
        if mapid not in zones:
            zones[mapid] = []
        zones[mapid].append("[%d]=%d" % (lvlid, id))

    with open(target, 'w+') as openfile:
        openfile.write('ep.spatial.regions = {\n')
        openfile.write('\n'.join(regions))
        openfile.write('\n}\n\n')

        i = 0
        openfile.write('ep.spatial.zones = {\n    ')
        for k, v in sorted(zones.iteritems()):
            if i == 3:
                sep, i = '\n    ', 0
            else:
                sep, i = ' ', i + 1
            openfile.write('[%d] = {%s},%s' % (k, ', '.join(v), sep))
        else:
            openfile.write('\n}\n\n')

        openfile.write('ep.spatial.special_zones = {\n')
        for k, v in sorted(specials.iteritems()):
            openfile.write('    [%d] = {%s},\n' % (k, ', '.join(v)))
        else:
            openfile.write('}')

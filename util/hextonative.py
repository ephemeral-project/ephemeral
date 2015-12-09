#!/usr/bin/python2
import sys, re

input = sys.stdin.read()
left, right = input.split('#', 1)
hex, right = right[:6], right[6:]

value = '%s{%0.3f, %0.3f, %0.3f, 1.0}%s' % (
    left,
    float(int(hex[0:2], 16)) / 255.0,
    float(int(hex[2:4], 16)) / 255.0,
    float(int(hex[4:6], 16)) / 255.0,
    right)

sys.stdout.write(value)

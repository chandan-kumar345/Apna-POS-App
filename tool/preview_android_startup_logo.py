"""Render the completed native vector's filled paths for visual verification."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'android/app/src/main/res'
ANDROID = '{http://schemas.android.com/apk/res/android}'
OUT = ROOT / 'build/native_receipt'
OUT.mkdir(parents=True, exist_ok=True)
vector = ET.parse(RES / 'drawable/startup_ink.xml').getroot()
position = ET.parse(RES / 'animator/startup_brand_position.xml').getroot()
offsets = {p.get(ANDROID + 'propertyName'): float(p.get(ANDROID + 'valueTo'))
           for p in position.iter('objectAnimator')}
scale = 720 / float(vector.get(ANDROID + 'viewportWidth'))
canvas = np.full((720, 720, 3), (254, 249, 247), dtype='uint8')
coverage = np.zeros((720, 720), dtype='uint8')
receipt_pixels = {}
for path in vector.iter('path'):
    name = path.get(ANDROID + 'name', '')
    if not (name.startswith('fill_') or name.startswith('receipt_')):
        continue
    contours = []
    for contour in re.findall(r'M([^Z]+)Z', path.get(ANDROID + 'pathData')):
        points = np.array([float(n) for n in re.findall(r'-?\d+(?:\.\d+)?', contour)]).reshape(-1, 2)
        points += (offsets['translateX'], offsets['translateY'])
        contours.append(np.round(points * scale).astype('int32'))
    mask = np.zeros((720, 720), dtype='uint8')
    cv2.fillPoly(mask, contours, 255)
    rgb = path.get(ANDROID + 'fillColor').lstrip('#')
    color = tuple(int(rgb[i:i+2], 16) for i in (4, 2, 0))
    canvas[mask > 0] = color
    coverage |= mask
    if name.startswith('receipt_'):
        receipt_pixels[name] = int(np.count_nonzero(mask))

y, x = np.indices((720, 720))
outside_safe_circle = (x - 360)**2 + (y - 360)**2 > 240**2
clipped = int(np.count_nonzero((coverage > 0) & outside_safe_circle))
assert clipped == 0, f'{clipped} visible pixels lie outside the safe icon circle'
assert all(count > 100 for count in receipt_pixels.values()) and len(receipt_pixels) == 3
cv2.imwrite(str(OUT / 'native-complete-logo.png'), canvas)
screen = np.full((844, 390, 3), (254, 249, 247), dtype='uint8')
screen[278:566, 51:339] = cv2.resize(canvas, (288, 288), interpolation=cv2.INTER_AREA)
cv2.imwrite(str(OUT / 'native-screen-preview.png'), screen)
print('Receipt component pixels:', receipt_pixels)
print('Pixels clipped by the safe icon circle:', clipped)

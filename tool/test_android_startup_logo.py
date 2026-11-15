"""Check the native startup artwork, which Flutter widget tests do not render."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

RES = Path(__file__).resolve().parents[1] / 'android/app/src/main/res'
ANDROID = '{http://schemas.android.com/apk/res/android}'


class NativeStartupLogoTest(unittest.TestCase):
    def test_receipt_has_border_paper_and_printed_lines(self):
        vector = ET.parse(RES / 'drawable/startup_ink.xml').getroot()
        paths = {p.get(ANDROID + 'name'): p for p in vector.iter('path')}
        for part in ['receipt_outline', 'receipt_paper', 'receipt_ink']:
            self.assertIn(part, paths, f'The Android startup logo is missing {part}')
            self.assertTrue(paths[part].get(ANDROID + 'pathData'))
        self.assertEqual(paths['receipt_outline'].get(ANDROID + 'fillColor'), '#0758F5')
        self.assertEqual(paths['receipt_paper'].get(ANDROID + 'fillColor'), '#F7F9FE')
        self.assertEqual(paths['receipt_ink'].get(ANDROID + 'fillColor'), '#06265C')

    def test_receipt_reveals_before_native_animation_ends(self):
        animation = ET.parse(RES / 'drawable/startup_writing.xml').getroot()
        targets = {p.get(ANDROID + 'name'): p for p in animation.findall('target')}
        for part in ['receipt_outline', 'receipt_paper', 'receipt_ink']:
            self.assertIn(part, targets)
            resource = targets[part].get(ANDROID + 'animation').split('/')[-1]
            animator = ET.parse(RES / f'animator/{resource}.xml').getroot()
            self.assertEqual(animator.get(ANDROID + 'propertyName'), 'fillAlpha')
            self.assertEqual(animator.get(ANDROID + 'valueTo'), '1')
            self.assertLessEqual(int(animator.get(ANDROID + 'startOffset')) +
                                 int(animator.get(ANDROID + 'duration')), 3600)

    def test_complete_artwork_moves_inside_the_safe_icon_circle(self):
        animation = ET.parse(RES / 'drawable/startup_writing.xml').getroot()
        targets = {p.get(ANDROID + 'name'): p for p in animation.findall('target')}
        self.assertIn('brand_position', targets)
        vector = ET.parse(RES / 'drawable/startup_ink.xml').getroot()
        groups = {p.get(ANDROID + 'name'): p for p in vector.iter('group')}
        self.assertIn('brand_position', groups)
        resource = targets['brand_position'].get(ANDROID + 'animation').split('/')[-1]
        animators = ET.parse(RES / f'animator/{resource}.xml').getroot()
        values = {p.get(ANDROID + 'propertyName'): float(p.get(ANDROID + 'valueTo'))
                  for p in animators.iter('objectAnimator')}
        # Original artwork center is (627,627), Android's vector center (1200,1200).
        self.assertEqual(values, {'translateX': 573.0, 'translateY': 573.0})


if __name__ == '__main__':
    unittest.main()

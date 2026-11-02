import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).parents[1]/'shell/helpers'))
import wallpaper_sample

@unittest.skipUnless(importlib.util.find_spec('PySide6'),'Optional Python Qt decoder is unavailable')
class WallpaperSamplingTests(unittest.TestCase):
    def fixture(self,path,color,width=120,height=80):
        from PySide6.QtGui import QImage,QColor
        image=QImage(width,height,QImage.Format_RGB32);image.fill(QColor(color));self.assertTrue(image.save(str(path)))
    def test_jpeg_png_webp_use_real_selected_pixels(self):
        with tempfile.TemporaryDirectory() as temp:
            for suffix in ['png','jpg','webp']:
                path=Path(temp)/('owned.'+suffix);self.fixture(path,'white')
                result=wallpaper_sample.sample(path,2560,1440,30,'cover')
                self.assertTrue(result['ok'])
                self.assertGreater(result['center']['r'],245)
    def test_contain_includes_black_letterbox_at_top(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'owned.png';self.fixture(path,'white',200,20)
            result=wallpaper_sample.sample(path,100,100,10,'contain')
            self.assertEqual(result['center'],{'r':0,'g':0,'b':0})
    def test_cover_samples_crop_not_hidden_image_top(self):
        from PySide6.QtGui import QImage,QColor
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'owned.png';image=QImage(100,200,QImage.Format_RGB32);image.fill(QColor('white'))
            for y in range(60):
                for x in range(100):image.setPixelColor(x,y,QColor('black'))
            image.save(str(path))
            result=wallpaper_sample.sample(path,200,100,20,'cover')
            self.assertEqual(result['center'],{'r':255,'g':255,'b':255})
    def test_missing_source_does_not_expose_filename(self):
        with self.assertRaisesRegex(ValueError,'Wallpaper is missing'):
            wallpaper_sample.sample('/not-a-real-private-file',100,100,10,'cover')

if __name__=='__main__':unittest.main()

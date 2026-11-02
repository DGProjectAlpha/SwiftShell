#!/usr/bin/env python3
"""Read only the chosen wallpaper file; never captures windows or the desktop."""
import argparse
import json
from pathlib import Path

def sample(path, width, height, bar_height, fit):
    from PySide6.QtCore import QSize
    from PySide6.QtGui import QImageReader
    source = Path(path)
    if not source.is_file() or source.stat().st_size > 48 * 1024 * 1024:
        raise ValueError('Wallpaper is missing or too large to analyze.')
    reader = QImageReader(str(source))
    reader.setAutoTransform(True)
    size = reader.size()
    if not size.isValid() or size.width()*size.height() > 48_000_000:
        raise ValueError('Wallpaper dimensions cannot be analyzed safely.')
    QImageReader.setAllocationLimit(128)
    ratio = min(1, 1280/max(size.width(),size.height()))
    reader.setScaledSize(QSize(max(1,round(size.width()*ratio)),max(1,round(size.height()*ratio))))
    image = reader.read()
    if image.isNull():
        raise ValueError('Wallpaper could not be decoded.')
    iw, ih = image.width(), image.height()
    scale = min(width/iw, height/ih) if fit == 'contain' else max(width/iw, height/ih)
    ox, oy = (width-iw*scale)/2, (height-ih*scale)/2
    bands = []
    values = []
    for region in range(3):
        pixels = []
        for column in range(24):
            x = width*(region+(column+.5)/24)/3
            for row in range(4):
                y = max(1,bar_height)*(row+.5)/4
                sx, sy = (x-ox)/scale, (y-oy)/scale
                if not 0 <= sx < iw or not 0 <= sy < ih:
                    rgb = (0,0,0)
                else:
                    color = image.pixelColor(min(iw-1,int(sx)),min(ih-1,int(sy)))
                    # Wallpaper surfaces composite alpha onto black.
                    rgb = tuple(round(c*color.alphaF()) for c in (color.red(),color.green(),color.blue()))
                pixels.append(rgb)
                values.append((.2126*rgb[0]+.7152*rgb[1]+.0722*rgb[2])/255)
        bands.append(dict(zip(('r','g','b'),[round(sum(p[c] for p in pixels)/len(pixels)) for c in range(3)])))
    return dict(ok=True,left=bands[0],center=bands[1],right=bands[2],mixed=max(values)-min(values)>.60)

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('path');parser.add_argument('width',type=int);parser.add_argument('height',type=int)
    parser.add_argument('bar_height',type=int);parser.add_argument('fit',choices=['cover','contain'])
    args=parser.parse_args()
    try:
        if min(args.width,args.height,args.bar_height)<=0:raise ValueError('Invalid wallpaper geometry.')
        result=sample(args.path,args.width,args.height,args.bar_height,args.fit)
    except Exception as error:
        result={'ok':False,'reason':str(error) if isinstance(error,ValueError) else 'Image analysis needs the optional Python Qt image decoder.'}
    print(json.dumps(result,separators=(',',':')))

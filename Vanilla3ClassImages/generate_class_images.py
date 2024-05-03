import math
import sys, os
from PIL import Image

target = 'Vanilla3'

def main():
    files = []
    for fpath in os.listdir(target):
        truePath = os.path.join(target, fpath)
        if os.path.isfile(truePath) and truePath.endswith('.png'):
            imageName = os.path.basename(truePath)[:-4]
            if not (imageName in files):
                files.append(imageName)
    print("Found", len(files), "files")
    files.sort()
    print("Creating ClassIcons.png")
    maxRows = int(math.ceil(len(files)*16/1024))
    print("Detected max rows:", maxRows)
    classIcons = Image.new('RGBA', (1024, maxRows*16))
    with open('config_output.lua', 'w') as config:
        config.write("{\n")
        n = 0
        count = len(files)-1
        for fileName in files:
            row = ((n*16)//1024)
            column = (n*16)-(1024*row)
            classIcons.paste(Image.open(os.path.join(target, fileName + '.png')), (column, row*16))
            config.write('\t["' + fileName + '"] = Vector2.new(' + str(column) + ', ' + str(row*16) + ')' + (',\n' if n < count else '\n}'))
            n += 1
    classIcons.save('ClassIcons.png')

if __name__ == "__main__":
    main()
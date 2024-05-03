import os, time
rbxPath = "C:\\Users\\Arthur\\AppData\\Local\\Roblox\\Versions\\"

latest = None
latestDate = None
for dir in os.listdir(rbxPath):
    dirDate = os.stat(os.path.join(rbxPath, dir)).st_mtime
    if not latest or dirDate > latestDate:
        latest = os.path.join(rbxPath, dir)
        latestDate = dirDate

if not latest:
    raise Exception("Could not find lates roblox directory")

insertableObjects = os.path.join(latest, "content", "studio_svg_textures", "Shared", "InsertableObjects", "Dark", "Standard")

with (open("export.lua", mode="w", encoding="utf8") as f):
    f.write("local BuiltinIcons = {\n")
    classes = []
    for file in os.listdir(insertableObjects):
        if not '@' in file and file.endswith('.png'):
            #path = os.path.join(insertableObjects, file)
            classes.append(f'\t[\"{file[:-4]}\"] = \"rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/{file}\"')
    f.write(',\n'.join(classes))
    f.write('\n}')

#print(time.ctime(max(os.stat(root).st_mtime for root,_,_ in os.walk(rbxPath))))
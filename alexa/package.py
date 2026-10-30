"""Build upload artifacts using only the Python standard library."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parent
out = root / 'dist'
out.mkdir(exist_ok=True)
for name, directory in [('lambda', 'lambda'), ('assets', 'assets')]:
    with ZipFile(out / f'{name}.zip', 'w', ZIP_DEFLATED) as archive:
        for path in sorted((root / directory).iterdir()):
            if path.is_file():
                archive.write(path, path.name)
print('Created alexa/dist/lambda.zip and alexa/dist/assets.zip')

from pathlib import Path
import nbformat


TESTS_DIR = Path("tests")


def validate(path: Path) -> nbformat.ValidationError | None:
    try:
        with open(path) as f:
            nb: nbformat.NotebookNode = nbformat.read(f, as_version=4)

        nbformat.validate(nb)
        return None

    except nbformat.ValidationError as error:
        return error


for path in TESTS_DIR.glob("*.ipynb"):
    error = validate(path)

    if error:
        print(f"FAIL: {path}")
        print(f"{error}")
    else:
        print(f"PASS: {path}")

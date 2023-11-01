#!/usr/bin/env python3

import os
from enum import Enum
import inquirer as inq
from docxtpl import DocxTemplate, InlineImage
from docx.shared import Mm

ROOT_DIR = os.path.dirname(__file__)
path = lambda p: os.path.join(ROOT_DIR, p)

cat_dir = lambda c: os.path.join(ROOT_DIR, c)
opt_path = lambda c, p: os.path.join(cat_dir(c), p)

class FieldType(Enum):
    CATEGORY = 1
    INPUT = 2
    LONG_INPUT = 3
    IMAGE = 4

fields = {
    "salarie_infos": {
        "type": FieldType.LONG_INPUT,
        "verbose": "Infos du salarie",
    },
    "salarie_metier": {
        "type": FieldType.INPUT,
        "verbose": "Metier du salarie",
    },
    "salarie_type_travail": {
        "type": FieldType.INPUT,
        "verbose": "Type de travail du salarie",
    },
    "dates_contrat": {
        "type": FieldType.INPUT,
        "verbose": "Dates du contrat",
    },
    "lieu_travail": {
        "type": FieldType.INPUT,
        "verbose": "Lieu de travail",
    },
    "date_signature": {
        "type": FieldType.INPUT,
        "verbose": "Date de signature",
    },
}

FillContext = dict[str, str]
FillerOptions = dict[str, FillContext]
ImageMetadata = tuple[str, str] # ("signature", "path/to/signature.png")
ImageList = list[ImageMetadata]

def get_template() -> DocxTemplate:
    return DocxTemplate(path("template.docx"))

def get_options(cat: str) -> list[str]:
    return [o.name for o in os.scandir(path=cat_dir(cat)) if o.is_dir()]

def get_option_data(cat: str, opt: str) -> (FillContext, ImageList):
    ctx = {}
    images = []

    for o in os.scandir(path=opt_path(cat, opt)):
        if not o.is_file():
            continue
        name, ext = os.path.splitext(o.name)
        field_name = f"{cat}_{name}"
        match ext:
            case ".txt":
                value = open(o.path).read()
                ctx[field_name] = value.removesuffix("\n")
            case ".png" | ".jpg" | ".jpeg":
                images.append((field_name, o.path))

    return ctx, images

def long_input(msg: str) -> str:
    print("Pour ce champ, entre ton texte sur autant de lignes que tu veux puis appuie sur control + D pour valider.")
    print(msg)
    lines = []
    while True:
        try:
            line = input()
        except EOFError:
            break
        lines.append(line)
    return "\n".join(lines)
        

def main() -> None:
    answers = inq.prompt([
        inq.List(
            "compagnie", 
            message="Quelle compagnie ?",
            choices=get_options("compagnie")
        ),
        inq.List(
            "spectacle", 
            message="Quel spectacle ?",
            choices=get_options("spectacle")
        ),
    ])
    ctx, images = {}, []
    for cat in ["compagnie", "spectacle"]:
        tmp_ctx, tmp_images = get_option_data(cat, answers[cat])
        ctx.update(tmp_ctx)
        images += tmp_images

    tpl = get_template()

    for field, img_path in images:
        ctx[field] = InlineImage(tpl, image_descriptor=img_path, width=Mm(30), height=Mm(30))

    # Values that were not provided through files and need to be entered manually
    for f_name, f in fields.items():
        msg = f["verbose"] + " : " 
        match f["type"]:
            case FieldType.INPUT:
                ctx[f_name] = input(msg)
            case FieldType.LONG_INPUT:
                ctx[f_name] = long_input(msg)

    tpl.render(ctx)
    tpl.save(os.path.join(os.path.expanduser("~"), "Desktop", "Contrat.docx"))

if __name__ == "__main__":
    main()

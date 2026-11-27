"""Read OpenDocument (.ods) and Office Open XML (.xlsx) spreadsheets with the
standard library only: each sheet as a list of rows of cell strings.

Numbers come back as their stored value (e.g. "12570" or "1.5E-2"), text as
its text. Repeated empty columns are capped, which is enough for the
published statistics tables `fetch.py` reads.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
import zipfile

_ODS_TABLE = "{urn:oasis:names:tc:opendocument:xmlns:table:1.0}"
_ODS_TEXT = "{urn:oasis:names:tc:opendocument:xmlns:text:1.0}"
_ODS_OFFICE = "{urn:oasis:names:tc:opendocument:xmlns:office:1.0}"


def read_ods(path) -> dict[str, list[list[str]]]:
    root = ET.fromstring(zipfile.ZipFile(path).read("content.xml"))
    out: dict[str, list[list[str]]] = {}
    for table in root.iter(_ODS_TABLE + "table"):
        rows = []
        for row in table.iter(_ODS_TABLE + "table-row"):
            cells: list[str] = []
            for cell in row:
                if cell.tag not in (_ODS_TABLE + "table-cell", _ODS_TABLE + "covered-table-cell"):
                    continue
                repeat = int(cell.get(_ODS_TABLE + "number-columns-repeated", "1"))
                value = cell.get(_ODS_OFFICE + "value")
                if value is None:
                    value = " ".join("".join(p.itertext()) for p in cell.findall(_ODS_TEXT + "p"))
                cells += [value] * min(repeat, 64)
            while cells and cells[-1] == "":
                cells.pop()
            if cells:
                rows.append(cells)
        out[table.get(_ODS_TABLE + "name")] = rows
    return out


_X = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
_R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"


def _col_index(ref: str) -> int:
    letters = re.match(r"[A-Z]+", ref).group(0)
    n = 0
    for ch in letters:
        n = n * 26 + ord(ch) - 64
    return n - 1


def read_xlsx(path) -> dict[str, list[list[str]]]:
    z = zipfile.ZipFile(path)
    shared: list[str] = []
    if "xl/sharedStrings.xml" in z.namelist():
        for si in ET.fromstring(z.read("xl/sharedStrings.xml")).iter(_X + "si"):
            shared.append("".join(t.text or "" for t in si.iter(_X + "t")))
    workbook = ET.fromstring(z.read("xl/workbook.xml"))
    rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
    targets = {r.get("Id"): r.get("Target") for r in rels}
    out: dict[str, list[list[str]]] = {}
    for sheet in workbook.iter(_X + "sheet"):
        target = targets[sheet.get(_R + "id")].lstrip("/")
        if not target.startswith("xl/"):
            target = "xl/" + target
        rows = []
        for row in ET.fromstring(z.read(target)).iter(_X + "row"):
            cells: dict[int, str] = {}
            for c in row.iter(_X + "c"):
                v = c.find(_X + "v")
                kind = c.get("t")
                if kind == "s" and v is not None:
                    val = shared[int(v.text)]
                elif kind == "inlineStr":
                    val = "".join(t.text or "" for t in c.iter(_X + "t"))
                else:
                    val = v.text if v is not None else ""
                cells[_col_index(c.get("r"))] = val
            if cells:
                rows.append([cells.get(i, "") for i in range(max(cells) + 1)])
        out[sheet.get("name")] = rows
    return out


def read(path) -> dict[str, list[list[str]]]:
    return read_xlsx(path) if str(path).endswith(".xlsx") else read_ods(path)

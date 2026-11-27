"""Download the open statistics the synthetic population is built from, and
extract the figures it uses into `population/margins.json`.

    python3 population/fetch.py            # download into population/raw/, write margins.json
    python3 population/fetch.py --offline  # re-extract from files already in population/raw/

Every source is published under the Open Government Licence v3.0 and is
downloaded without an account or key. `margins.json` records, for each file,
its URL, publisher, licence, the date it was fetched and its SHA-256, so the
extraction can be repeated and checked. A few figures are only published as
text in a statistical release (no table to download); those are entered here
with the page and the sentence they come from (`TEXT_FIGURES`).

No microdata is used: no survey records, no administrative records, nothing
from the UK Data Service. Only published aggregate tables.

Stdlib only.
"""

from __future__ import annotations

import argparse
import csv
import datetime
import hashlib
import io
import json
import pathlib
import sys
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sheets  # noqa: E402

RAW = HERE / "raw"
OUT = HERE / "margins.json"
OGL = "Open Government Licence v3.0"
OGL_URL = "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/"

# id -> (title, publisher, url, local file name)
SOURCES = {
    "hmrc_t2_1": (
        "Table 2.1 Number of individual Income Tax payers (projections to 2026 to 2027, July 2026)",
        "HM Revenue & Customs",
        "https://assets.publishing.service.gov.uk/media/6a54e2a9a4890e65cce64dd3/Table_2.1_Number_of_individual_Income_Tax_Payers.ods",
        "hmrc_t2_1.ods",
    ),
    "hmrc_t2_2": (
        "Table 2.2 Number of Income Tax payers by country (projections to 2026 to 2027, July 2026)",
        "HM Revenue & Customs",
        "https://assets.publishing.service.gov.uk/media/6a54e2b01228eb26a4cab84c/Table_2.2_Number_of_Income_Tax_payers_by_country.ods",
        "hmrc_t2_2.ods",
    ),
    "hmrc_t2_5": (
        "Table 2.5 Income Tax liabilities by income range (projections to 2026 to 2027, July 2026)",
        "HM Revenue & Customs",
        "https://assets.publishing.service.gov.uk/media/6a5a4b987eb057103bd946a5/Table_2.5_Income_Tax_liabilites_by_income_range.ods",
        "hmrc_t2_5.ods",
    ),
    "hmrc_t3_6": (
        "Table 3.6 Profit, employment and pension income, 2023 to 2024",
        "HM Revenue & Customs",
        "https://assets.publishing.service.gov.uk/media/69f20fa8c42061e837e3ac67/Table_3.6_2324.ods",
        "hmrc_t3_6.ods",
    ),
    "hmrc_t3_7": (
        "Table 3.7 Property, interest, dividend and other income, 2023 to 2024",
        "HM Revenue & Customs",
        "https://assets.publishing.service.gov.uk/media/69f20fe2b8ce27acfa096850/Table_3.7_2324.ods",
        "hmrc_t3_7.ods",
    ),
    "hmrc_cb": (
        "Child Benefit Statistics: annual release, data at August 2025, main tables",
        "HM Revenue & Customs",
        "https://assets.publishing.service.gov.uk/media/6a8d696901bbff0bf8f97903/Child_Benefit_August_2025_Main_Tables.ods",
        "hmrc_cb.ods",
    ),
    "hmrc_receipts": (
        "HMRC tax receipts and National Insurance contributions for the UK: statistics table (November 2026)",
        "HM Revenue & Customs",
        "https://assets.publishing.service.gov.uk/media/6af706889be17c68c69ca800/NS_Table.ods",
        "hmrc_receipts.ods",
    ),
    "dwp_bect": (
        "Benefit expenditure and caseload tables: autumn 2026",
        "Department for Work and Pensions",
        "https://assets.publishing.service.gov.uk/media/6b0061d507e86cba56db977a/Benefit-Expenditure-and-Caseloads-Tables-Autumn-2026..ods",
        "dwp_bect.ods",
    ),
    "ons_families": (
        "Families and households in the UK: 2025 (dataset)",
        "Office for National Statistics",
        "https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/birthsdeathsandmarriages/families/datasets/familiesandhouseholdsfamiliesandhouseholds/current/familiesandhouseholdsuk2025.xlsx",
        "ons_families.xlsx",
    ),
    "ons_mye": (
        "Population estimates for the UK, mid-2025 (MYE2, persons by single year of age)",
        "Office for National Statistics",
        "https://www.ons.gov.uk/file?uri=/peoplepopulationandcommunity/populationandmigration/populationestimates/datasets/populationestimatesforukenglandandwalesscotlandandnorthernireland/mid2025/mye25tablesuk.xlsx",
        "ons_mye.xlsx",
    ),
    "hmrc_trr": (
        "Direct effects of illustrative tax changes (ready reckoner), June 2025",
        "HM Revenue & Customs",
        "https://assets.publishing.service.gov.uk/media/68552862b46781eacfd71d71/June_2025_TRR_ODS__1_.ods",
        "hmrc_trr.ods",
    ),
    "census_tenure": (
        "Census 2021 TS054 Tenure, England and Wales (Nomis API, no key)",
        "Office for National Statistics (Nomis)",
        "https://www.nomisweb.co.uk/api/v01/dataset/NM_2072_1.data.csv?date=latest&geography=2092957703&measures=20100&select=geography_name,c2021_tenure_9_name,obs_value",
        "census_tenure.csv",
    ),
}

# Figures published only as text in a release. Each with its page and sentence.
TEXT_FIGURES = {
    "uc_share_with_children_aug_2026": {
        "value": 0.441,
        "page": "https://www.gov.uk/government/statistics/universal-credit-statistics-29-april-2013-to-13-august-2026/universal-credit-quarterly-statistics-29-april-2013-to-13-august-2026",
        "quote": "Households with children accounted for 44.1% of households on Universal Credit with a payment in August 2026.",
        "publisher": "Department for Work and Pensions",
    },
    "private_rent_uk_monthly_oct_2026": {
        "value": 1411,
        "page": "https://www.ons.gov.uk/economy/inflationandpriceindices/bulletins/privaterentandhousepricesuk/latest",
        "quote": "The average monthly private rent in the UK was £1,411 in October 2026.",
        "publisher": "Office for National Statistics",
    },
    "private_rent_london_monthly_oct_2026": {
        "value": 2350,
        "page": "https://www.ons.gov.uk/economy/inflationandpriceindices/bulletins/privaterentandhousepricesuk/latest",
        "quote": "Average rent was highest in London (£2,350) and lowest in the North East (£793) in October 2026.",
        "publisher": "Office for National Statistics",
    },
    "social_rent_weekly_england_2025_26": {
        "value": 121.72,
        "page": "https://www.gov.uk/government/statistics/private-registered-provider-social-housing-stock-and-rents-in-england-2025-to-2026/private-registered-providers-stock-and-rents-in-england-summary-key-facts",
        "quote": "Average general needs net rent £121.72 per week",
        "publisher": "Regulator of Social Housing",
    },
}


def download(force: bool) -> None:
    RAW.mkdir(exist_ok=True)
    for sid, (_, _, url, name) in SOURCES.items():
        path = RAW / name
        if path.exists() and not force:
            continue
        req = urllib.request.Request(url, headers={"User-Agent": "uk-tax-lean population fetch"})
        with urllib.request.urlopen(req, timeout=120) as r:
            path.write_bytes(r.read())
        print(f"fetched {sid}: {path.stat().st_size} bytes", file=sys.stderr)


def num(s: str) -> float:
    return float(str(s).replace(",", "").replace("£", "").replace("+", ""))


def _row(rows, first: str):
    for r in rows:
        if r and r[0].strip().startswith(first):
            return r
    raise KeyError(first)


def extract_hmrc() -> dict:
    t25 = sheets.read(RAW / "hmrc_t2_5.ods")["2_5_IT_Liabilities_2026-27"]
    ranges = []
    for r in t25:
        if not r or not r[0]:
            continue
        head = r[0].strip()
        if head.startswith("£2,000,000"):
            lower = 2_000_000
        elif head.replace(".", "").isdigit():
            lower = int(num(head))
        else:
            continue
        ranges.append({
            "lower": lower,
            "taxpayers": num(r[9]) * 1e3,
            "total_income": num(r[10]) * 1e6,
            "liability": num(r[11]) * 1e6,
        })
    for a, b in zip(ranges, ranges[1:]):
        a["upper"] = b["lower"]
    ranges[-1]["upper"] = None
    total = _row(t25, "All Ranges")

    t21 = sheets.read(RAW / "hmrc_t2_1.ods")["2_1_IT_payers_by_demographic"]
    r21 = _row(t21, "2026 to 2027")
    t22 = sheets.read(RAW / "hmrc_t2_2.ods")
    by_country = {}
    for key, sheet in (("england", "EN"), ("wales", "WA"), ("scotland", "SC"),
                       ("northern_ireland", "NI"), ("london", "LD")):
        by_country[key] = num(_row(t22[f"2_2_Taxpayers_by_demographic_{sheet}"], "2026 to 2027")[1]) * 1e3

    def by_range(path, sheet, names):
        rows = sheets.read(path)[sheet]
        out = []
        for r in rows:
            if not r or not r[0].replace(".", "").isdigit():
                continue
            entry = {"lower": int(num(r[0]))}
            for i, name in enumerate(names):
                def val(x):
                    return 0.0 if x.startswith("[") else num(x)
                entry[name] = {"n": val(r[1 + 3 * i]) * 1e3, "amount": val(r[2 + 3 * i]) * 1e6}
            entry["taxpayers"] = num(r[1 + 3 * len(names)]) * 1e3 if sheet == "Table_3_6" else None
            out.append(entry)
        return out

    t36 = by_range(RAW / "hmrc_t3_6.ods", "Table_3_6",
                   ["self_employment", "employment", "state_pension", "other_pensions"])
    t37 = by_range(RAW / "hmrc_t3_7.ods", "Table_3_7",
                   ["property", "interest", "dividends", "other"])
    sources = []
    for a, b in zip(t36, t37):
        assert a["lower"] == b["lower"]
        entry = {k: v for k, v in a.items() if k != "taxpayers"}
        entry.update({k: v for k, v in b.items() if k not in ("lower", "taxpayers")})
        sources.append(entry)

    rec = sheets.read(RAW / "hmrc_receipts.ods")
    ra = rec["Receipts_Annually"]
    header = next(r for r in ra if r and r[0].startswith("Table 2 HMRC Receipts"))
    row = _row(ra, "2025 to 2026")

    def col(name):
        return num(row[next(i for i, h in enumerate(header) if h.startswith(name))]) * 1e6

    ea = rec["Expenditure_Annually"]
    eh = next(r for r in ea if r and r[0].startswith("Table 4 HMRC Expenditure"))
    er = _row(ea, "2025 to 2026")

    cb = sheets.read(RAW / "hmrc_cb.ods")

    def cb_row(sheet, code):
        rows = cb[sheet]
        return next(r for r in rows if len(r) > 1 and r[1] == code)

    def fam(r):
        return {"families": num(r[2]), "one": num(r[3]), "two": num(r[4]),
                "three_plus": sum(num(x) for x in r[5:9] if not x.startswith("[")),
                "children": num(r[9]),
                "children_by_age": {"0_4": num(r[10]), "5_10": num(r[11]), "11_15": num(r[12]), "16_plus": num(r[13])}}

    cb_paid = {c: fam(cb_row("Table_3", code)) for c, code in
               (("uk", "K02000001"), ("england", "E92000001"), ("wales", "W92000004"),
                ("scotland", "S92000003"), ("northern_ireland", "N92000002"), ("london", "E12000007"))}
    opted = fam(cb_row("Table_9", "K02000001"))
    ages = {}
    for r in cb["Table_4"]:
        if r and r[0].isdigit():
            ages[int(r[0])] = num(r[1])

    trr = sheets.read(RAW / "hmrc_trr.ods")["Publication_Format"]

    def trr_row(label):
        r = _row(trr, label)
        return {"2026_27": num(r[1]) * 1e6, "2027_28": num(r[2]) * 1e6}

    return {
        "ready_reckoner": {
            "basic_rate_1p": trr_row("Change basic rate by 1p"),
            "personal_allowance_100": trr_row("Change personal allowance by £100"),
        },
        "taxpayers_by_range_2026_27": ranges,
        "taxpayers_all_ranges_2026_27": {"taxpayers": num(total[9]) * 1e3, "total_income": num(total[10]) * 1e6,
                                         "liability": num(total[11]) * 1e6},
        "taxpayers_by_rate_2026_27": {"all": num(r21[1]) * 1e3, "savers": num(r21[3]) * 1e3,
                                      "basic": num(r21[4]) * 1e3, "higher": num(r21[5]) * 1e3,
                                      "additional": num(r21[6]) * 1e3, "under_65": num(r21[9]) * 1e3,
                                      "65_plus": num(r21[10]) * 1e3, "state_pension_age": num(r21[11]) * 1e3},
        "taxpayers_by_country_2026_27": by_country,
        "income_sources_by_range_2023_24": sources,
        "receipts_2025_26": {"income_tax": col("Income Tax"), "nics": col("National Insurance"),
                             "class1_employer": col("PAYE NIC1 (EMP'er)"),
                             "class1_employee": col("PAYE NIC1 (EMP'ee)"),
                             "sa_class2_4": col("SA NIC2&4"),
                             "child_benefit_paid": num(er[next(i for i, h in enumerate(eh) if h.startswith("Child Benefit"))]) * 1e6},
        "child_benefit_in_payment_aug_2025": cb_paid,
        "child_benefit_opted_out_aug_2025": opted,
        "child_benefit_children_by_age_aug_2025": ages,
    }


def extract_dwp() -> dict:
    s = sheets.read(RAW / "dwp_bect.ods")

    def find(sheet, label, after=None, col_year="2026/27"):
        """The 2026/27 value of the first row labelled `label` (below the row
        labelled `after`, if given), in the table whose header holds the year."""
        rows = s[sheet]
        start = 0
        if after:
            start = next(i for i, r in enumerate(rows) if len(r) > 1 and r[1].startswith(after))
        year_col = None
        for r in rows[start:]:
            for j, c in enumerate(r):
                if c.startswith(col_year):
                    year_col = j
            if year_col is not None and len(r) > 1 and r[1].strip() == label:
                return num(r[year_col])
        raise KeyError((sheet, label))

    uc = "Universal_Credit_and_equivalent"
    return {
        "uc_spend": find(uc, "Universal Credit") * 1e6,
        "uc_housing_element_spend": find(uc, "of which Housing Element") * 1e6,
        "uc_households": find(uc, "Universal Credit", after="Universal Credit and equivalents caseloa") * 1e3,
        "uc_lcwra": _first_prefix(s[uc], "of which limited capability for work and",
                                  "Universal Credit and equivalents caseloa") * 1e3,
        "uc_housing_element": find(uc, "Universal Credit Housing Element", after="Universal Credit and equivalents caseloa") * 1e3,
        "uc_carer_element": find(uc, "Universal Credit Carers Element", after="Universal Credit and equivalents caseloa") * 1e3,
        "carers_allowance_in_payment": find("Carers_Allowance", "of which in payment") * 1e3,
        "carers_allowance_spend": find("Carers_Allowance", "Total") * 1e6,
        "child_benefit_spend": find("UK_welfare_", "Child Benefit") * 1e9,
        "tax_free_childcare_spend": find("UK_welfare_", "Tax Free Childcare") * 1e9,
        "state_pension_caseload": find("State_Pension", "Total State Pension Caseload") * 1e3,
        "state_pension_caseload_abroad": find("State_Pension", "State Pension paid outside UK included above",
                                              after="State Pension caseload") * 1e3,
        "state_pension_spend": find("State_Pension", "Total") * 1e6,
        "pension_credit_caseload": find("Pension_Credit", "Pension Credit", after="Pension Credit caseload") * 1e3,
    }


def _first_prefix(rows, prefix, after):
    start = next(i for i, r in enumerate(rows) if len(r) > 1 and r[1].startswith(after))
    year_col = None
    for r in rows[start:]:
        for j, c in enumerate(r):
            if c.startswith("2026/27"):
                year_col = j
        if year_col is not None and len(r) > 1 and r[1].startswith(prefix):
            return num(r[year_col])
    raise KeyError(prefix)


def extract_ons() -> dict:
    fam = sheets.read(RAW / "ons_families.xlsx")

    def est(sheet, label, nth=0):
        hits = [r for r in fam[sheet] if r and r[0].strip().startswith(label)]
        return num(hits[nth][1]) * 1e3

    t3 = fam["3"]
    # Table 3: the "All families" block is last; its rows follow the label.
    i_all = max(i for i, r in enumerate(t3) if r and r[0].strip() == "All families")
    i_lone = next(i for i, r in enumerate(t3) if r and r[0].strip().startswith("Lone parent family"))

    def nxt(i, label):
        return num(next(r for r in t3[i + 1:] if r and r[0].strip().startswith(label))[1]) * 1e3

    families = {
        "all_couple_families": sum(est("1", lab) for lab in (
            "Married couple family", "Civil partner couple family",
            "Opposite-sex cohabiting couple family", "Same-sex cohabiting couple family")),
        "lone_parent_families": est("1", "Lone parent family"),
        "dependent_children": {
            "all": {k: nxt(i_all, lab) for k, lab in (("one", "One child"), ("two", "Two children"),
                                                       ("three_plus", "Three or more children"))},
            "lone_parent": {k: nxt(i_lone, lab) for k, lab in (("one", "One child"), ("two", "Two children"),
                                                                ("three_plus", "Three or more children"))},
        },
        "households": sum(est("5", lab) for lab in ("One person", "Two people", "Three people", "Four people",
                                                    "Five people", "Six or more people")),
        "one_person_households": est("5", "One person"),
        "living_alone_65_plus": est("6", "65 and over"),
    }

    mye = sheets.read(RAW / "ons_mye.xlsx")["MYE2 - Persons"]
    header = next(r for r in mye if r and r[0] == "Code")
    age_col = {}
    for j, h in enumerate(header):
        h = h.strip()
        if h.isdigit():
            age_col[int(h)] = j
        elif h.startswith("90"):
            age_col[90] = j
    pop = {}
    for key, code in (("uk", "K02000001"), ("england", "E92000001"), ("wales", "W92000004"),
                      ("scotland", "S92000003"), ("northern_ireland", "N92000002"), ("london", "E12000007")):
        r = next(r for r in mye if r and r[0] == code)
        by_age = {a: num(r[j]) for a, j in age_col.items()}
        pop[key] = {"all": num(r[3]), "under_16": sum(v for a, v in by_age.items() if a < 16),
                    "16_plus": sum(v for a, v in by_age.items() if a >= 16),
                    "66_plus": sum(v for a, v in by_age.items() if a >= 66)}
        if key == "uk":
            pop[key]["by_age"] = by_age

    tenure = {}
    with open(RAW / "census_tenure.csv", newline="") as f:
        for r in csv.DictReader(f):
            tenure[r["C2021_TENURE_9_NAME"]] = num(r["OBS_VALUE"])
    return {
        "families_2025": families,
        "population_mid_2025": pop,
        "tenure_census_2021_england_wales": {
            "all": tenure["Total: All households"],
            "owned": tenure["Owned"] + tenure["Shared ownership"],
            "social_rented": tenure["Social rented"],
            "private_rented": tenure["Private rented or lives rent free"],
        },
    }


def sha256(path) -> str:
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--offline", action="store_true", help="use the files already in population/raw/")
    ap.add_argument("--force", action="store_true", help="download again even if a file is present")
    args = ap.parse_args()
    if not args.offline:
        download(args.force)
    previous = json.loads(OUT.read_text()) if OUT.exists() else {}
    sources = {}
    for sid, (title, publisher, url, name) in SOURCES.items():
        digest = sha256(RAW / name)
        old = previous.get("sources", {}).get(sid, {})
        retrieved = old.get("retrieved") if old.get("sha256") == digest else datetime.date.today().isoformat()
        sources[sid] = {"title": title, "publisher": publisher, "url": url, "licence": OGL,
                        "licence_url": OGL_URL, "retrieved": retrieved, "sha256": digest}
    for sid, fig in TEXT_FIGURES.items():
        sources[sid] = {"title": fig["quote"], "publisher": fig["publisher"], "url": fig["page"],
                        "licence": OGL, "licence_url": OGL_URL, "retrieved": "2026-11-27",
                        "sha256": None}
    data = {
        "note": "Extracted by population/fetch.py from published open statistics. Do not edit by hand.",
        "sources": sources,
        "hmrc": extract_hmrc(),
        "dwp": extract_dwp(),
        "ons": extract_ons(),
        "text": {k: v["value"] for k, v in TEXT_FIGURES.items()},
    }
    OUT.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n")
    print(f"wrote {OUT}", file=sys.stderr)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Strip Period Tracker widget/notification targets from SadieMarie.xcodeproj."""

from __future__ import annotations

import re
import sys
from pathlib import Path

PBX = Path(__file__).resolve().parents[1] / "SadieMarie.xcodeproj" / "project.pbxproj"

REMOVE_IDS = {
    "73358C7E2F8ECC5800DFA772",
    "73358C7F2F8ECC5800DFA772",
    "73358C802F8ECC5800DFA772",
    "73358C812F8ECC5800DFA772",
    "73358C822F8ECC5800DFA772",
    "73358C842F8ECC5800DFA772",
    "73358C852F8ECC5800DFA772",
    "73358C862F8ECC5800DFA772",
    "73358C872F8ECC5800DFA772",
    "73358C882F8ECC5800DFA772",
    "73358C942F8ECC5A00DFA772",
    "73358C952F8ECC5A00DFA772",
    "73358C962F8ECC5A00DFA772",
    "73358C972F8ECC5A00DFA772",
    "73358C982F8ECC5A00DFA772",
    "73358C992F8ECC5A00DFA772",
    "73358C9A2F8ECC5A00DFA772",
    "73358C9B2F8ECC5A00DFA772",
    "73358CAB2F901C8300DFA772",
    "73358CAC2F901C8300DFA772",
    "73358CAD2F901C8300DFA772",
    "73358CAE2F901C8300DFA772",
    "73358CAF2F901C8300DFA772",
    "73358CB02F901C8300DFA772",
    "73358CB42F901C8300DFA772",
    "73358CB52F901C8300DFA772",
    "73358CB62F901C8300DFA772",
    "73358CB72F901C8300DFA772",
    "73358CB82F901C8300DFA772",
    "73358CB92F901C8300DFA772",
    "73358CBA2F901C8300DFA772",
    "73358CBC2F902AB700DFA772",
    "73358CA32F8ECD9400DFA772",
    "73358CA42F8EDFD600DFA772",
    "73358C832F8ECC5800DFA772",
}


def remove_object_block(text: str, obj_id: str) -> str:
    marker = f"\n\t\t{obj_id} "
    start = text.find(marker)
    if start == -1:
        return text
    brace_start = text.find("{", start)
    if brace_start == -1:
        return text
    depth = 0
    i = brace_start
    while i < len(text):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                if end < len(text) and text[end] == ";":
                    end += 1
                return text[:start] + text[end:]
        i += 1
    return text


def remove_array_refs(text: str, obj_id: str) -> str:
    text = re.sub(rf"\n\t\t\t\t{obj_id} /\*.*?\*/,", "", text)
    text = re.sub(rf"\n\t\t\t{obj_id} /\*.*?\*/,", "", text)
    return text


def main() -> int:
    text = PBX.read_text(encoding="utf-8")
    for obj_id in sorted(REMOVE_IDS, key=len, reverse=True):
        text = remove_object_block(text, obj_id)
        text = remove_array_refs(text, obj_id)

    text = text.replace(
        "\t\t\tdependencies = (\n"
        "\t\t\t\t73358C952F8ECC5A00DFA772 /* PBXTargetDependency */,\n"
        "\t\t\t\t73358CB52F901C8300DFA772 /* PBXTargetDependency */,\n"
        "\t\t\t);\n",
        "\t\t\tdependencies = (\n\t\t\t);\n",
    )

    text = text.replace("productName = PeriodTracker;", "productName = SadieMarie;")
    text = text.replace("productName = PeriodTrackerTests;", "productName = SadieMarieTests;")
    text = text.replace("productName = PeriodTrackerUITests;", "productName = SadieMarieUITests;")
    text = text.replace("remoteInfo = PeriodTracker;", "remoteInfo = SadieMarie;")
    text = text.replace("PRODUCT_MODULE_NAME = BaseAppTemplate;", "PRODUCT_MODULE_NAME = SadieMarie;")
    text = text.replace(
        'INFOPLIST_FILE = "/Users/leonbuchmiller/Documents/Projects/My Apps/SadieMarie/SadieMarie/Info.plist";',
        "INFOPLIST_FILE = SadieMarie/Info.plist;",
    )

    if text.count("{") != text.count("}"):
        print(f"ERROR: unbalanced braces {text.count('{')} vs {text.count('}')}")
        return 1

    PBX.write_text(text, encoding="utf-8")
    print(f"Cleaned {PBX}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

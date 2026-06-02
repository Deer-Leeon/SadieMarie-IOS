#!/usr/bin/env python3
"""Remove Period Tracker targets; rename PartnerWidgets → SadieMarieWidgets in pbxproj."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = ROOT / "SadieMarie.xcodeproj" / "project.pbxproj"

# NotificationService only (keep PartnerWidgets IDs → SadieMarieWidgets)
REMOVE_IDS = {
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
        "\t\t\tdependencies = (\n"
        "\t\t\t\t73358C952F8ECC5A00DFA772 /* PBXTargetDependency */,\n"
        "\t\t\t);\n",
    )
    text = text.replace(
        "\t\t\tfiles = (\n"
        "\t\t\t\t73358C962F8ECC5A00DFA772 /* PartnerWidgets.appex in Embed Foundation Extensions */,\n"
        "\t\t\t\t73358CB62F901C8300DFA772 /* NotificationService.appex in Embed Foundation Extensions */,\n"
        "\t\t\t);\n",
        "\t\t\tfiles = (\n"
        "\t\t\t\t73358C962F8ECC5A00DFA772 /* SadieMarieWidgets.appex in Embed Foundation Extensions */,\n"
        "\t\t\t);\n",
    )

    replacements = [
        ("PartnerWidgetsExtensionDebug.entitlements", "SadieMarieWidgetsExtensionDebug.entitlements"),
        ("PartnerWidgetsExtension.entitlements", "SadieMarieWidgetsExtension.entitlements"),
        ("PartnerWidgets/Info.plist", "SadieMarieWidgets/Info.plist"),
        ("path = PartnerWidgets;", "path = SadieMarieWidgets;"),
        ("/* PartnerWidgets */", "/* SadieMarieWidgets */"),
        ("/* PartnerWidgets.appex */", "/* SadieMarieWidgets.appex */"),
        ("PartnerWidgets.appex", "SadieMarieWidgets.appex"),
        ("name = PartnerWidgets;", "name = SadieMarieWidgets;"),
        ("productName = PartnerWidgetsExtension;", "productName = SadieMarieWidgets;"),
        ("remoteInfo = PartnerWidgetsExtension;", "remoteInfo = SadieMarieWidgets;"),
        ("73358C812F8ECC5800DFA772 /* PartnerWidgets */", "73358C812F8ECC5800DFA772 /* SadieMarieWidgets */"),
        (
            'PRODUCT_BUNDLE_IDENTIFIER = "com.lj-buchmiller.SadieMarie.dev.PartnerWidgets";',
            'PRODUCT_BUNDLE_IDENTIFIER = "com.lj-buchmiller.SadieMarie.dev.SadieMarieWidgets";',
        ),
        (
            'PRODUCT_BUNDLE_IDENTIFIER = "com.lj-buchmiller.SadieMarie.PartnerWidgets";',
            'PRODUCT_BUNDLE_IDENTIFIER = "com.lj-buchmiller.SadieMarie.SadieMarieWidgets";',
        ),
        ("INFOPLIST_KEY_CFBundleDisplayName = SadieMarie;", "INFOPLIST_KEY_CFBundleDisplayName = \"Sadie Marie Widget\";"),
        ("productName = PeriodTracker;", "productName = SadieMarie;"),
        ("productName = PeriodTrackerTests;", "productName = SadieMarieTests;"),
        ("productName = PeriodTrackerUITests;", "productName = SadieMarieUITests;"),
        ("remoteInfo = PeriodTracker;", "remoteInfo = SadieMarie;"),
        ("PRODUCT_MODULE_NAME = BaseAppTemplate;", "PRODUCT_MODULE_NAME = SadieMarie;"),
        ("PeriodTrackerTests.swift", "SadieMarieTests.swift"),
        (
            'INFOPLIST_FILE = "/Users/leonbuchmiller/Documents/Projects/My Apps/SadieMarie/SadieMarie/Info.plist";',
            "INFOPLIST_FILE = SadieMarie/Info.plist;",
        ),
        (
            'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Dev Cycle Tracker.app/Dev Cycle Tracker";',
            'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/SadieMarie.app/SadieMarie";',
        ),
        (
            'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/OV Cycle Tracker.app/OV Cycle Tracker";',
            'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/SadieMarie.app/SadieMarie";',
        ),
        ("group.com.lj-buchmiller.PeriodTracker", "group.com.lj-buchmiller.SadieMarie"),
    ]
    for old, new in replacements:
        text = text.replace(old, new)

    # Drop NotificationService from targets list if still present
    text = text.replace("\n\t\t\t\t73358CAE2F901C8300DFA772 /* NotificationService */,", "")

    if text.count("{") != text.count("}"):
        print(f"ERROR: unbalanced braces {text.count('{')} vs {text.count('}')}")
        return 1

    PBX.write_text(text, encoding="utf-8")
    print(f"Migrated {PBX}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

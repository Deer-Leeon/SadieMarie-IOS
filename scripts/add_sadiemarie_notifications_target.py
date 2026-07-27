#!/usr/bin/env python3
"""Add SadieMarieNotifications NSE target to SadieMarie.xcodeproj."""

from __future__ import annotations

import sys
from pathlib import Path

PBX = Path(__file__).resolve().parents[1] / "SadieMarie.xcodeproj" / "project.pbxproj"


def main() -> int:
    text = PBX.read_text(encoding="utf-8")
    if "SadieMarieNotifications" in text and "73358CAE2F901C8300DFA772" in text:
        print("SadieMarieNotifications target already present")
        return 0

    if "73358CAE2F901C8300DFA772" in text:
        print("ERROR: conflicting notification target IDs")
        return 1

    insert_build = """\t\t73358CB62F901C8300DFA772 /* SadieMarieNotifications.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = 73358CAF2F901C8300DFA772 /* SadieMarieNotifications.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
"""
    text = text.replace("/* End PBXBuildFile section */", insert_build + "/* End PBXBuildFile section */")

    insert_proxy = """\t\t73358CB42F901C8300DFA772 /* PBXContainerItemProxy */ = {
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = 735A66EB2F7640EF00C6ADEE /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = 73358CAE2F901C8300DFA772;
\t\t\tremoteInfo = SadieMarieNotifications;
\t\t};
"""
    text = text.replace("/* End PBXContainerItemProxy section */", insert_proxy + "/* End PBXContainerItemProxy section */")

    text = text.replace(
        "\t\t\tfiles = (\n"
        "\t\t\t\t73358C962F8ECC5A00DFA772 /* SadieMarieWidgets.appex in Embed Foundation Extensions */,\n"
        "\t\t\t);\n",
        "\t\t\tfiles = (\n"
        "\t\t\t\t73358C962F8ECC5A00DFA772 /* SadieMarieWidgets.appex in Embed Foundation Extensions */,\n"
        "\t\t\t\t73358CB62F901C8300DFA772 /* SadieMarieNotifications.appex in Embed Foundation Extensions */,\n"
        "\t\t\t);\n",
    )

    insert_refs = """\t\t73358CAF2F901C8300DFA772 /* SadieMarieNotifications.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = SadieMarieNotifications.appex; sourceTree = BUILT_PRODUCTS_DIR; };
\t\t73358CC12F901C8300DFA772 /* SadieMarieNotificationsExtension.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = SadieMarieNotificationsExtension.entitlements; sourceTree = "<group>"; };
\t\t73358CC22F901C8300DFA772 /* SadieMarieNotificationsExtensionDebug.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = SadieMarieNotificationsExtensionDebug.entitlements; sourceTree = "<group>"; };
"""
    text = text.replace("/* End PBXFileReference section */", insert_refs + "/* End PBXFileReference section */")

    insert_exceptions = """\t\t73358CBA2F901C8300DFA772 /* Exceptions for "SadieMarieNotifications" folder in "SadieMarieNotifications" target */ = {
\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;
\t\t\tmembershipExceptions = (
\t\t\t\tInfo.plist,
\t\t\t\tSadieMarieNotifications.entitlements,
\t\t\t);
\t\t\ttarget = 73358CAE2F901C8300DFA772 /* SadieMarieNotifications */;
\t\t};
"""
    text = text.replace("/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */", insert_exceptions + "/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */")

    insert_root = """\t\t73358CB02F901C8300DFA772 /* SadieMarieNotifications */ = {
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\texceptions = (
\t\t\t\t73358CBA2F901C8300DFA772 /* Exceptions for "SadieMarieNotifications" folder in "SadieMarieNotifications" target */,
\t\t\t);
\t\t\tpath = SadieMarieNotifications;
\t\t\tsourceTree = "<group>";
\t\t};
"""
    text = text.replace("/* End PBXFileSystemSynchronizedRootGroup section */", insert_root + "/* End PBXFileSystemSynchronizedRootGroup section */")

    insert_frameworks = """\t\t73358CAC2F901C8300DFA772 /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
"""
    text = text.replace(
        "\t\t735A66F02F7640EF00C6ADEE /* Frameworks */ = {",
        insert_frameworks + "\t\t735A66F02F7640EF00C6ADEE /* Frameworks */ = {",
    )

    text = text.replace(
        "\t\t\tchildren = (\n"
        "\t\t\t\t73358CA42F8EDFD600DFA772 /* SadieMarieWidgetsExtensionDebug.entitlements */,\n"
        "\t\t\t\t73358CA32F8ECD9400DFA772 /* SadieMarieWidgetsExtension.entitlements */,\n",
        "\t\t\tchildren = (\n"
        "\t\t\t\t73358CC22F901C8300DFA772 /* SadieMarieNotificationsExtensionDebug.entitlements */,\n"
        "\t\t\t\t73358CC12F901C8300DFA772 /* SadieMarieNotificationsExtension.entitlements */,\n"
        "\t\t\t\t73358CA42F8EDFD600DFA772 /* SadieMarieWidgetsExtensionDebug.entitlements */,\n"
        "\t\t\t\t73358CA32F8ECD9400DFA772 /* SadieMarieWidgetsExtension.entitlements */,\n",
    )

    text = text.replace(
        "\t\t\t\t73358C882F8ECC5800DFA772 /* SadieMarieWidgets */,\n"
        "\t\t\t\t73358C832F8ECC5800DFA772 /* Frameworks */,\n",
        "\t\t\t\t73358C882F8ECC5800DFA772 /* SadieMarieWidgets */,\n"
        "\t\t\t\t73358CB02F901C8300DFA772 /* SadieMarieNotifications */,\n"
        "\t\t\t\t73358C832F8ECC5800DFA772 /* Frameworks */,\n",
    )

    text = text.replace(
        "\t\t\t\t73358C822F8ECC5800DFA772 /* SadieMarieWidgets.appex */,\n"
        "\t\t\t);\n"
        "\t\t\tname = Products;\n",
        "\t\t\t\t73358C822F8ECC5800DFA772 /* SadieMarieWidgets.appex */,\n"
        "\t\t\t\t73358CAF2F901C8300DFA772 /* SadieMarieNotifications.appex */,\n"
        "\t\t\t);\n"
        "\t\t\tname = Products;\n",
    )

    insert_target = """\t\t73358CAE2F901C8300DFA772 /* SadieMarieNotifications */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = 73358CB72F901C8300DFA772 /* Build configuration list for PBXNativeTarget "SadieMarieNotifications" */;
\t\t\tbuildPhases = (
\t\t\t\t73358CAB2F901C8300DFA772 /* Sources */,
\t\t\t\t73358CAC2F901C8300DFA772 /* Frameworks */,
\t\t\t\t73358CAD2F901C8300DFA772 /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t73358CB02F901C8300DFA772 /* SadieMarieNotifications */,
\t\t\t);
\t\t\tname = SadieMarieNotifications;
\t\t\tpackageProductDependencies = (
\t\t\t);
\t\t\tproductName = SadieMarieNotifications;
\t\t\tproductReference = 73358CAF2F901C8300DFA772 /* SadieMarieNotifications.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t};
"""
    text = text.replace(
        "\t\t735A66F22F7640EF00C6ADEE /* SadieMarie */ = {",
        insert_target + "\t\t735A66F22F7640EF00C6ADEE /* SadieMarie */ = {",
    )

    text = text.replace(
        "\t\t\tdependencies = (\n"
        "\t\t\t\t73358C952F8ECC5A00DFA772 /* PBXTargetDependency */,\n"
        "\t\t\t);\n",
        "\t\t\tdependencies = (\n"
        "\t\t\t\t73358C952F8ECC5A00DFA772 /* PBXTargetDependency */,\n"
        "\t\t\t\t73358CB52F901C8300DFA772 /* PBXTargetDependency */,\n"
        "\t\t\t);\n",
    )

    text = text.replace(
        "\t\t\t\t73358C812F8ECC5800DFA772 = {\n"
        "\t\t\t\t\tCreatedOnToolsVersion = 26.3;\n"
        "\t\t\t\t};\n"
        "\t\t\t\t735A66F22F7640EF00C6ADEE = {",
        "\t\t\t\t73358C812F8ECC5800DFA772 = {\n"
        "\t\t\t\t\tCreatedOnToolsVersion = 26.3;\n"
        "\t\t\t\t};\n"
        "\t\t\t\t73358CAE2F901C8300DFA772 = {\n"
        "\t\t\t\t\tCreatedOnToolsVersion = 26.3;\n"
        "\t\t\t\t};\n"
        "\t\t\t\t735A66F22F7640EF00C6ADEE = {",
    )

    text = text.replace(
        "\t\t\t\t73358C812F8ECC5800DFA772 /* SadieMarieWidgets */,\n"
        "\t\t\t);\n"
        "\t\t};\n"
        "/* End PBXProject section */",
        "\t\t\t\t73358C812F8ECC5800DFA772 /* SadieMarieWidgets */,\n"
        "\t\t\t\t73358CAE2F901C8300DFA772 /* SadieMarieNotifications */,\n"
        "\t\t\t);\n"
        "\t\t};\n"
        "/* End PBXProject section */",
    )

    insert_resources = """\t\t73358CAD2F901C8300DFA772 /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
"""
    text = text.replace("/* Begin PBXResourcesBuildPhase section */", "/* Begin PBXResourcesBuildPhase section */\n" + insert_resources)

    insert_sources = """\t\t73358CAB2F901C8300DFA772 /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
"""
    text = text.replace("/* Begin PBXSourcesBuildPhase section */", "/* Begin PBXSourcesBuildPhase section */\n" + insert_sources)

    insert_dep = """\t\t73358CB52F901C8300DFA772 /* PBXTargetDependency */ = {
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = 73358CAE2F901C8300DFA772 /* SadieMarieNotifications */;
\t\t\ttargetProxy = 73358CB42F901C8300DFA772 /* PBXContainerItemProxy */;
\t\t};
"""
    text = text.replace("/* Begin PBXTargetDependency section */", "/* Begin PBXTargetDependency section */\n" + insert_dep)

    insert_build_configs = """\t\t73358CB82F901C8300DFA772 /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tCODE_SIGN_ENTITLEMENTS = SadieMarieNotificationsExtensionDebug.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 7;
\t\t\t\tDEVELOPMENT_TEAM = F54JWSP8S3;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = SadieMarieNotifications/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "Sadie Marie Notifications";
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.6;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.lj-buchmiller.SadieMarie.dev.SadieMarieNotifications";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSTRING_CATALOG_GENERATE_SYMBOLS = YES;
\t\t\t\tSWIFT_APPROACHABLE_CONCURRENCY = YES;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t73358CB92F901C8300DFA772 /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tCODE_SIGN_ENTITLEMENTS = SadieMarieNotificationsExtension.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 7;
\t\t\t\tDEVELOPMENT_TEAM = F54JWSP8S3;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = SadieMarieNotifications/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "Sadie Marie Notifications";
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.6;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.lj-buchmiller.SadieMarie.SadieMarieNotifications";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSTRING_CATALOG_GENERATE_SYMBOLS = YES;
\t\t\t\tSWIFT_APPROACHABLE_CONCURRENCY = YES;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = Release;
\t\t};
"""
    text = text.replace("/* End XCBuildConfiguration section */", insert_build_configs + "/* End XCBuildConfiguration section */")

    insert_config_list = """\t\t73358CB72F901C8300DFA772 /* Build configuration list for PBXNativeTarget "SadieMarieNotifications" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t73358CB82F901C8300DFA772 /* Debug */,
\t\t\t\t73358CB92F901C8300DFA772 /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
"""
    text = text.replace("/* End XCConfigurationList section */", insert_config_list + "/* End XCConfigurationList section */")

    if text.count("{") != text.count("}"):
        print(f"ERROR: unbalanced braces {text.count('{')} vs {text.count('}')}")
        return 1

    PBX.write_text(text, encoding="utf-8")
    print(f"Added SadieMarieNotifications target to {PBX}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

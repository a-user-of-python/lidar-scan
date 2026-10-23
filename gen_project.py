#!/usr/bin/env python3
"""Generates LiDARScan.xcodeproj/project.pbxproj. Run from ~/workspace/lidar-scan/."""
import hashlib, os

def uuid(name: str) -> str:
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()

APP = "LiDARScan"
FILES = ["LiDARScanApp.swift", "ContentView.swift", "LiDARScanner.swift", "STLWriter.swift"]
ASSETS = "Assets.xcassets"

# ---- UUIDs ----
proj_uuid = uuid("proj")
target_uuid = uuid("target")
app_ref = uuid("app_ref")
infoplist_ref = uuid("infoplist")
group_main = uuid("group_main")
group_products = uuid("group_products")
group_root = uuid("group_root")
src_phase = uuid("src_phase")
res_phase = uuid("res_phase")
fw_phase = uuid("fw_phase")
proj_config_list = uuid("proj_config_list")
tgt_config_list = uuid("tgt_config_list")
proj_debug = uuid("proj_debug")
proj_release = uuid("proj_release")
tgt_debug = uuid("tgt_debug")
tgt_release = uuid("tgt_release")

file_refs = {f: uuid("fileref_" + f) for f in FILES}
build_files = {f: uuid("buildfile_" + f) for f in FILES}
assets_ref = uuid("fileref_assets")
assets_build = uuid("buildfile_assets")

def pbx_build_file(f):
    return f"\t\t{build_files[f]} = {{isa = PBXBuildFile; fileRef = {file_refs[f]}; }};"

def pbx_file_ref(f):
    return f"\t\t{file_refs[f]} = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = \"<group>\"; }};"

objects = []

# PBXBuildFile
for f in FILES:
    objects.append(pbx_build_file(f))
objects.append(f'\t\t{assets_build} = {{isa = PBXBuildFile; fileRef = {assets_ref}; }};')

# PBXFileReference
for f in FILES:
    objects.append(pbx_file_ref(f))
objects.append(f'\t\t{assets_ref} = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {ASSETS}; sourceTree = "<group>"; }};')
objects.append(f'\t\t{app_ref} = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP}.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
objects.append(f'\t\t{infoplist_ref} = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')

# PBXGroup
objects.append(f'''\t\t{group_root} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{group_main},
\t\t\t\t{group_products},
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};''')
objects.append(f'''\t\t{group_main} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(chr(9)*4 + file_refs[f] + "," for f in FILES)}
\t\t\t\t{infoplist_ref},
\t\t\t\t{assets_ref},
\t\t\t);
\t\t\tpath = {APP};
\t\t\tsourceTree = "<group>";
\t\t}};''')
objects.append(f'''\t\t{group_products} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{app_ref},
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};''')

# PBXNativeTarget
objects.append(f'''\t\t{target_uuid} = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {tgt_config_list};
\t\t\tbuildPhases = (
\t\t\t\t{src_phase},
\t\t\t\t{fw_phase},
\t\t\t\t{res_phase},
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = {APP};
\t\t\tproductName = {APP};
\t\t\tproductReference = {app_ref};
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};''')

# PBXProject
objects.append(f'''\t\t{proj_uuid} = {{
\t\t\tisa = PBXProject;
\t\t\tbuildConfigurationList = {proj_config_list};
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {group_root};
\t\t\tproductRefGroup = {group_products};
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{target_uuid},
\t\t\t);
\t\t}};''')

# Phases
objects.append(f'''\t\t{src_phase} = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(chr(9)*4 + build_files[f] + "," for f in FILES)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};''')
objects.append(f'''\t\t{fw_phase} = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};''')
objects.append(f'''\t\t{res_phase} = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{assets_build},
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};''')

# Configurations
def xcconfig(uid, configname, settings):
    lines = [f'\t\t{uid} = {{', '\t\t\tisa = XCBuildConfiguration;']
    lines.append('\t\t\tbuildSettings = {')
    for k, v in settings.items():
        lines.append(f'\t\t\t\t{k} = {v};')
    lines.append('\t\t\t};')
    lines.append(f'\t\t\tname = {configname};')
    lines.append('\t\t};')
    return '\n'.join(lines)

proj_settings = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_TESTABILITY": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "MTL_FAST_MATH": "YES",
    "ONLY_ACTIVE_ARCH": "YES",
    "SDKROOT": "iphoneos",
    "SWIFT_VERSION": "5.0",
}
tgt_settings = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": '"LiDARScan/Info.plist"',
    "INFOPLIST_KEY_NSCameraUsageDescription": '"LiDAR 3D scanning needs camera access to build the model."',
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks"',
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.example.lidarscan",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1"',
}

objects.append(xcconfig(proj_debug, "Debug", proj_settings))
objects.append(xcconfig(proj_release, "Release", {**proj_settings, "COPY_PHASE_STRIP": "YES", "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"', "ENABLE_TESTABILITY": "NO", "ONLY_ACTIVE_ARCH": "NO"}))
objects.append(xcconfig(tgt_debug, "Debug", tgt_settings))
objects.append(xcconfig(tgt_release, "Release", {**tgt_settings, "COPY_PHASE_STRIP": "YES", "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"'}))

objects.append(f'''\t\t{proj_config_list} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{proj_debug},
\t\t\t\t{proj_release},
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};''')
objects.append(f'''\t\t{tgt_config_list} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{tgt_debug},
\t\t\t\t{tgt_release},
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};''')

pbxproj = f'''// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{
{chr(10).join(objects)}
\t}};
\trootObject = {proj_uuid};
}}
'''

os.makedirs(f"{APP}.xcodeproj", exist_ok=True)
with open(f"{APP}.xcodeproj/project.pbxproj", "w") as f:
    f.write(pbxproj)
print("Wrote LiDARScan.xcodeproj/project.pbxproj")

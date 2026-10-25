#!/usr/bin/env ruby
# Deterministic Xcode project generator; no gems or network dependencies.
require 'digest'
require 'fileutils'
require 'json'
root = File.expand_path('..', __dir__)
project = File.join(root, 'ReminderSnap.xcodeproj')
FileUtils.mkdir_p(project)
def uid(value); Digest::SHA256.hexdigest(value)[0,24].upcase; end
def quote(value); value.to_s.to_json; end
objects = {}
google_file = File.join(root, 'Resources/GoogleOAuth.json')
google_client = File.exist?(google_file) ? JSON.parse(File.read(google_file)).fetch('client_id', '') : ''
google_scheme = google_client.empty? ? 'com.nerdykevvy.ReminderSnap.oauth-unconfigured' : google_client.split('.').reverse.join('.')
add = lambda { |key, body| objects[uid(key)] = body; uid(key) }
sources = Dir.glob(File.join(root, 'Sources/ReminderSnapApp/*.swift')).sort.map { |p| p.delete_prefix(root + '/') }
sources.each { |p| add.call(p, "isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{quote(p)}; sourceTree = SOURCE_ROOT;") }
resources = {'Resources/AppIcon.icns' => 'image.icns', 'Resources/Assets.xcassets' => 'folder.assetcatalog', 'Resources/PrivacyInfo.xcprivacy' => 'text.xml'}
resources.each { |p, type| add.call(p, "isa = PBXFileReference; lastKnownFileType = #{type}; path = #{quote(p)}; sourceTree = SOURCE_ROOT;") }
package = add.call('package', 'isa = XCLocalSwiftPackageReference; relativePath = .;')
targets = []
products = []
%w[macOS iOS].each do |platform|
  name = "ReminderSnap-#{platform}"
  product = add.call("product-#{platform}", 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "ReminderSnap.app"; sourceTree = BUILT_PRODUCTS_DIR;')
  products << product
  dependency = add.call("core-#{platform}", "isa = XCSwiftPackageProductDependency; package = #{package}; productName = ReminderSnapCore;")
  framework = add.call("core-build-#{platform}", "isa = PBXBuildFile; productRef = #{dependency};")
  files = sources.map { |p| add.call("#{platform}-#{p}", "isa = PBXBuildFile; fileRef = #{uid(p)};") }
  source_phase = add.call("sources-#{platform}", "isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (#{files.join(',')},); runOnlyForDeploymentPostprocessing = 0;")
  chosen = platform == 'macOS' ? ['Resources/AppIcon.icns', 'Resources/PrivacyInfo.xcprivacy'] : ['Resources/Assets.xcassets', 'Resources/PrivacyInfo.xcprivacy']
  files = chosen.map { |p| add.call("#{platform}-#{p}", "isa = PBXBuildFile; fileRef = #{uid(p)};") }
  resource_phase = add.call("resources-#{platform}", "isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (#{files.join(',')},); runOnlyForDeploymentPostprocessing = 0;")
  framework_phase = add.call("frameworks-#{platform}", "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (#{framework},); runOnlyForDeploymentPostprocessing = 0;")
  configs = %w[Debug Release].map do |config|
    settings = {
      'PRODUCT_NAME'=>'ReminderSnap', 'EXECUTABLE_NAME'=>'ReminderSnap', 'PRODUCT_BUNDLE_IDENTIFIER'=>'com.nerdykevvy.ReminderSnap',
      'SWIFT_VERSION'=>'5.0', 'MARKETING_VERSION'=>'2.1', 'CURRENT_PROJECT_VERSION'=>'20106',
      'GOOGLE_CLIENT_ID'=>google_client, 'GOOGLE_REVERSED_CLIENT_ID'=>google_scheme,
      'CLOUDKIT_ENVIRONMENT'=>config == 'Debug' ? 'Development' : 'Production',
      'APS_ENVIRONMENT'=>config == 'Debug' ? 'development' : 'production',
      'CODE_SIGN_STYLE'=>'Automatic', 'DEVELOPMENT_TEAM'=>'Z977ASQ4T3', 'GENERATE_INFOPLIST_FILE'=>'NO', 'SWIFT_EMIT_LOC_STRINGS'=>'YES',
      'SWIFT_OPTIMIZATION_LEVEL'=>config == 'Debug' ? '-Onone' : '-O',
      'ONLY_ACTIVE_ARCH'=>config == 'Debug' ? 'YES' : 'NO',
      'ENABLE_PREVIEWS'=>'YES', 'REMINDERSNAP_PRIVACY_POLICY_URL'=>'https://github.com/NerdyKevvy/ReminderSnap-v2.0/blob/main/AppStore/PRIVACY-POLICY.md',
      'DEBUG_INFORMATION_FORMAT'=>config == 'Debug' ? 'dwarf' : 'dwarf-with-dsym',
      'LD_RUNPATH_SEARCH_PATHS'=>'$(inherited) @executable_path/Frameworks @executable_path/../Frameworks'
    }
    if platform == 'macOS'
      settings.merge!('SDKROOT'=>'macosx', 'MACOSX_DEPLOYMENT_TARGET'=>'13.0', 'INFOPLIST_FILE'=>'Resources/MacInfo.plist', 'CODE_SIGN_ENTITLEMENTS'=>'Resources/Mac.entitlements', 'ENABLE_HARDENED_RUNTIME'=>'YES', 'SUPPORTED_PLATFORMS'=>'macosx')
    else
      settings.merge!('SDKROOT'=>'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET'=>'17.0', 'INFOPLIST_FILE'=>'Resources/iOSInfo.plist', 'CODE_SIGN_ENTITLEMENTS'=>'Resources/iOS.entitlements', 'TARGETED_DEVICE_FAMILY'=>'1,2', 'SUPPORTED_PLATFORMS'=>'iphoneos iphonesimulator', 'SUPPORTS_MACCATALYST'=>'NO', 'ASSETCATALOG_COMPILER_APPICON_NAME'=>'AppIcon')
    end
    settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG' if config == 'Debug'
    add.call("#{platform}-#{config}", "isa = XCBuildConfiguration; name = #{config}; buildSettings = { #{settings.map { |k,v| "#{k} = #{quote(v)};" }.join(' ')} };")
  end
  config_list = add.call("configs-#{platform}", "isa = XCConfigurationList; buildConfigurations = (#{configs.join(',')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
  target = add.call("target-#{platform}", "isa = PBXNativeTarget; buildConfigurationList = #{config_list}; buildPhases = (#{source_phase},#{framework_phase},#{resource_phase},); buildRules = (); dependencies = (); name = #{quote(name)}; packageProductDependencies = (#{dependency},); productName = #{quote(name)}; productReference = #{product}; productType = \"com.apple.product-type.application\";")
  targets << target
  schemes = File.join(project, 'xcshareddata/xcschemes'); FileUtils.mkdir_p(schemes)
  reference = "<BuildableReference BuildableIdentifier=\"primary\" BlueprintIdentifier=\"#{target}\" BuildableName=\"ReminderSnap.app\" BlueprintName=\"#{name}\" ReferencedContainer=\"container:ReminderSnap.xcodeproj\"/>"
  File.write(File.join(schemes, "#{name}.xcscheme"), <<~XML)
    <?xml version="1.0" encoding="UTF-8"?>
    <Scheme LastUpgradeVersion="1600" version="1.3">
      <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">#{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
      <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
      <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">#{reference}</BuildableProductRunnable></LaunchAction>
      <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">#{reference}</BuildableProductRunnable></ProfileAction>
      <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
    </Scheme>
  XML
end
group = add.call('source-group', "isa = PBXGroup; children = (#{sources.map { |p| uid(p) }.join(',')},); name = App; sourceTree = \"<group>\";")
res = add.call('resource-group', "isa = PBXGroup; children = (#{resources.keys.map { |p| uid(p) }.join(',')},); name = Resources; sourceTree = \"<group>\";")
prod = add.call('product-group', "isa = PBXGroup; children = (#{products.join(',')},); name = Products; sourceTree = \"<group>\";")
main = add.call('main-group', "isa = PBXGroup; children = (#{group},#{res},#{prod},); sourceTree = \"<group>\";")
configs = %w[Debug Release].map { |c| add.call("project-#{c}", "isa = XCBuildConfiguration; name = #{c}; buildSettings = { CLANG_ENABLE_MODULES = YES; };" ) }
config_list = add.call('project-configs', "isa = XCConfigurationList; buildConfigurations = (#{configs.join(',')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
root_id = add.call('project', "isa = PBXProject; attributes = { BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = { #{targets.map { |target| "#{target} = { SystemCapabilities = { com.apple.iCloud = { enabled = 1; }; com.apple.Push = { enabled = 1; }; }; };" }.join(' ')} }; }; buildConfigurationList = #{config_list}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base, \"zh-Hans\",); mainGroup = #{main}; packageReferences = (#{package},); productRefGroup = #{prod}; projectDirPath = \"\"; projectRoot = \"\"; targets = (#{targets.join(',')},);")
File.write(File.join(project, 'project.pbxproj'), "// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n" + objects.map { |key, body| "#{key} = { #{body} };" }.join("\n") + "\n}; rootObject = #{root_id}; }\n")
puts "Generated #{project}"

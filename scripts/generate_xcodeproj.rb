#!/usr/bin/env ruby

require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'CodexAccountHub.xcodeproj')
APP_DIR = File.join(ROOT, 'CodexAccountHub')
TEST_DIR = File.join(ROOT, 'CodexAccountHubTests')

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes['LastSwiftUpdateCheck'] = '2620'
project.root_object.attributes['LastUpgradeCheck'] = '2620'

app_target = project.new_target(:application, 'CodexAccountHub', :osx, '14.0')
test_target = project.new_target(:unit_test_bundle, 'CodexAccountHubTests', :osx, '14.0')
test_target.add_dependency(app_target)

app_group = project.main_group.find_subpath('CodexAccountHub', true)
test_group = project.main_group.find_subpath('CodexAccountHubTests', true)

Dir.glob(File.join(APP_DIR, '**', '*.swift')).sort.each do |path|
    file_ref = app_group.new_file(path.sub("#{ROOT}/", ''))
    app_target.add_file_references([file_ref])
end

Dir.glob(File.join(APP_DIR, '**', '*.xcassets')).sort.each do |path|
    file_ref = app_group.new_file(path.sub("#{ROOT}/", ''))
    app_target.add_resources([file_ref])
end

Dir.glob(File.join(TEST_DIR, '**', '*.swift')).sort.each do |path|
    file_ref = test_group.new_file(path.sub("#{ROOT}/", ''))
    test_target.add_file_references([file_ref])
end

local_package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
local_package.relative_path = 'Packages/CodexAuthCore'
project.root_object.package_references << local_package

def add_package_dependency(project, target, package_reference, product_name)
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.package = package_reference
  dependency.product_name = product_name
  target.package_product_dependencies << dependency

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  target.frameworks_build_phase.files << build_file
end

add_package_dependency(project, app_target, local_package, 'CodexAuthCore')
add_package_dependency(project, test_target, local_package, 'CodexAuthCore')

common_app_settings = {
  'SWIFT_VERSION' => '6.0',
  'PRODUCT_BUNDLE_IDENTIFIER' => 'dev.codex-account-hub',
  'PRODUCT_NAME' => 'CodexAccountHub',
  'PRODUCT_MODULE_NAME' => 'CodexAccountHub',
  'EXECUTABLE_NAME' => 'CodexAccountHub',
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'INFOPLIST_KEY_CFBundleDisplayName' => 'Codex Account Hub',
  'INFOPLIST_KEY_CFBundleShortVersionString' => '$(MARKETING_VERSION)',
  'INFOPLIST_KEY_CFBundleVersion' => '$(CURRENT_PROJECT_VERSION)',
  'INFOPLIST_KEY_LSMinimumSystemVersion' => '14.0',
  'INFOPLIST_KEY_LSUIElement' => 'YES',
  'MACOSX_DEPLOYMENT_TARGET' => '14.0',
  'ENABLE_APP_SANDBOX' => 'NO',
  'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/../Frameworks'],
  'CURRENT_PROJECT_VERSION' => '1',
  'MARKETING_VERSION' => '0.1.0',
  'SWIFT_EMIT_LOC_STRINGS' => 'NO',
  'CLANG_ENABLE_MODULES' => 'YES'
}

debug_app_settings = {
  'CODE_SIGNING_ALLOWED' => 'NO',
  'CODE_SIGNING_REQUIRED' => 'NO',
  'ENABLE_HARDENED_RUNTIME' => 'NO'
}

release_app_settings = {
  'CODE_SIGN_STYLE' => 'Manual',
  'CODE_SIGNING_ALLOWED' => 'YES',
  'CODE_SIGNING_REQUIRED' => 'YES',
  'CODE_SIGN_IDENTITY' => 'Developer ID Application',
  'ENABLE_HARDENED_RUNTIME' => 'YES'
}

app_target.build_configurations.each do |config|
  common_app_settings.each do |key, value|
    config.build_settings[key] = value
  end

  config_specific_settings = if config.name == 'Release'
    release_app_settings
  else
    debug_app_settings
  end

  config_specific_settings.each do |key, value|
    config.build_settings[key] = value
  end
end

test_target.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'dev.codex-account-hub.tests'
  config.build_settings['PRODUCT_NAME'] = 'CodexAccountHubTests'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'NO'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/CodexAccountHub.app/Contents/MacOS/CodexAccountHub'
end

app_scheme = Xcodeproj::XCScheme.new
app_scheme.configure_with_targets(app_target, test_target, launch_target: app_target)
app_scheme.save_as(PROJECT_PATH, 'CodexAccountHub', true)

test_scheme = Xcodeproj::XCScheme.new
test_scheme.configure_with_targets(test_target, test_target, launch_target: nil)
test_scheme.save_as(PROJECT_PATH, 'CodexAccountHubTests', true)

project.save

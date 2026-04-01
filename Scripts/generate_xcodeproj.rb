#!/usr/bin/env ruby
require 'xcodeproj'
require 'pathname'

ROOT = Pathname.new(__dir__).parent
PROJECT_PATH = ROOT + 'PhotoLocSyncMac.xcodeproj'

project = Xcodeproj::Project.new(PROJECT_PATH.to_s)
project.root_object.attributes['LastUpgradeCheck'] = '2600'
project.root_object.attributes['LastSwiftUpdateCheck'] = '2600'

app_target = project.new_target(:application, 'PhotoLocSyncMac', :osx, '14.0')
app_target.product_reference.name = 'PhotoLocSyncMac.app'

[project, app_target].each do |obj|
  next unless obj.respond_to?(:build_configurations)
  obj.build_configurations.each do |config|
    config.build_settings['SWIFT_VERSION'] = '6.0'
    config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
    config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  end
end

app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'dev.glacials.PhotoLocSyncMac'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = 'Configuration/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Configuration/PhotoLocSyncMac.entitlements'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'NO'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks']
  config.build_settings['PRODUCT_NAME'] = 'PhotoLocSyncMac'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
end

main_group = project.main_group
[
  'App',
  'Sources',
  'Tests',
  'Configuration',
  'Docs',
  'Scripts'
].each do |name|
  main_group.find_subpath(name, true)
end

source_paths = Dir.chdir(ROOT) { Dir.glob('{App,Sources}/**/*.swift').sort }
file_refs = source_paths.map do |relative|
  main_group.find_file_by_path(relative) || main_group.new_file(relative)
end
app_target.add_file_references(file_refs)

['Configuration/Info.plist', 'Configuration/PhotoLocSyncMac.entitlements', 'README.md'].each do |relative|
  main_group.find_file_by_path(relative) || main_group.new_file(relative)
end

project.recreate_user_schemes
Xcodeproj::XCScheme.share_scheme(project.path, 'PhotoLocSyncMac')
project.save

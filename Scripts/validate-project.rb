#!/usr/bin/env ruby
require 'json'
require 'open3'
require 'rexml/document'
root = File.expand_path('..', __dir__)
output, status = Open3.capture2('plutil', '-convert', 'json', '-o', '-', File.join(root, 'ReminderSnap.xcodeproj/project.pbxproj'))
abort 'Invalid project file' unless status.success?
project = JSON.parse(output)
objects = project.fetch('objects')
root_object = objects.fetch(project.fetch('rootObject'))
abort 'Expected two application targets' unless root_object.fetch('targets').length == 2
app_files = Dir.glob(File.join(root, 'Sources/ReminderSnapApp/*.swift')).map { |p| p.delete_prefix(root + '/') }.sort
root_object.fetch('targets').each do |id|
  target = objects.fetch(id)
  source_phase = target.fetch('buildPhases').map { |p| objects.fetch(p) }.find { |p| p['isa'] == 'PBXSourcesBuildPhase' }
  included = source_phase.fetch('files').map { |p| objects.fetch(objects.fetch(p).fetch('fileRef')).fetch('path') }.sort
  abort "Missing app sources in #{target['name']}" unless included == app_files
  target.fetch('packageProductDependencies').each do |dependency|
    abort 'Missing core dependency' unless objects.fetch(dependency).fetch('productName') == 'ReminderSnapCore'
  end
  scheme = REXML::Document.new(File.read(File.join(root, "ReminderSnap.xcodeproj/xcshareddata/xcschemes/#{target['name']}.xcscheme")))
  scheme.elements.each('//BuildableReference') { |r| abort 'Wrong scheme target' unless r.attributes['BlueprintIdentifier'] == id }
  puts "#{target['name']}: shared source membership, core dependency and scheme valid."
end
abort 'Missing iOS app icon' unless File.file?(File.join(root, 'Resources/Assets.xcassets/AppIcon.appiconset/ReminderSnapIcon.png'))
puts 'Static project validation passed. This does not compile the iOS target.'

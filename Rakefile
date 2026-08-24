# frozen_string_literal: true

Rake.add_rakelib 'tasks'

desc 'Default task to run with no specification'
task default: :spec

desc 'Build environment by loading the gem'
task :environment do
  require_relative 'lib/mootool'
end

UI_PATH = File.join(__dir__, 'data', 'ui')

namespace :ui do
  desc 'Build the GResource file'
  task :build do
    gresource_bin = File.join(UI_PATH, 'resources.bin')
    gresource_xml = File.join(UI_PATH, 'application.gresource.xml')
    system('glib-compile-resources',
           '--target', gresource_bin,
           '--sourcedir', File.dirname(gresource_xml),
           gresource_xml)
  end
end

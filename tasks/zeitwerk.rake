# frozen_string_literal: true

module MooTool
  class ZeitwerkChecker # :nodoc:
    def self.check
      Zeitwerk::Loader.eager_load_all

      autoloaded = ActiveSupport::Dependencies.autoload_paths + ActiveSupport::Dependencies.autoload_once_paths
      eager_loaded = ActiveSupport::Dependencies._eager_load_paths.to_a

      unchecked = autoloaded - eager_loaded
      unchecked.select! { |dir| Dir.exist?(dir) && !Dir.empty?(dir) }
      unchecked
    end
  end
end

report_unchecked = lambda do |unchecked|
  puts
  puts <<~ERROR
    WARNING: The following directories will only be checked if you configure
    them to be eager loaded:
  ERROR
  puts

  unchecked.each { |dir| puts "  #{dir}" }
  puts

  puts <<~ERROR
    You may verify them manually, or add them to config.eager_load_paths
    in config/application.rb and run zeitwerk:check again.
  ERROR
  puts
end

namespace :zeitwerk do
  desc 'Check project structure for Zeitwerk compatibility'
  task check: :environment do
    puts 'Hold on, I am eager loading the application.'

    begin
      unchecked = MooTool::ZeitwerkChecker.check
    rescue Zeitwerk::NameError => e
      abort e.message
    end

    if unchecked.empty?
      puts 'All is good!'
    else
      report_unchecked[unchecked]
      puts 'Otherwise, all is good!'
    end
  end
end

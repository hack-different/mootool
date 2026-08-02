# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'steep/rake_task'
require 'yard'
require 'rubocop/rake_task'

Rake.add_rakelib 'tasks'

RSpec::Core::RakeTask.new(:spec)

desc 'Default task to run with no specification'
task default: :spec

desc 'Build environment by loading the gem'
task :environment do
  require_relative 'lib/mootool'
end

YARD::Rake::YardocTask.new

RuboCop::RakeTask.new

Steep::RakeTask.new

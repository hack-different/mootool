# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'steep/rake_task'
require 'yard'
require 'rubocop/rake_task'

Rake.add_rakelib 'lib/tasks'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

task :environment do
  require_relative 'lib/mootool'
end

YARD::Rake::YardocTask.new

RuboCop::RakeTask.new

Steep::RakeTask.new

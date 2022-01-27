# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mootool/version'

Gem::Specification.new do |spec|
  spec.name          = 'mootool'
  spec.version       = MooTool::VERSION
  spec.authors       = ['Rick Mark']
  spec.email         = ['rickmark@outlook.com']

  spec.summary       = "Mach-O's Other Tool"
  spec.description   = 'mootool is a swiss army knife for dealing wiith Apple Mach-O files'
  spec.homepage      = 'https://github.com/hack-different/mootool'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'

    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/hack-different/mootool'
    spec.metadata['changelog_uri'] = 'https://github.com/hack-different/mootool'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '> 2'
  spec.add_development_dependency 'overcommit'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rake'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'sorbet'

  spec.add_runtime_dependency 'sorbet-runtime'
  spec.add_runtime_dependency 'ruby-macho'
end

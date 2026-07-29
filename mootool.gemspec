# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'moo_tool/version'

Gem::Specification.new do |spec|
  spec.name = 'moo_tool'
  spec.version = MooTool::VERSION
  spec.authors = ['Rick Mark']
  spec.email = ['rickmark@outlook.com']

  spec.summary = "Mach-O's Other Tool"
  spec.description = 'moo_tool is a swiss army knife for dealing with Apple Mach-O files'
  spec.homepage = 'https://github.com/hack-different/mootool'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 4.0'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
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
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activemodel'
  spec.add_dependency 'activesupport'
  spec.add_dependency 'amazing_print'
  spec.add_dependency 'CFPropertyList'
  spec.add_dependency 'colorize'
  spec.add_dependency 'ecies'
  spec.add_dependency 'lzfse'
  spec.add_dependency 'lzss'
  spec.add_dependency 'plist'
  spec.add_dependency 'ruby-lzma'
  spec.add_dependency 'ruby-macho'
  spec.add_dependency 'rubyzip'
  spec.add_dependency 'thor'
  spec.add_dependency 'uuidtools'

  spec.metadata['rubygems_mfa_required'] = 'true'
end

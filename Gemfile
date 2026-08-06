# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in mootool.gemspec
gemspec

gem 'jekyll'
gem 'just-the-docs'

group :jekyll_plugins do
  gem 'jekyll-feed'
  gem 'jekyll-gist'
  gem 'jekyll-github-metadata'
  gem 'jekyll-paginate'
  gem 'jekyll-remote-theme'
  gem 'jekyll-seo-tag'
  gem 'jekyll-sitemap'
end

group :development, :test do
  gem 'mdl'
  gem 'overcommit'
  gem 'pry'
  gem 'rake'
  gem 'rbs'
  gem 'rbs-inline'
  gem 'rspec'
  gem 'rubocop'
  gem 'rubocop-rake'
  gem 'rubocop-rspec'
  gem 'simplecov'
  gem 'spoom'
  gem 'steep'
  gem 'typeprof'
end

gem 'http_parser.rb', '~> 0.6.0', platforms: [:jruby]
gem 'wdm', '~> 0.1', platforms: :windows
platforms :windows, :jruby do
  gem 'tzinfo', '>= 1', '< 3'
  gem 'tzinfo-data'
end

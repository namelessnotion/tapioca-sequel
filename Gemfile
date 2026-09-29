# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rake', '~> 13.0'
gem 'rspec', '~> 3.13'
gem 'rubocop', require: false
gem 'rubocop-rspec', require: false
gem 'sqlite3', '>= 1.7'

# CI tests against each supported tapioca minor; locally, the lockfile's.
gem 'tapioca', ENV.fetch('TAPIOCA_VERSION') if ENV['TAPIOCA_VERSION']

# frozen_string_literal: true

require_relative 'lib/tapioca_sequel/version'

Gem::Specification.new do |spec|
  spec.name = 'tapioca-sequel'
  spec.version = TapiocaSequel::VERSION
  spec.authors = ['Anthony Byram']
  spec.email = ['anthony@namelessnotion.com']

  spec.summary = 'Tapioca DSL compiler that generates Sorbet RBIs for Sequel::Model classes.'
  spec.description = <<~DESC
    A Tapioca DSL compiler for Sequel models. From each model's database schema
    and association reflections it generates typed column accessors, finders,
    association methods, and a typed dataset class, so a query chain that
    starts at `Model.where` keeps returning the model all the way through.
  DESC
  spec.homepage = 'https://github.com/namelessnotion/tapioca-sequel'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'README.md', 'LICENSE.txt', 'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'sequel', '~> 5.0'
  spec.add_dependency 'tapioca', '~> 0.19'
end

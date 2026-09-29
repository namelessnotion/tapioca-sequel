# frozen_string_literal: true

require 'sequel'
require 'tapioca/internal'
require 'tapioca/helpers/test/dsl_compiler'

require_relative 'support/schema'
require_relative 'support/models'
require 'tapioca/dsl/compilers/sequel_model'
require_relative 'support/compiler_helpers'

RSpec::Matchers.define_negated_matcher :exclude, :include

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.include CompilerHelpers
end

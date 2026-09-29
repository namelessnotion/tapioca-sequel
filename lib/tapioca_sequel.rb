# typed: strict
# frozen_string_literal: true

# The compiler itself lives in lib/tapioca/dsl/compilers/, where `tapioca dsl`
# finds and loads it from every gem in the bundle; there is nothing to require
# at runtime.
require_relative 'tapioca_sequel/version'

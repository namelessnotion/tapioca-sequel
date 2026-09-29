# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc 'Run the Sorbet static type checker'
task :typecheck do
  sh 'bundle exec srb tc'
end

task default: %i[spec rubocop typecheck]

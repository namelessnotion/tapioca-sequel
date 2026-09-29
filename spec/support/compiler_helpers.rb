# frozen_string_literal: true

# One example per generated method, each pinning that method's signature, so
# a table of expected signatures reads as the RBI it describes and a failure
# names the one method that changed.
RSpec.shared_examples 'generated signatures' do |constant_name, scope, signatures|
  signatures.each do |method, signature|
    it "generates #{scope}##{method} as #{signature}" do
      expect(signatures_for(constant_name)).to include("#{scope}##{method}" => signature)
    end
  end
end

# Runs the compiler the way `tapioca dsl` does, through tapioca's own test
# context, which also syntax-checks every generated file with Sorbet.
module CompilerHelpers
  def rbi_for(constant_name)
    compiler_context.rbi_for(constant_name)
  end

  def gathered_constants
    compiler_context.gathered_constants
  end

  # Every generated method, keyed `Scope#name`, as `(param: Type, ...) -> Return`.
  # One line per method whether or not the formatter wrapped its sig, so an
  # expectation reads like the signature it pins.
  def signatures_for(constant_name)
    signatures = {}
    collect_signatures(RBI::Parser.parse_string(rbi_for(constant_name)), nil, signatures)
    signatures
  end

  private

  def compiler_context
    @compiler_context ||= Tapioca::Helpers::Test::DslCompiler::CompilerContext.new(
      Tapioca::Dsl::Compilers::SequelModel
    )
  end

  def collect_signatures(node, scope, signatures)
    case node
    when RBI::Method
      signatures["#{scope}##{node.name}"] = signature(node.sigs.fetch(0))
    when RBI::Tree
      name = node.is_a?(RBI::Module) || node.is_a?(RBI::Class) ? node.name : scope
      node.nodes.each { |child| collect_signatures(child, name, signatures) }
    end
  end

  def signature(sig)
    "(#{sig.params.map { |param| "#{param.name}: #{param.type}" }.join(', ')}) -> #{sig.return_type}"
  end
end

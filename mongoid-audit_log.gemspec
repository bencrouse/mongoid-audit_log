# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mongoid/audit_log/version'

Gem::Specification.new do |spec|
  spec.name          = "mongoid-audit_log"
  spec.version       = Mongoid::AuditLog::VERSION
  spec.authors       = ["Ben Crouse"]
  spec.email         = ["bencrouse@gmail.com"]
  spec.description   = %q{Stupid simple audit logging for Mongoid}
  spec.summary       = %q{No fancy versioning, undo, redo, etc. Just saves changes to Mongoid models in a separate collection.}
  spec.homepage      = "https://github.com/bencrouse/mongoid-audit_log"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version     = ">= 1.9.2"
  spec.required_rubygems_version = ">= 1.3.6"

  spec.add_runtime_dependency "mongoid", [">= 7.0"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
end

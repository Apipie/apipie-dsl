# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'apipie_dsl/version'

Gem::Specification.new do |spec|
  spec.name          = 'apipie-dsl'
  spec.version       = ApipieDSL::VERSION
  spec.authors       = ['Oleh Fedorenko']
  spec.email         = ['fpostoleh@gmail.com']

  spec.summary       = 'Ruby DSL documentation tool'
  spec.description   = 'Ruby DSL documentation tool'
  spec.homepage      = 'https://github.com/ofedoren/apipie-dsl'
  spec.license       = 'MIT'

  spec.files         = Dir['{app,lib,doc,test}/**/*', 'LICENSE', 'README*']
  spec.test_files    = Dir['{test}/**/*']

  spec.bindir        = 'bin'
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.3.0'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'json-schema'
  spec.add_development_dependency 'maruku'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rdoc'
  spec.add_development_dependency 'RedCloth'
  spec.add_development_dependency 'actionview'
end

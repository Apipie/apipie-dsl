# frozen_string_literal: true

require 'apipie_dsl/version'
require 'apipie_dsl/errors'
require 'apipie_dsl/markup'
require 'apipie_dsl/configuration'
require 'apipie_dsl/apipie_dsl_module'
require 'apipie_dsl/see_description'
require 'apipie_dsl/tag_list_description'
require 'apipie_dsl/exception_description'
require 'apipie_dsl/parameter_description'
require 'apipie_dsl/method_description'
require 'apipie_dsl/class_description'
require 'apipie_dsl/dsl'
require 'apipie_dsl/return_description'
require 'apipie_dsl/validator'

module ApipieDSL
  require 'fileutils'
  require 'apipie_dsl/railtie' if defined?(Rails)

  def self.root
    File.dirname(__dir__)
  end
end

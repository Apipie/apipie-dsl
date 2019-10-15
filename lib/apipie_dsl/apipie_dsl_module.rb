# frozen_string_literal: true

require 'apipie_dsl/utils'
require 'apipie_dsl/application'

module ApipieDSL
  extend ApipieDSL::Utils

  def self.app
    @app ||= ApipieDSL::Application.new
  end

  def self.configure
    yield configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.docs(version = nil, class_name = nil, method_name = nil, lang = nil, section = nil)
    version ||= configuration.default_version
    section ||= configuration.default_section
    app.docs(version, class_name, method_name, lang, section)
  end

  def self.debug(message)
    puts message if configuration.debug
  end

  # All calls delegated to ApipieDSL::Application instance
  def self.method_missing(method, *args, &block)
    app.respond_to?(method) ? app.send(method, *args, &block) : super
  end

  def self.app_info(version = nil, lang = nil)
    info = if app_info_version_valid?(version)
             translate(configuration.app_info[version], lang)
           elsif app_info_version_valid?(configuration.default_version)
             translate(configuration.app_info[configuration.default_version], lang)
           else
             'Another DSL description'
           end

    ApipieDSL.markup_to_html(info)
  end

  def self.dsl_base_url(version = nil)
    if dsl_base_url_version_valid?(version)
      configuration.dsl_base_url[version]
    elsif dsl_base_url_version_valid?(configuration.default_version)
      configuration.dsl_base_url[configuration.default_version]
    else
      '/dsl'
    end
  end

  def self.app_info_version_valid?(version)
    version && configuration.app_info.key?(version)
  end

  def self.dsl_base_url_version_valid?(version)
    version && configuration.dsl_base_url.key?(version)
  end
end

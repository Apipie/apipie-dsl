# frozen_string_literal: true

module ApipieDSL
  class Application
    if defined? Rails
      require 'apipie_dsl/static_dispatcher'

      class Engine < Rails::Engine
        initializer 'static assets', :before => :build_middleware_stack do |app|
          app.middleware.use ::ApipieDSL::StaticDispatcher, "#{root}/app/public"
        end
      end
    end
    attr_reader :class_descriptions, :refs

    def initialize
      initialize_environment
    end

    def available_versions
      @class_descriptions.keys.sort
    end

    def set_class_versions(klass, versions)
      @class_versions[klass.to_s] = versions
    end

    def class_versions(klass)
      ret = @class_versions[klass.to_s]
      return ret unless ret.empty?
      return [ApipieDSL.configuration.default_version] if [Class, Module].include?(klass) || klass.nil?

      class_versions(ApipieDSL.superclass_for(klass))
    end

    def get_class_name(klass)
      class_name = klass.respond_to?(:name) ? klass.name : klass
      raise ArgumentError, "ApipieDSL: Can not resolve class #{klass} name." unless class_name.is_a?(String)
      return class_name if ApipieDSL.configuration.class_full_names?

      class_name.split('::').last
    end

    def define_param_group(klass, name, &block)
      key = "#{klass.name}##{name}"
      @param_groups[key] = block
    end

    def get_param_group(klass, name)
      key = "#{klass.name}##{name}"
      raise StandardError, "Param group #{key} is not defined" unless @param_groups.key?(key)

      @param_groups[key]
    end

    def define_method_description(klass, method_name, dsl_data)
      return if ignored?(klass, method_name)

      ret_method_description = nil
      versions = dsl_data[:dsl_versions] || []
      versions = class_versions(klass) if versions.empty?

      versions.each do |version|
        class_name_with_version = "#{version}##{get_class_name(klass)}"
        class_description = get_class_description(class_name_with_version)

        if class_description.nil?
          class_dsl_data = { sections: [ApipieDSL.configuration.default_section] }
          class_description = define_class_description(klass, version, class_dsl_data)
        end

        method_description = ApipieDSL::MethodDescription.new(method_name, class_description, dsl_data)

        # Create separate method description for each version in
        # case the method belongs to more versions. Return just one
        # because the version doesn't matter for the purpose it's used
        # (to wrap the original version with validators)
        ret_method_description ||= method_description
        class_description.add_method_description(method_description)
      end

      ret_method_description
    end

    def define_class_description(klass, version, dsl_data = {})
      return if ignored?(klass)

      class_name = dsl_data[:class_name] || get_class_name(klass)
      class_description = @class_descriptions[version][class_name]
      if class_description
        # Already defined the class somewhere (probably in
        # some method. Updating just meta data from dsl
        class_description.update_from_dsl_data(dsl_data) unless dsl_data.empty?
      else
        class_description = ApipieDSL::ClassDescription.new(klass, class_name, dsl_data, version)
        ApipieDSL.debug("@class_descriptions[#{version}][#{class_name}] = #{class_description}")
        @class_descriptions[version][class_description.id] ||= class_description
      end
      class_description.refs.each do |ref|
        if @refs[version][ref]
          ApipieDSL.debug("Overwriting refs for #{class_name}")
        end

        @refs[version][ref] = class_description
      end
      class_description
    end

    # get method
    #
    # There are two ways how this method can be used:
    # 1) Specify both parameters
    #   class_name:
    #       class - IO
    #       string with resource name and version - "v1#io"
    #   method_name: name of the method (string or symbol)
    #
    # 2) Specify only first parameter:
    #   class_name: string containing both class and method name joined
    #   with '#' symbol.
    #   - "io#puts" get default version
    #   - "v2#io#puts" get specific version
    def get_method_description(class_name, method_name = nil)
      ApipieDSL.debug("Getting #{class_name}##{method_name} documentation")
      crumbs = class_name.split('#')
      method_name = crumbs.pop if method_name.nil?
      class_name = crumbs.join('#')
      class_description = get_class_description(class_name)
      raise ArgumentError, "Class #{class_name} does not exists." if class_description.nil?

      class_description.method_description(method_name.to_sym)
    end

    # options:
    # => "io"
    # => "v2#io"
    # =>  V2::IO
    def get_class_description(klass, version = nil)
      return nil if [NilClass, nil].include?(klass)

      if klass.is_a?(String)
        crumbs = klass.split('#')
        version = crumbs.first if crumbs.size == 2
        version ||= ApipieDSL.configuration.default_version
        return @class_descriptions[version][crumbs.last] if @class_descriptions.key?(version)
      else
        class_name = get_class_name(klass)
        class_name = "#{version}##{class_name}" if version
        return nil if class_name.nil?

        class_description = get_class_description(class_name)
        return class_description if class_description && class_description.klass.to_s == klass.to_s
      end
    end

    # get all versions of class description
    def get_class_descriptions(klass)
      available_versions.map do |version|
        get_class_description(klass, version)
      end.compact
    end

    # get all versions of method description
    def get_method_descriptions(klass, method)
      get_class_descriptions(klass).map do |class_description|
        class_description.method_description(method.to_sym)
      end.compact
    end

    def remove_method_description(klass, versions, method_name)
      versions.each do |version|
        klass = get_class_name(klass)
        if (class_description = class_description("#{version}##{klass}"))
          class_description.remove_method_description(method_name)
        end
      end
    end

    def docs(version, class_name, method_name, lang, section = nil)
      empty_doc = empty_docs(version, lang)
      return empty_doc unless valid_search_args?(version, class_name, method_name)

      classes =
        if class_name.nil?
          class_descriptions[version].each_with_object({}) do |(name, description), result|
            result[name] = description.docs(section, nil, lang)
            result
          end
        else
          [@class_descriptions[version][class_name].docs(section, method_name, lang)]
        end
      empty_doc[:docs][:classes] = classes
      empty_doc
    end

    def dsl_classes_paths
      ApipieDSL.configuration.dsl_classes_matchers.map { |m| Dir.glob(m) }
               .concat(Dir.glob(ApipieDSL.configuration.dsl_classes_matcher))
               .flatten.uniq
    end

    def translate(str, locale)
      if ApipieDSL.configuration.translate
        ApipieDSL.configuration.translate.call(str, locale)
      else
        str
      end
    end

    def ignored?(klass, method = nil)
      ignored = ApipieDSL.configuration.ignored
      class_name = get_class_name(klass.name)
      return true if ignored.include?(class_name)
      return true if ignored.include?("#{class_name}##{method}")
    end

    def reload_documentation
      # don't load translated strings, we'll translate them later
      old_locale = locale
      reset_locale(ApipieDSL.configuration.default_locale)

      rails_mark_classes_for_reload if defined?(Rails)

      dsl_classes_paths.each do |file|
        begin
          ApipieDSL.debug("Loading #{file}")
          if defined?(Rails)
            load_class_from_file(file)
          else
            load(file)
          end
        rescue StandardError
          # Some constant the file uses may not be defined
          # before it's loaded
          # TODO: better loading
        end
      end

      reset_locale(old_locale)
    end

    def load_documentation
      return if @documentation_loaded && !ApipieDSL.configuration.reload_dsl?

      ApipieDSL.reload_documentation
      @documentation_loaded = true
    end

    def locale
      ApipieDSL.configuration.locale.call(nil) if ApipieDSL.configuration.locale
    end

    def reset_locale(loc)
      ApipieDSL.configuration.locale.call(loc) if ApipieDSL.configuration.locale
    end

    private

    def initialize_environment
      @class_descriptions ||= Hash.new { |h, version| h[version] = {} }
      @class_versions ||= Hash.new { |h, klass| h[klass.to_s] = [] }
      @refs ||= Hash.new { |h, version| h[version] = {} }
      @param_groups ||= {}
    end

    def empty_docs(version, lang)
      url_args = ApipieDSL.configuration.version_in_url ? version : ''
      {
        docs: {
          name: ApipieDSL.configuration.app_name,
          info: ApipieDSL.app_info(version, lang),
          copyright: ApipieDSL.configuration.copyright,
          doc_url: ApipieDSL.full_url(url_args),
          classes: {}
        }
      }
    end

    def load_class_from_file(class_file)
      require_dependency class_file
    end

    # Since Rails 3.2, the classes are reloaded only on file change.
    # We need to reload all the classes to rebuild the
    # docs, therefore we just force to reload all the code.
    def rails_mark_classes_for_reload
      unless Rails.application.config.cache_classes
        Rails::VERSION::MAJOR == 4 ? ActionDispatch::Reloader.cleanup! : Rails.application.reloader.reload!
        initialize_environment
        Rails::VERSION::MAJOR == 4 ? ActionDispatch::Reloader.prepare! : Rails.application.reloader.prepare!
      end
    end

    def valid_search_args?(version, class_name, method_name)
      return false unless class_descriptions.key?(version)

      if class_name
        return false unless class_descriptions[version].key?(class_name)

        if method_name
          class_description = class_descriptions[version][class_name]
          return false unless class_description.valid_method_name?(method_name)
        end
      end
      true
    end
  end
end

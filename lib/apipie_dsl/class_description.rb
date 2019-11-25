# frozen_string_literal: true

module ApipieDSL
  class ClassDescription
    attr_reader :klass, :short_description, :full_description, :methods,
                :deprecated, :show, :refs, :sections

    def initialize(klass, class_name, dsl_data = nil, version = nil)
      @klass = klass
      @name = class_name
      @methods = {}
      @properties = []
      @version = version || ApipieDSL.configuration.default_version
      @parent = ApipieDSL.get_class_description(ApipieDSL.superclass_for(klass), version)
      @refs = []
      @sections = []
      @show = true
      update_from_dsl_data(dsl_data) if dsl_data
    end

    def update_from_dsl_data(dsl_data)
      @name = dsl_data[:class_name] if dsl_data[:class_name]
      @full_description = ApipieDSL.markup_to_html(dsl_data[:description])
      @short_description = dsl_data[:short_description]
      @tag_list = dsl_data[:tag_list]
      @metadata = dsl_data[:meta]
      @deprecated = dsl_data[:deprecated] || false
      @show = dsl_data[:show] || @show
      @properties = (dsl_data[:properties] || []).map do |args|
        ApipieDSL::MethodDescription.from_dsl_data(self, args)
      end
      @refs = dsl_data[:refs] || [@name]
      @sections = dsl_data[:sections] || @sections
      return unless dsl_data[:app_info]

      ApipieDSL.configuration.app_info[version] = dsl_data[:app_info]
    end

    def id
      return @klass.name if ApipieDSL.configuration.class_full_names?

      @name
    end

    def version
      @version || @parent.try(:version) || ApipieDSL.configuration.default_version
    end

    def add_method_description(method_description)
      ApipieDSL.debug "@resource_descriptions[#{version}][#{@name}].methods[#{method_description.name}] = #{method_description}"
      @methods[method_description.name.to_sym] = method_description
    end

    def method_description(method_name)
      @methods[method_name.to_sym]
    end

    def remove_method_description(method_name)
      return unless @methods.key?(method_name)

      @methods.delete(method_name)
    end

    def method_descriptions
      @methods.values
    end

    def property_descriptions
      @properties
    end

    def doc_url(section = nil)
      crumbs = []
      crumbs << version if ApipieDSL.configuration.version_in_url
      crumbs << section if section
      crumbs << id
      ApipieDSL.full_url(crumbs.join('/'))
    end

    def valid_method_name?(method_name)
      @methods.keys.map(&:to_s).include?(method_name.to_s)
    end

    def docs(section = nil, method_name = nil, lang = nil)
      raise "Method #{method_name} not found for class #{id}" if method_name && !valid_method_name?(method_name)

      methods = if method_name.nil?
                  @methods.map { |_key, method_desc| method_desc.docs(section, lang) }
                else
                  [@methods[method_name.to_sym].docs(section, lang)]
                end
      {
        id: id,
        name: @name,
        doc_url: doc_url(section),
        short_description: ApipieDSL.translate(@short_description, lang),
        full_description: ApipieDSL.translate(@full_description, lang),
        version: version,
        metadata: @metadata,
        properties: @properties.map { |prop_desc| prop_desc.docs(section, lang) },
        methods: methods,
        deprecated: @deprecated,
        show: @show
      }
    end
  end
end

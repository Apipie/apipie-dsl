# frozen_string_literal: true

module ApipieDSL
  class ClassDescription
    attr_reader :klass, :short_description, :full_description, :methods,
                :deprecated, :show

    def initialize(klass, class_name, dsl_data = nil, version = nil)
      @klass = klass
      @name = class_name
      @methods = {}
      @properties = []
      @version = version || ApipieDSL.configuration.default_version
      @parent = ApipieDSL.get_class_description(ApipieDSL.superclass_for(klass), version)
      update_from_dsl_data(dsl_data) if dsl_data
    end

    def update_from_dsl_data(dsl_data)
      @name = dsl_data[:class_name] if dsl_data[:class_name]
      @full_description = ApipieDSL.markup_to_html(dsl_data[:description])
      @short_description = dsl_data[:short_description]
      @tag_list = dsl_data[:tag_list]
      @metadata = dsl_data[:meta]
      @dsl_base_url = dsl_data[:dsl_base_url]
      @deprecated = dsl_data[:deprecated] || false
      @show = dsl_data[:show]
      @properties = dsl_data[:properties].map do |args|
        ApipieDSL::ParameterDescription.from_dsl_data(self, args)
      end
      return unless dsl_data[:app_info]

      ApipieDSL.configuration.app_info[version] = dsl_data[:app_info]
    end

    def id
      return @klass.name if ApipieDSL.configuration.class_full_names?

      @klass.name.split('::').last
    end

    def version
      @version || @parent.try(:version) || ApipieDSL.configuration.default_version
    end

    def dsl_base_url
      @dsl_base_url || @parent.try(:dsl_base_url) || ApipieDSL.dsl_base_url(version)
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
      @properties.select(&:validator)
    end

    def doc_url
      crumbs = []
      crumbs << version if ApipieDSL.configuration.version_in_url
      crumbs << id
      ApipieDSL.full_url(crumbs.join('/'))
    end

    def dsl_url
      "#{ApipieDSL.dsl_base_url(version)}#{@path}"
    end

    def valid_method_name?(method_name)
      @methods.keys.map(&:to_s).include?(method_name.to_s)
    end

    def to_hash(method_name = nil, lang = nil)
      raise "Method #{method_name} not found for class #{_name}" if method_name && !valid_method_name?(method_name)

      methods = if method_name.nil?
                  @methods.map { |_key, method_description| method_description.to_hash(lang) }
                else
                  [@methods[method_name.to_sym].to_hash(lang)]
                end
      {
        doc_url: doc_url,
        dsl_url: dsl_url,
        name: @name,
        short_description: ApipieDSL.translate(@short_description, lang),
        full_description: ApipieDSL.translate(@full_description, lang),
        version: version,
        metadata: @metadata,
        properties: property_descriptions.map { |prop| prop.to_hash(lang) }.flatten,
        methods: methods,
        deprecated: @deprecated,
        show: @show
      }
    end
  end
end

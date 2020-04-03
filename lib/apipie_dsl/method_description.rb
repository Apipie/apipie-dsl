# frozen_string_literal: true

module ApipieDSL
  class MethodDescription
    attr_reader :name, :klass, :see, :examples, :signature
    attr_accessor :full_description, :short_description, :metadata, :show,
                  :raises, :returns, :aliases
    alias_method :class_description, :klass

    def self.from_dsl_data(klass, args)
      name, dsl_data = args
      ApipieDSL::MethodDescription.new(name, klass, dsl_data)
    end

    def initialize(name, klass, dsl_data)
      @name = name.to_s
      @klass = klass

      desc = dsl_data[:description] || ''
      @full_description = ApipieDSL.markup_to_html(desc)

      @short_description = dsl_data[:short_description] || ''

      @params = (dsl_data[:params] || []).map do |args|
        ApipieDSL::ParameterDescription.from_dsl_data(self, args)
      end

      @params = ApipieDSL::ParameterDescription.unify(@params)

      @raises = (dsl_data[:raises] || []).map do |args|
        ApipieDSL::ExceptionDescription.from_dsl_data(args)
      end

      # Every method in Ruby returns an onject
      dsl_data[:returns] = [{ object_of: Object }] if dsl_data[:returns].nil?

      @returns = ApipieDSL::ReturnDescription.from_dsl_data(self, dsl_data[:returns])

      @tag_list = dsl_data[:tag_list]

      @see = (dsl_data[:see] || []).map do |method, options|
        options[:scope] ||= @klass
        ApipieDSL::SeeDescription.new(method, options)
      end

      @metadata = dsl_data[:meta]

      @show = dsl_data[:show].nil? ? true : dsl_data[:show]

      @examples = (dsl_data[:examples] || []).select do |example|
        next example if example[:for].nil?

        example[:for].to_s == @name
      end

      @aliases = dsl_data[:aliases]

      @signature = dsl_data[:signature]
    end

    def id
      "#{klass.id}##{name}"
    end

    def plain_params
      @params
    end

    def params
      param_descriptions.each_with_object({}) { |p, h| h[p.name] = p }
                        .sort.to_h
    end

    def param_descriptions
      @params.select(&:validator)
    end

    def tag_list
      parent = ApipieDSL.get_class_description(ApipieDSL.superclass_for(@klass.class))
      parent_tags = [parent, @klass].compact.flat_map(&:tag_list_arg)
      ApipieDSL::TagListDescription.new((parent_tags + @tag_list).uniq.compact)
    end

    def version
      klass.version
    end

    def doc_url(section = nil)
      crumbs = []
      crumbs << @klass.version if ApipieDSL.configuration.version_in_url
      crumbs << section if section
      crumbs << @klass.id
      crumbs << @name
      ApipieDSL.full_url(crumbs.join('/')).gsub('?', '%3F')
    end

    def docs(section = nil, lang = nil)
      {
        doc_url: doc_url(section),
        name: @name,
        full_description: ApipieDSL.translate(@full_description, lang),
        short_description: ApipieDSL.translate(@short_description, lang),
        params: param_descriptions.map { |param| param.docs(lang) }.flatten,
        raises: raises.map(&:docs),
        returns: @returns.docs(lang),
        metadata: @metadata,
        see: see.map(&:docs),
        show: @show,
        examples: @examples,
        aliases: aliases,
        signature: signature
      }
    end
  end
end

# frozen_string_literal: true

module ApipieDSL
  class MethodDescription
    attr_reader :name, :klass, :see, :examples
    attr_accessor :full_description, :short_description, :metadata, :show,
                  :raises, :returns
    alias_method :class_description, :klass

    def initialize(name, klass, dsl_data)
      @name = name.to_s
      @klass = klass

      desc = dsl_data[:description] || ''
      @full_description = ApipieDSL.markup_to_html(desc)

      @short_description = dsl_data[:short_description] || ''

      @params = dsl_data[:params].map do |args|
        ApipieDSL::ParameterDescription.from_dsl_data(self, args)
      end

      @params = ApipieDSL::ParameterDescription.unify(@params)

      @raises = dsl_data[:raises].map do |args|
        ApipieDSL::ExceptionDescription.from_dsl_data(args)
      end

      # Every method in Ruby returns an onject
      dsl_data[:returns] = [{ object_of: Object }] if dsl_data[:returns].nil?

      @returns = ApipieDSL::ReturnDescription.from_dsl_data(self, dsl_data[:returns])

      @tag_list = dsl_data[:tag_list]

      @see = dsl_data[:see].map do |args|
        ApipieDSL::SeeDescription.new(args)
      end

      @metadata = dsl_data[:meta]

      @show = dsl_data[:show]

      @examples = dsl_data[:examples]
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

    def doc_url
      crumbs = []
      crumbs << @klass.version if ApipieDSL.configuration.version_in_url
      crumbs << @klass.id
      crumbs << @name
      ApipieDSL.full_url(crumbs.join('/')).gsub('?', '%3F')
    end

    def to_hash(lang = nil)
      {
        doc_url: doc_url,
        name: @name,
        full_description: ApipieDSL.translate(@full_description, lang),
        short_description: ApipieDSL.translate(@short_description, lang),
        params: param_descriptions.map { |param| param.to_hash(lang) }.flatten,
        raises: raises.map(&:to_hash),
        returns: @returns.to_hash(lang),
        metadata: @metadata,
        see: see.map(&:to_hash),
        show: @show,
        examples: @examples
      }
    end
  end
end

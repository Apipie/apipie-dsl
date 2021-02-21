# frozen_string_literal: true

module ApipieDSL
  # method parameter description
  #
  # name - method name (show)
  # desc - description
  # validator - Validator::BaseValidator subclass
  class ParameterDescription
    attr_reader :name, :desc, :type, :options, :method_description,
                :metadata, :show, :is_array, :default_value
    attr_accessor :parent

    alias_method :is_array?, :is_array

    def self.from_dsl_data(method_description, args)
      name, validator, desc_or_options, options, block = args
      ApipieDSL::ParameterDescription.new(method_description,
                                          name,
                                          validator,
                                          desc_or_options,
                                          options,
                                          &block)
    end

    def ==(other)
      return false unless self.class == other.class

      if method_description == other.method_description && @options == other.options
        true
      else
        false
      end
    end

    def initialize(method_description, name, validator, desc_or_options = nil, options = {}, &block)
      if desc_or_options.is_a?(Hash)
        options = options.merge(desc_or_options)
      elsif desc_or_options.is_a?(String)
        options[:desc] = desc_or_options
      elsif !desc_or_options.nil?
        raise ArgumentError, 'Parameter description: expected description or options as 3rd parameter'
      end

      @options = options.transform_keys(&:to_sym)

      @method_description = method_description
      @name = name
      @desc = @options[:desc]
      @type = @options[:type] || :required
      @schema = @options[:schema]
      @default_value = @options[:default]
      @parent = @options[:parent]
      @metadata = @options[:meta]
      @show = @options.key?(:show) ? @options[:show] : true

      return unless validator

      @validator = if validator.is_a?(String)
        ApipieDSL::Validator::Lazy.new(self, validator, @options, block)
      else
        ApipieDSL::Validator::BaseValidator.find(self, validator, @options, block)
      end
      raise StandardError, "Validator for #{validator} not found." unless @validator
    end

    def validator
      return @validator unless @validator.is_a?(ApipieDSL::Validator::Lazy)

      @validator = @validator.build
    end

    def validate(value)
      validator.valid?(value)
    end

    def full_name
      name_parts = parents_and_self.map { |p| p.name if p.show }.compact
      return name.to_s if name_parts.empty?

      ([name_parts.first] + name_parts[1..-1].map { |n| "[#{n}]" }).join('')
    end

    # Returns an array of all the parents: starting with the root parent
    # ending with itself
    def parents_and_self
      ret = []
      ret.concat(parent.parents_and_self) if parent
      ret << self
      ret
    end

    def merge_with(other_param_desc)
      if validator && other_param_desc.validator
        validator.merge_with(other_param_desc.validator)
      else
        self.validator ||= other_param_desc.validator
      end
      self
    end

    # Merge param descriptions. Allows defining hash params on more places
    # (e.g. in param_groups). For example:
    #
    #     def_param_group :user do
    #       param :user, Hash do
    #         param :name, String
    #       end
    #     end
    #
    #     param_group :user
    #     param :user, Hash do
    #       param :password, String
    #     end
    def self.unify(params)
      ordering = params.map(&:name)
      params.group_by(&:name).map do |_name, description|
        description.reduce(&:merge_with)
      end.sort_by { |param| ordering.index(param.name) }
    end

    def self.merge(target_params, source_params)
      params_to_merge, params_to_add = source_params.partition do |source_param|
        target_params.any? { |target_param| source_param.name == target_param.name }
      end
      unify(target_params + params_to_merge)
      target_params.concat(params_to_add)
    end

    def docs(lang = nil)
      hash = {
        name: name.to_s,
        full_name: full_name,
        description: ApipieDSL.markup_to_html(ApipieDSL.translate(@options[:desc], lang)),
        type: type.to_s,
        default: default_value,
        validator: validator.to_s,
        expected_type: validator.expected_type,
        metadata: metadata,
        show: show
      }
      hash.delete(:default) if type == :required
      hash[:schema] = @schema if type == :block
      return hash unless validator.sub_params

      hash[:params] = validator.sub_params.map { |param| param.docs(lang) }
      hash
    end
  end
end

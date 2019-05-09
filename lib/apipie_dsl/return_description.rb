# frozen_string_literal: true

module ApipieDSL
  class ReturnDescription
    class ReturnObject
      include ApipieDSL::Base
      include ApipieDSL::Parameter

      def initialize(method_description, scope, return_type, block)
        @method_description = method_description
        @scope = scope
        @param_group = { scope: scope }

        if block
          instance_exec(&block)
        elsif !return_type.is_a?(Symbol)
          class_description = ApipieDSL.get_class_description(return_type)
          @params_ordered = class_description&.property_descriptions
        end
      end

      # this routine overrides Param#default_param_group_scope
      # and is called if Param#param_group is invoked
      # during the instance_exec call in ReturnObject#initialize
      def default_param_group_scope
        @scope
      end

      def params_ordered
        @params_ordered ||= dsl_data[:params].map do |args|
          options = args.find { |arg| arg.is_a? Hash }
          options[:param_group] = @param_group
          ApipieDSL::ParameterDescription.from_dsl_data(@method_description, args)
        end.compact
      end

      def to_hash(lang = nil)
        params_ordered.map { |param| param.to_hash(lang) }
      end
    end
  end

  class ReturnDescription
    def self.from_dsl_data(method_description, args)
      options, block = args

      new(method_description, options, block)
    end

    def initialize(method_description, options, block)
      @return_type = options[:param_group] || options[:object_of]
      @array_of = options[:array_of] || false
      raise ReturnsMultipleDefinitionError, options if @array_of && @return_type

      @return_type ||= @array_of
      @description = options[:desc]

      @returns_object = ReturnObject.new(method_description, options[:scope], @return_type, block)
    end

    def array?
      @array_of != false
    end

    def params_ordered
      @returns_object.params_ordered
    end

    def to_hash(lang = nil)
      hash = {
        description: @description,
        array: array?,
        object: {
          class: ApipieDSL.get_class_name(@return_type),
          properties: @returns_object.to_hash(lang)
        }
      }
      hash[:object].delete(:class) if @return_type.is_a?(Symbol)
      hash
    end
  end
end

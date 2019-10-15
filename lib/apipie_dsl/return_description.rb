# frozen_string_literal: true

module ApipieDSL
  class ReturnDescription
    class ReturnObject
      include ApipieDSL::Base
      include ApipieDSL::Parameter

      def initialize(method_description, options, block)
        @method_description = method_description
        @scope = options[:scope]
        @param_group = { scope: @scope }
        @options = options
        @return_type = (@options.keys & %i[array_of one_of object_of param_group]).first

        return unless @options[@return_type].is_a?(::Class)

        if block && (@options[@return_type] == Hash)
          instance_exec(&block)
        else
          class_description = ApipieDSL.get_class_description(@options[@return_type])
          @params_ordered = if class_description.nil?
                              []
                            else
                              class_description.property_descriptions
                            end
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

      def return_class
        case @return_type
        when :object_of
          @options[@return_type]
        when :one_of, :param_group
          Object
        when :array_of
          Array
        end
      end

      def return_data(lang = nil)
        if %i[one_of array_of].include?(@return_type)
          @options[@return_type]
        else
          data = params_ordered.map { |param| param.docs(lang) }
          data.empty? ? nil : data
        end
      end

      def docs(lang = nil)
        {
          meta: @return_type,
          class: return_class,
          data: return_data(lang)
        }
      end
    end
  end

  class ReturnDescription
    def self.from_dsl_data(method_description, args)
      options, block = args

      new(method_description, options, block)
    end

    def initialize(method_description, options, block)
      if options[:array_of] && options[:one_of] && options[:object_of] && options[:param_group]
        raise ReturnsMultipleDefinitionError, options
      end

      @description = options[:desc]
      @returns_object = ReturnObject.new(method_description, options, block)
    end

    def params_ordered
      @returns_object.params_ordered
    end

    def docs(lang = nil)
      {
        description: @description,
        object: @returns_object.docs(lang)
      }
    end
  end
end

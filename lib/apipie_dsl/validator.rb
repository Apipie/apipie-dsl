# frozen_string_literal: true

module ApipieDSL
  module Validator
    class Lazy
      def initialize(param_description, argument, options, block)
        @param_description = param_description
        @argument = argument
        @options = options
        @block = block
      end

      def build
        # TODO support for plain Ruby
        return unless defined? Rails

        BaseValidator.find(@param_description, @argument.constantize, @options, @block)
      end
    end
    # To create a new validator, inherit from ApipieDSL::Validator::BaseValidator
    # and implement class method 'build' and instance method 'validate'
    class BaseValidator
      attr_reader :param_description

      def initialize(param_description)
        @param_description = param_description
      end

      def self.build(_param_description, _argument, _options, &_block)
        raise NotImplementedError
      end

      def validate(_value)
        raise NotImplementedError
      end

      def description
        raise NotImplementedError
      end

      def inspected_fields
        [:param_description]
      end

      def inspect
        string = "#<#{self.class.name}:#{object_id} "
        fields = inspected_fields.map { |field| "#{field}: #{send(field)}" }
        string << fields.join(', ') << '>'
      end

      def self.inherited(subclass)
        @validators ||= []
        @validators.unshift(subclass)
      end

      def self.find(param_description, argument, options, block)
        @validators.each do |type|
          validator = type.build(param_description, argument, options, block)
          return validator if validator
        end
        nil
      end

      def valid?(value)
        return true if validate(value)

        raise ParamInvalid.new(@param_description.name, value, description)
      end

      def to_s
        description
      end

      def docs
        raise NotImplementedError
      end

      def expected_type
        'string'
      end

      def sub_params
        nil
      end

      def merge_with(other_validator)
        return self if self == other_validator

        raise NotImplementedError, "Don't know how to merge #{inspect} with #{other_validator.inspect}"
      end

      def ==(other)
        return false unless self.class == other.class

        param_description == other.param_description
      end
    end

    class TypeValidator < BaseValidator
      def initialize(param_description, argument)
        super(param_description)
        @type = argument
      end

      def self.build(param_description, argument, _options, block)
        return unless argument.is_a?(::Class)
        return if argument == Hash && !block.nil?

        new(param_description, argument)
      end

      def validate(value)
        return false if value.nil?

        value.is_a?(@type)
      end

      def description
        "Must be a #{@type}"
      end

      def expected_type
        if @type.ancestors.include?(Hash)
          'hash'
        elsif @type.ancestors.include?(Array)
          'array'
        elsif @type.ancestors.include?(Numeric)
          'numeric'
        else
          'string'
        end
      end
    end

    class RegexpValidator < BaseValidator
      def initialize(param_description, argument)
        super(param_description)
        @regexp = argument
      end

      def self.build(param_description, argument, _options, _block)
        new(param_description, argument) if argument.is_a?(Regexp)
      end

      def validate(value)
        value =~ @regexp
      end

      def description
        "Must match regular expression <code>/#{@regexp.source}/</code>."
      end

      def expected_type
        'regexp'
      end
    end

    # Arguments value must be one of given in array
    class EnumValidator < BaseValidator
      def initialize(param_description, argument)
        super(param_description)
        @array = argument
      end

      def self.build(param_description, argument, _options, _block)
        new(param_description, argument) if argument.is_a?(Array)
      end

      def validate(value)
        @array.include?(value)
      end

      def values
        @array
      end

      def description
        string = @array.map { |value| "<code>#{value}</code>" }.join(', ')
        "Must be one of: #{string}."
      end
    end

    class ArrayValidator < BaseValidator
      def initialize(param_description, argument, options = {})
        super(param_description)
        @type = argument
        @items_type = options[:of]
        @items_enum = options[:in]
      end

      def self.build(param_description, argument, options, block)
        return if argument != Array || block.is_a?(Proc)

        new(param_description, argument, options)
      end

      def validate(values)
        return false unless process_value(values).respond_to?(:each) &&
                            !process_value(values).is_a?(String)

        process_value(values).all? { |v| validate_item(v) }
      end

      def process_value(values)
        values || []
      end

      def description
        "Must be an array of #{items_type}"
      end

      def expected_type
        'array'
      end

      private

      def validate_item(value)
        valid_type?(value) && valid_value?(value)
      end

      def valid_type?(value)
        return true unless @items_type

        item_validator = BaseValidator.find(nil, @items_type, nil, nil)

        if item_validator
          item_validator.valid?(value)
        else
          value.is_a?(@items_type)
        end
      end

      def items_enum
        @items_enum = Array(@items_enum.call) if @items_enum.is_a?(Proc)
        @items_enum
      end

      def valid_value?(value)
        if items_enum
          items_enum.include?(value)
        else
          true
        end
      end

      def items_type
        return items_enum.inspect if items_enum

        @items_type || 'any type'
      end
    end

    class ArrayClassValidator < BaseValidator
      def initialize(param_description, argument)
        super(param_description)
        @array = argument
      end

      def validate(value)
        @array.include?(value.class)
      end

      def self.build(param_description, argument, _options, block)
        return if !argument.is_a?(Array) || argument.first.class != ::Class || block.is_a?(Proc)

        new(param_description, argument)
      end

      def description
        "Must be one of: #{@array.join(', ')}."
      end
    end

    class ProcValidator < BaseValidator
      def initialize(param_description, argument)
        super(param_description)
        @proc = argument
      end

      def validate(value)
        # The proc should return true if value is valid
        # Otherwise it should return a string
        !(@help = @proc.call(value)).is_a?(String)
      end

      def self.build(param_description, argument, _options, _block)
        return if !argument.is_a?(Proc) || argument.arity != 1

        new(param_description, argument)
      end

      def description
        @help
      end
    end

    class HashValidator < BaseValidator
      include ApipieDSL::Base
      include ApipieDSL::Parameter
      include ApipieDSL::Klass

      def initialize(param_description, argument, param_group)
        super(param_description)
        @param_group = param_group
        instance_exec(&argument)
        prepare_hash_params
      end

      def self.build(param_description, argument, options, block)
        return if argument != Hash || !block.is_a?(Proc) || block.arity.positive?

        new(param_description, block, options[:param_group])
      end

      def sub_params
        @sub_params ||= dsl_data[:params].map do |args|
          options = args.find { |arg| arg.is_a?(Hash) }
          options[:parent] = param_description
          ApipieDSL::ParameterDescription.from_dsl_data(param_description.method_description, args)
        end
      end

      def validate(value)
        return false unless value.is_a?(Hash)

        @hash_params&.each do |name, param|
          if ApipieDSL.configuration.validate_value?
            param.validate(value[name]) if value.key?(name)
          end
        end
        true
      end

      def description
        'Must be a Hash'
      end

      def expected_type
        'hash'
      end

      def default_param_group_scope
        @param_group && @param_group[:scope]
      end

      def merge_with(other_validator)
        if other_validator.is_a?(HashValidator)
          @sub_params = ApipieDSL::ParameterDescription.unify(sub_params + other_validator.sub_params)
          prepare_hash_params
        else
          super
        end
      end

      private

      def prepare_hash_params
        @hash_params = sub_params.each_with_object({}) do |param, hash|
          hash.update(param.name.to_sym => param)
        end
      end
    end

    class DecimalValidator < BaseValidator
      def self.build(param_description, argument, _options, _block)
        return if argument != :decimal

        new(param_description)
      end

      def validate(value)
        value.to_s =~ /\A^[-+]?[0-9]+([,.][0-9]+)?\Z$/
      end

      def description
        'Must be a decimal number'
      end
    end

    class NumberValidator < BaseValidator
      def self.build(param_description, argument, _options, _block)
        return if argument != :number

        new(param_description)
      end

      def validate(value)
        value.to_s =~ /\A(0|[1-9]\d*)\Z$/
      end

      def description
        'Must be a number'
      end

      def expected_type
        'numeric'
      end
    end

    class BooleanValidator < BaseValidator
      def self.build(param_description, argument, _options, _block)
        return unless %i[bool boolean].include?(argument)

        new(param_description)
      end

      def validate(value)
        %w[true false 1 0].include?(value.to_s)
      end

      def description
        string = %w[true false 1 0].map { |value| "<code>#{value}</code>" }.join(', ')
        "Must be one of: #{string}"
      end

      def expected_type
        'boolean'
      end
    end

    class RestValidator < BaseValidator
      def self.build(param_description, argument, _options, _block)
        return unless %i[rest list splat].include?(argument)

        new(param_description)
      end

      def validate(_value)
        # In *rest param we don't care about passed values.
        true
      end

      def description
        'Must be a list of values'
      end

      def expected_type
        'list'
      end
    end

    class NestedValidator < BaseValidator
      def initialize(param_description, argument, param_group)
        super(param_description)
        @validator = HashValidator.new(param_description, argument, param_group)
        @type = argument
      end

      def self.build(param_description, argument, options, block)
        return if argument != Array || !block.is_a?(Proc) || block.arity.positive?

        new(param_description, block, options[:param_group])
      end

      def validate(value)
        value ||= []
        return false if value.class != Array

        value.each do |child|
          return false unless @validator.validate(child)
        end
        true
      end

      def expected_type
        'array'
      end

      def description
        'Must be an Array of nested elements'
      end

      def sub_params
        @validator.sub_params
      end
    end
  end
end

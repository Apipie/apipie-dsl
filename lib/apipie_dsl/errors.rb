# frozen_string_literal: true

module ApipieDSL
  class Error < StandardError; end
  class ParamError < Error
    attr_accessor :param

    def initialize(param)
      @param = param
    end
  end

  class ParamMissing < ParamError
    def to_s
      return "Missing parameter #{@param.name}" if @param.options[:missing_message].nil?

      if @param.options[:missing_message].is_a?(Proc)
        @param.options[:missing_message].call
      else
        @param.options[:missing_message].to_s
      end
    end
  end

  class UnknownParam < ParamError
    def to_s
      "Unknown parameter #{@param}"
    end
  end

  class ParamInvalid < ParamError
    attr_accessor :value, :error

    def initialize(param, value, error)
      super(param)
      @value = value
      @error = error
    end

    def to_s
      "Invalid parameter '#{@param}' value #{@value.inspect}: #{@error}"
    end
  end

  class MultipleDefinitionError < Error
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def to_s
      "Multiple definition of #{@value}"
    end
  end

  class ReturnsMultipleDefinitionError < Error
    def to_s
      "A 'returns' statement cannot indicate both array_of and type"
    end
  end

  class MultipleReturnsError < Error
    def to_s
      "A 'returns' statement cannot be used more than once"
    end
  end

  class ConfigurationError < Error
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def to_s
      "Configuration error: #{@value}"
    end
  end
end

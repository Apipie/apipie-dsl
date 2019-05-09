# frozen_string_literal: true

module ApipieDSL
  class ExceptionDescription
    attr_reader :error, :description, :metadata

    def self.from_dsl_data(args)
      error_or_options, desc, options = args
      ApipieDSL::ExceptionDescription.new(error_or_options, desc, options)
    end

    def initialize(error_or_options, desc = nil, options = {})
      if error_or_options.is_a?(Hash)
        error_or_options.transform_keys!(&:to_sym)
        @error = error_or_options[:error]
        @metadata = error_or_options[:meta]
        @description = error_or_options[:desc] || error_or_options[:description]
      else
        @error = if error_or_options.is_a?(Symbol)
                   Rack::Utils::SYMBOL_TO_STATUS_CODE[error_or_options]
                 else
                   error_or_options
                 end
        raise ArgumentError, error_or_options unless @error

        @metadata = options[:meta]
        @description = desc
      end
    end

    def to_hash
      {
        error: error,
        description: description,
        metadata: metadata
      }
    end
  end
end

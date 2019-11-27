# frozen_string_literal: true

module ApipieDSL
  class SeeDescription
    attr_reader :link, :description

    def initialize(method, options = {})
      @method = method
      @link = options[:link]
      @description = options[:desc] || options[:description]
      @scope = options[:scope]
    end

    def docs
      { link: link, url: see_url, description: description }
    end

    private

    def see_url
      method_description = if @scope
        if @scope.is_a?(ApipieDSL::ClassDescription)
          @scope.method_description(@method)
        else
          ApipieDSL.get_method_description(@scope.to_s, @method)
        end
      else
        ApipieDSL.get_method_description(@method)
      end
      raise ArgumentError, "Method #{@method} referenced in 'see' does not exist." if method_description.nil?

      method_description.doc_url(method_description.klass.sections.first)
    end
  end
end

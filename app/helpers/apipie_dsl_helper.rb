# frozen_string_literal: true

module ApipieDSLHelper
  include ActionView::Helpers::TagHelper

  def heading(title, level = 1)
    content_tag("h#{level}") do
      title
    end
  end

  def escaped_method_name(method, escaping = '')
    return method.gsub('?', escaping) if method.is_a?(String)
  end

  def method_signature(method_desc)
    params = method_desc[:params].map do |param|
      case param[:type]
      when 'required'
        param[:name]
      when 'optional'
        "#{param[:name]} = #{param[:default] || 'nil'}"
      when 'keyword'
        "#{param[:name]}: #{param[:default]}"
      end
    end
    "#{method_desc[:name]}(#{params.join(', ')})"
  end
end

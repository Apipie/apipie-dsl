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

  def resolve_default(default)
    case default
    when nil
      'nil'
    when ''
      "\"\""
    else
      default
    end
  end

  def method_signature(method_desc)
    params = method_desc[:params].map do |param|
      default = resolve_default(param[:default])
      case param[:type]
      when 'required'
        param[:name]
      when 'optional'
        "#{param[:name]} = #{default}"
      when 'keyword'
        "#{param[:name]}: #{default}"
      end
    end
    return "#{method_desc[:name]}" if params.empty?

    "#{method_desc[:name]}(#{params.join(', ')})"
  end

  def reference_for(obj, version, link_extension)
    return obj.to_s unless [::Module, ::Class].include?(obj.class)

    referenced = ApipieDSL.app.refs[version][ApipieDSL.app.get_class_name(obj)]
    return obj.to_s if referenced.nil?

    "<a href='" + referenced.doc_url + link_extension + "'>#{obj.to_s.html_safe}</a>"
  end
end

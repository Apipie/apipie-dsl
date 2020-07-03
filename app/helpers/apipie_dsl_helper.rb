# frozen_string_literal: true

require 'apipie_dsl/tasks_utils'

module ApipieDslHelper
  require 'action_view' unless defined?(ActionView)
  include ActionView::Helpers::TagHelper

  def heading(title, level = 1)
    content_tag("h#{level}") do
      title
    end
  end

  def escaped_method_name(method, escaping = '')
    return method.gsub('?', escaping) if method.is_a?(String)
  end

  def apipie_dsl_example(source, output = nil)
    text = content_tag(:p, _('Example input:')) +
      content_tag(:pre, source)

    if output.present?
      text += content_tag(:p, _('Example output:')) +
        content_tag(:pre, output)
    end

    text.html_safe
  end

  def apipie_erb_wrap(content, mode: :loud, open_trim: false, close_trim: false)
    case mode
    when :loud
      '<%= ' + content + " #{close_trim ? '-' : ''}%>"
    when :comment
      '<%# ' + content + " #{close_trim ? '-' : ''}%>"
    else
      "<%#{open_trim ? '- ' : ' '}" + content + " #{close_trim ? '-' : ''}%>"
    end
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
    return "#{method_desc[:name]}" if method_desc[:params].empty?

    params = method_desc[:params].map do |param|
      default = resolve_default(param[:default])
      case param[:type]
      when 'required'
        param[:name].to_s
      when 'optional'
        if param[:expected_type] == 'list'
          "*#{param[:name]}"
        else
          "#{param[:name]} = #{default}"
        end
      when 'keyword'
        "#{param[:name]}: #{default}"
      end
    end.compact.join(', ')

    block_param = method_desc[:params].find { |p| p[:type] == 'block' }

    signature_parts = [method_desc[:name]]
    signature_parts << "(#{params})" unless params.empty?
    signature_parts << " #{block_param[:schema]}" if block_param
    signature_parts.join
  end

  def class_references(obj, version, link_extension)
    # Try to convert to a constant in case of LazyValidator usage
    # Will raise const missing exception in case of wrong usage of the method
    if obj.is_a?(String)
      ref = ApipieDSL.refs[version][ApipieDSL.get_class_name(obj)]
      return "<a href='#{ref.doc_url(ref.sections.first)}#{link_extension}'>#{obj}</a>" if ref

      obj = ApipieDSL.configuration.rails? ? obj.constantize : obj.split('::').reduce(::Module, :const_get)
    end
    return obj.to_s unless [::Module, ::Class, ::Array].include?(obj.class)

    refs = [obj].flatten.map do |o|
      next o unless [::Module, ::Class].include?(o.class)

      referenced = ApipieDSL.refs[version][ApipieDSL.get_class_name(o)]
      next o if referenced.nil?

      "<a href='#{referenced.doc_url(referenced.sections.first)}#{link_extension}'>#{o}</a>"
    end
    return refs.first if refs.size < 2

    refs
  end

  def dsl_sections
    ApipieDSL.configuration.sections
  end

  def in_section?(section, klass)
    ApipieDslHelper.in_section?(section, klass)
  end

  def self.in_section?(section, klass)
    class_desc = ApipieDSL.get_class_description(klass)
    raise ApipieDSL::Error, "Cannot find #{klass} description" if class_desc.nil?
    return true if section.empty?

    class_desc.sections.include?(section)
  end

  def section_ext(section)
    "/#{section}"
  end

  def current_version(classes)
    if classes.is_a?(Array)
      classes.first[:version]
    elsif classes.is_a?(Hash)
      classes.values.first[:version]
    else
      raise ApipieDSL::Error, "Cannot find current version for #{classes}"
    end
  end

  def render_help
    render template: ApipieDSL.configuration.help_layout
  end
end

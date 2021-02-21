# rubocop:disable Style/FrozenStringLiteralComment
module ApipieDSL
  module Utils
    attr_accessor :url_prefix

    def superclass_for(klass_or_module)
      return klass_or_module.superclass if klass_or_module.respond_to?(:superclass)

      parent_name = to_s.split('::')[-2]
      return nil if parent_name.nil?

      Module.const_get(parent_name)
    end

    def markup_to_html(text)
      return '' if text.nil?

      if ApipieDSL.configuration.markup.respond_to?(:to_html)
        ApipieDSL.configuration.markup.to_html(text)
      else
        text
      end
    end

    def request_script_name
      Thread.current[:apipie_dsl_req_script_name] || ''
    end

    def request_script_name=(script_name)
      Thread.current[:apipie_dsl_req_script_name] = script_name
    end

    def full_url(path)
      unless @url_prefix
        @url_prefix = request_script_name.to_s
        @url_prefix << ApipieDSL.configuration.doc_base_url
      end
      path = path.sub(%r{^/}, '')
      ret = "#{@url_prefix}/#{path}"
      ret.insert(0, '/') unless ret =~ %r{\A[./]}
      ret.sub!(%r{/*\Z}, '')
      ret
    end

    def include_javascripts
      %w[bundled/jquery.js
         bundled/bootstrap-collapse.js
         bundled/prettify.js
         apipie_dsl.js ].map do |file|
        "<script type='text/javascript' src='#{ApipieDSL.full_url("javascripts/#{file}")}'></script>"
      end.join("\n").html_safe
    end

    def include_stylesheets
      %w[bundled/bootstrap.min.css
         bundled/prettify.css
         bundled/bootstrap-responsive.min.css ].map do |file|
        "<link type='text/css' rel='stylesheet' href='#{ApipieDSL.full_url("stylesheets/#{file}")}'/>"
      end.join("\n").html_safe
    end
  end
end

if defined? Rails
  class Module
    # https://github.com/rails/rails/pull/35035
    def as_json(options = nil)
      name
    end
  end
end
# rubocop:enable Style/FrozenStringLiteralComment

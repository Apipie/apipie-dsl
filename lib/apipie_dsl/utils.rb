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
      Thread.current[:apipie_req_script_name] || ''
    end

    def request_script_name=(script_name)
      Thread.current[:apipie_req_script_name] = script_name
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
  end
end
if RUBY_VERSION < '2.5.0'
  class Hash
    def transform_keys
      result = {}
      each do |key, value|
        new_key = yield key
        result[new_key] = value
      end
      result
    end
  end
end
# rubocop:enable Style/FrozenStringLiteralComment

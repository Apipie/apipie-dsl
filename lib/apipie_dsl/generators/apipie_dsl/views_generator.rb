# frozen_string_literal: true

module ApipieDSL
  class ViewsGenerator < ::Rails::Generators::Base
    source_root File.expand_path('../../../app/views', __dir__)
    desc 'Copy ApipieDSL views to your application'

    def copy_views
      directory 'apipie_dsl', 'app/views/apipie_dsl'
      directory 'layouts/apipie_dsl', 'app/views/layouts/apipie_dsl'
    end
  end
end

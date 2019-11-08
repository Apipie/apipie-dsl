# frozen_string_literal: true

module ApipieDSL
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)
    namespace 'apipie_dsl:install'
    class_option(:route,
                 aliases: '-r',
                 type: :string,
                 desc: 'What path should be the doc available on',
                 default: '/apipie-dsl')

    def create_initializer
      template 'initializer.rb.erb', 'config/initializers/apipie_dsl.rb'
    end

    def add_route
      route('apipie_dsl')
    end
  end
end

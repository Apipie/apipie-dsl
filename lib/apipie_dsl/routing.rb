# frozen_string_literal: true

module ApipieDSL
  module Routing
    module MapperExtensions
      def apipie_dsl(options = {})
        namespace 'apipie_dsl', path: ApipieDSL.configuration.doc_base_url do
          constraints(version: /[^\/]+/, section: /[^\/]+/, class: /[^\/]+/,
                      method: /[^\/]+/) do
            get(options.reverse_merge("(:version)/(:section)/(:class)/(:method)" => 'apipie_dsls#index', as: :apipie_dsl))
          end
        end
      end
    end
  end
end

ActionDispatch::Routing::Mapper.send :include, ApipieDSL::Routing::MapperExtensions

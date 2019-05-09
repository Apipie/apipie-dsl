# frozen_string_literal: true

require 'apipie-dsl'
require 'rails'

module ApipieDSL
  class Railtie < Rails::Railtie
    railtie_name :apipie_dsl

    rake_tasks do
      path = File.expand_path(__dir__)
      Dir.glob("#{path}/tasks/**/*.rake").each { |f| load f }
    end
  end
end

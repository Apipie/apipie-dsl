# frozen_string_literal: true

require_relative '../../tasks_utils'

namespace :apipie_dsl do
  desc 'Generate static documentation json'
  if defined?(Rails)
    task static_json: :environment do |_task, args|
      ApipieDSL::TasksUtils.with_loaded_documentation do
        args.with_defaults(version: ApipieDSL.configuration.default_version)
        out = ENV['OUT'] || File.join(::Rails.root, ApipieDSL.configuration.doc_path, 'dsldoc')
        ([nil] + ApipieDSL.configuration.languages).each do |lang|
          doc = ApipieDSL.docs(args[:version], nil, nil, lang)
          ApipieDSL::TasksUtils.generate_json_page(out, doc, lang)
        end
      end
    end
  else
    task :static_json do |_task, args|
      ApipieDSL.reload_documentation
      args.with_defaults(version: ApipieDSL.configuration.default_version)
      out = ENV['OUT'] || File.join(Rake.original_dir, ApipieDSL.configuration.doc_path, 'dsldoc')
      ([nil] + ApipieDSL.configuration.languages).each do |lang|
        doc = ApipieDSL.docs(args[:version], nil, nil, lang)
        ApipieDSL::TasksUtils.generate_json_page(out, doc, lang)
      end
    end
  end
end

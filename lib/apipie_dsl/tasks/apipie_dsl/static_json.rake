# frozen_string_literal: true

require 'json'

namespace :apipie_dsl do
  desc 'Generate static documentation json'
  if defined?(Rails)
    task static_json: :environment do |_task, args|
      args.with_defaults(version: ApipieDSL.configuration.default_version)
      out = ENV['OUT'] || File.join(Rake.original_dir, ApipieDSL.configuration.doc_path, 'dsldoc')
      ([nil] + ApipieDSL.configuration.languages).each do |lang|
        doc = ApipieDSL.docs(args[:version], nil, nil, lang)
        generate_json_page(out, doc, lang)
      end
    end
  else
    task :static_json do |_task, args|
      with_loaded_documentation do
        args.with_defaults(version: ApipieDSL.configuration.default_version)
        out = ENV['OUT'] || File.join(Rake.original_dir, ApipieDSL.configuration.doc_path, 'dsldoc')
        ([nil] + ApipieDSL.configuration.languages).each do |lang|
          doc = ApipieDSL.docs(args[:version], nil, nil, lang)
          generate_json_page(out, doc, lang)
        end
      end
    end
  end

  def with_loaded_documentation
    # Apipie.configuration.use_cache = false # we don't want to skip DSL evaluation
    ApipieDSL.reload_documentation
    yield
  end

  def generate_json_page(file_base, doc, lang = nil)
    FileUtils.mkdir_p(file_base) unless File.exist?(file_base)

    filename = "schema_apipie_dsl#{lang}.json"
    File.open("#{file_base}/#{filename}", 'w') { |file| file.write(JSON.pretty_generate(doc)) }
  end
end

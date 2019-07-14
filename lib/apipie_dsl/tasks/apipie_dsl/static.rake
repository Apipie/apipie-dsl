# frozen_string_literal: true

require_relative '../../tasks_utils'

namespace :apipie_dsl do
  desc 'Generate static documentation'
  if defined?(Rails)
    task static: :environment do |_task, args|
      args.with_defaults(version: ApipieDSL.configuration.default_version)
      out = ENV['OUT'] || File.join(::Rails.root, ApipieDSL.configuration.doc_path, 'dsldoc')
      subdir = File.basename(out)
      ApipieDSL::TasksUtils.copy_jscss(out)
      ApipieDSL.configuration.version_in_url = false
      ([nil] + ApipieDSL.configuration.languages).each do |lang|
        I18n.locale = lang || ApipieDSL.configuration.default_locale
        ApipieDSL.url_prefix = "./#{subdir}"
        doc = ApipieDSL.docs(args[:version], nil, nil, lang)
        doc[:docs][:link_extension] = "#{lang_ext(lang)}.html"
        ApipieDSL::TasksUtils.generate_one_page(out, doc, lang)
        ApipieDSL::TasksUtils.generate_plain_page(out, doc, lang)
        ApipieDSL::TasksUtils.generate_index_page(out, doc, false, false, lang)
        ApipieDSL.url_prefix = "../#{subdir}"
        ApipieDSL::TasksUtils.generate_class_pages(args[:version], out, doc, false, lang)
        ApipieDSL.url_prefix = "../../#{subdir}"
        ApipieDSL::TasksUtils.generate_method_pages(args[:version], out, doc, false, lang)
      end
    end
  end
end

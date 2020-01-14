# frozen_string_literal: true

require_relative '../../tasks_utils'

namespace :apipie_dsl do
  desc 'Generate cache to avoid production dependencies on markup languages'
  task :cache => :environment do
    puts "#{Time.now} | Started"
    ApipieDSL::TasksUtils.with_loaded_documentation do
      puts "#{Time.now} | Documents loaded..."
      ([nil] + ApipieDSL.configuration.languages).each do |lang|
        I18n.locale = lang || ApipieDSL.configuration.default_locale
        puts "#{Time.now} | Processing docs for #{lang}"
        cache_dir = ENV['OUT'] || ApipieDSL.configuration.cache_dir
        file_base = File.join(cache_dir, ApipieDSL.configuration.doc_base_url)
        subdir = File.basename(file_base)
        ApipieDSL.available_versions.each do |version|
          file_base_version = File.join(file_base, version)
          ApipieDSL.configuration.sections.each do |section|
            ApipieDSL.url_prefix = "../../#{subdir}"
            doc = ApipieDSL.docs(version, nil, nil, lang, section)
            doc[:docs][:link_extension] = "#{lang_ext(lang)}.html"
            ApipieDSL::TasksUtils.generate_index_page(file_base_version, doc, true, true, lang, section)
            ApipieDSL.url_prefix = "../../../#{subdir}"
            section_out = "#{file_base_version}/#{section}"
            ApipieDSL::TasksUtils.generate_class_pages(version, section_out, doc, true, lang)
            ApipieDSL.url_prefix = "../../../../#{subdir}"
            ApipieDSL::TasksUtils.generate_method_pages(version, section_out, doc, true, lang)
          end
          ApipieDSL.url_prefix = "../../#{subdir}"
          doc = ApipieDSL.docs(version, nil, nil, lang)
          doc[:docs][:link_extension] = "#{lang_ext(lang)}.html"
          ApipieDSL::TasksUtils.generate_help_page(file_base_version, doc, true, lang)
        end
      end
    end
    puts "#{Time.now} | Finished"
  end
end

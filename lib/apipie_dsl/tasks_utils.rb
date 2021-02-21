# frozen_string_literal: true

require 'json'
require_relative '../../app/helpers/apipie_dsl_helper'

module ApipieDSL
  module TasksUtils
    def self.generate_json_page(file_base, doc, lang = nil)
      FileUtils.mkdir_p(file_base) unless File.exist?(file_base)

      filename = "schema_apipie_dsl#{lang_ext(lang)}.json"
      File.open("#{file_base}/#{filename}", 'w') { |file| file.write(JSON.pretty_generate(doc)) }
    end

    def self.renderer
      return @renderer if @renderer

      base_paths = [File.expand_path('../../app/views/apipie_dsl/apipie_dsls', __dir__)]
      if ApipieDSL.configuration.rails?
        base_paths.unshift("#{Rails.root}/app/views") if File.directory?("#{Rails.root}/app/views")
        base_paths.unshift("#{Rails.root}/app/views/apipie_dsl/apipie_dsls") if File.directory?("#{Rails.root}/app/views/apipie_dsl/apipie_dsls")
      end
      layouts_paths = [File.expand_path('../../app/views/layouts', __dir__)]
      if ApipieDSL.configuration.rails? && File.directory?("#{Rails.root}/app/views/layouts/apipie_dsl")
        layouts_paths.unshift("#{Rails.root}/app/views/layouts")
      end
      paths = ActionView::PathSet.new(base_paths + layouts_paths)
      @renderer = ActionView::Base.new(paths, {})
      @renderer.singleton_class.send(:include, ::ApipieDslHelper)
      @renderer
    end

    def self.render_page(file_name, template, variables, layout = 'apipie_dsl')
      File.open(file_name, 'w') do |f|
        variables.each do |var, val|
          renderer.instance_variable_set("@#{var}", val)
        end
        f.write(renderer.render(template: template.to_s,
                                layout: (layout && "apipie_dsl/#{layout}")))
      end
    end

    def self.generate_one_page(file_base, doc, lang = nil)
      FileUtils.mkdir_p(File.dirname(file_base)) unless File.exist?(File.dirname(file_base))

      render_page("#{file_base}/#{File.basename(file_base)}-onepage#{lang_ext(lang)}.html", 'static',
                  doc: doc[:docs], language: lang,
                  languages: ApipieDSL.configuration.languages)
    end

    def self.generate_plain_page(file_base, doc, lang = nil)
      FileUtils.mkdir_p(File.dirname(file_base)) unless File.exist?(File.dirname(file_base))

      render_page("#{file_base}/#{File.basename(file_base)}-plain#{lang_ext(lang)}.html", 'plain',
                  { doc: doc[:docs], language: lang,
                    languages: ApipieDSL.configuration.languages }, nil)
    end

    def self.generate_index_page(file_base, doc, include_json = false, show_versions = false, lang = nil, section = nil)
      versions = show_versions && ApipieDSL.available_versions
      section_file = "#{file_base}/#{section}"
      FileUtils.mkdir_p(File.dirname(section_file)) unless File.exist?(File.dirname(section_file))
      render_page("#{section_file}#{lang_ext(lang)}.html",
      'index', doc: doc[:docs], versions: versions, language: lang,
               languages: ApipieDSL.configuration.languages, section: section)
      File.open("#{file_base}#{lang_ext(lang)}.json", 'w') { |f| f << doc.to_json } if include_json
    end

    def self.generate_class_pages(version, file_base, doc, include_json = false, lang = nil, section = nil)
      doc[:docs][:classes].each do |class_name, class_desc|
        next unless ApipieDslHelper.in_section?(section, class_name)

        class_file_base = File.join(file_base, class_desc[:id])
        FileUtils.mkdir_p(File.dirname(class_file_base)) unless File.exist?(File.dirname(class_file_base))

        doc = ApipieDSL.docs(version, class_name, nil, lang, section)
        doc[:docs][:link_extension] = (lang ? ".#{lang}.html" : '.html')
        render_page("#{class_file_base}#{lang_ext(lang)}.html", 'class',
                    doc: doc[:docs], klass: doc[:docs][:classes].first,
                    language: lang, languages: ApipieDSL.configuration.languages)
        File.open("#{class_file_base}#{lang_ext(lang)}.json", 'w') { |f| f << doc.to_json } if include_json
      end
    end

    def self.generate_method_pages(version, file_base, doc, include_json = false, lang = nil, section = nil)
      doc[:docs][:classes].each do |class_name, class_params|
        next unless ApipieDslHelper.in_section?(section, class_name)

        class_params[:methods].each do |method|
          method_file_base = File.join(file_base, class_name.to_s, method[:name].to_s)
          FileUtils.mkdir_p(File.dirname(method_file_base)) unless File.exist?(File.dirname(method_file_base))

          doc = ApipieDSL.docs(version, class_name, method[:name], lang, section)
          doc[:docs][:link_extension] = (lang ? ".#{lang}.html" : '.html')
          render_page("#{method_file_base}#{lang_ext(lang)}.html", 'method',
                      doc: doc[:docs], klass: doc[:docs][:classes].first,
                      method: doc[:docs][:classes].first[:methods].first,
                      language: lang, languages: ApipieDSL.configuration.languages)

          File.open("#{method_file_base}#{lang_ext(lang)}.json", 'w') { |f| f << doc.to_json } if include_json
        end
      end
    end

    def self.generate_help_page(file_base, doc, show_versions = false, lang = nil)
      versions = show_versions && ApipieDSL.available_versions
      section_file = "#{file_base}/help"
      FileUtils.mkdir_p(File.dirname(section_file)) unless File.exist?(File.dirname(section_file))
      render_page("#{section_file}#{lang_ext(lang)}.html", 'custom_help',
      doc: doc[:docs], versions: versions, language: lang,
      languages: ApipieDSL.configuration.languages, section: 'help')
    end

    def self.lang_ext(lang = nil)
      lang ? ".#{lang}" : ''
    end

    def self.copy_jscss(dest)
      src = File.expand_path('../../app/public/apipie_dsl', __dir__)
      FileUtils.mkdir_p dest
      FileUtils.cp_r "#{src}/.", dest
    end

    def self.with_loaded_documentation
      ApipieDSL.reload_documentation
      yield
    end
  end
end

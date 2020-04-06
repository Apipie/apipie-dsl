# frozen_string_literal: true

module ApipieDsl
  class ApipieDslsController < ActionController::Base
    include ActionView::Context
    include ApipieDslHelper

    layout ApipieDSL.configuration.layout

    around_action :set_script_name
    before_action :authenticate

    def authenticate
      if ApipieDSL.configuration.authenticate
        instance_eval(&ApipieDSL.configuration.authenticate)
      end
    end

    def index
      params[:version] ||= ApipieDSL.configuration.default_version
      params[:section] ||= ApipieDSL.configuration.default_section

      get_format

      respond_to do |format|
        if ApipieDSL.configuration.use_cache?
          render_from_cache
          return
        end

        @language = get_language
        @section = params[:section]

        ApipieDSL.load_documentation if ApipieDSL.configuration.reload_dsl? || (Rails.version.to_i >= 4.0 && !Rails.application.config.eager_load)

        I18n.locale = @language

        @doc = ApipieDSL.docs(params[:version], params[:class], params[:method], @language, @section)
        @doc = authorized_doc

        format.json do
          if @doc
            render json: @doc
          else
            head :not_found
          end
        end

        format.html do
          unless @doc
            render 'apipie_dsl_404', status: 404
            return
          end

          @versions = ApipieDSL.available_versions
          @doc = @doc[:docs]
          @doc[:link_extension] = (@language ? ".#{@language}" : '') + ApipieDSL.configuration.link_extension
          render 'getting_started' and return if @doc[:classes].blank?

          @klass = @doc[:classes].first if params[:class].present?
          @method = @klass[:methods].first if params[:method].present?
          @languages = ApipieDSL.configuration.languages

          if @klass && @method
            render 'method'
          elsif @klass
            render 'class'
          elsif params[:class].present? || params[:method].present?
            render 'apipie_dsl_404', status: 404
          elsif @section == 'help'
            render 'custom_help'
          else
            render 'index'
          end
        end
      end
    end

    private

    helper_method :heading

    def get_language
      return nil unless ApipieDSL.configuration.translate

      lang = Apipie.configuration.default_locale
      %i[class method version section].each do |par|
        next unless params[par]

        splitted = params[par].split('.')
        if splitted.length > 1 && ApipieDSL.configuration.languages.include?(splitted.last)
          lang = splitted.last
          params[par].sub!(".#{lang}", '')
        end
      end
      lang
    end

    def authorized_doc
      return if @doc.nil?
      return @doc unless ApipieDSL.configuration.authorize

      new_doc = { docs: @doc[:docs].clone }

      new_doc[:docs][:classes] = if @doc[:docs][:classes].is_a?(Array)
                                   @doc[:docs][:classes].select do |klass|
                                     authorize_class(klass)
                                   end
                                 else
                                   @doc[:docs][:classes].select do |_class_name, klass|
                                     authorize_class(klass)
                                   end
                                 end

      new_doc
    end

    def authorize_class(klass)
      if instance_exec(klass[:id], nil, klass, &ApipieDSL.configuration.authorize)
        klass[:methods] = klass[:methods].select do |m|
          instance_exec(klass[:id], m[:name], m, &ApipieDSL.configuration.authorize)
        end
        true
      else
        false
      end
    end

    def get_format
      %i[class method version section].each do |par|
        next unless params[par]

        %i[html json].each do |format|
          extension = ".#{format}"
          if params[par].include?(extension)
            params[par] = params[par].sub(extension, '')
            params[:format] = format
          end
        end
      end
      request.format = params[:format] if params[:format]
    end

    def render_from_cache
      path = ApipieDSL.configuration.doc_base_url.dup
      # some params can contain dot, but only one in row
      if %i[class method format version].any? { |p| params[p].to_s =~ /\.\./ }
        head :bad_request and return
      end

      path << '/' << params[:version] if params[:version].present?
      path << '/' << params[:section] if params[:section].present?
      path << '/' << params[:class] if params[:class].present?
      path << '/' << params[:method] if params[:method].present?
      path << if params[:format].present?
                ".#{params[:format]}"
              else
                '.html'
              end

      # we sanitize the params before so in ideal case, this condition
      # will be never satisfied. It's here for cases somebody adds new
      # param into the path later and forgets about sanitation.

      head :bad_request and return if path =~ /\.\./

      cache_file = File.join(ApipieDSL.configuration.cache_dir, path)
      if File.exist?(cache_file)
        content_type = case params[:format]
                       when 'json' then 'application/json'
                       else 'text/html'
                       end
        send_file cache_file, type: content_type, disposition: 'inline'
      else
        Rails.logger.error("DSL doc cache not found for '#{path}'. Perhaps you have forgot to run `rake apipie_dsl:cache`")
        head :not_found
      end
    end

    def set_script_name
      ApipieDSL.request_script_name = request.env['SCRIPT_NAME']
      yield
    ensure
      ApipieDSL.request_script_name = nil
    end
  end
end

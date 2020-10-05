# frozen_string_literal: true

module ApipieDSL
  module Base
    def apipie_eval_dsl(*args, &block)
      raise ArgumentError, 'Block expected' unless block_given?

      instance_exec(*args, &block)
      dsl_data
    ensure
      dsl_data_clear
    end

    def dsl_data
      @dsl_data ||= dsl_data_init
    end

    def dsl_data_clear
      @dsl_data = nil
    end

    private

    def dsl_data_init
      @dsl_data =
        {
          name: nil,
          short_description: nil,
          description: nil,
          dsl_versions: [],
          deprecated: false,
          meta: nil,
          params: [],
          properties: [],
          raises: [],
          returns: nil,
          see: [],
          show: true,
          examples: [],
          sections: ['all']
        }
    end
  end

  module Common
    def dsl_versions(*versions)
      dsl_data[:dsl_versions].concat(versions)
    end
    alias_method :dsl_version, :dsl_versions

    def desc(description)
      dsl_data[:description] = description
    end
    alias_method :description, :desc
    alias_method :full_description, :desc

    def short(short)
      dsl_data[:short_description] = short
    end
    alias_method :short_description, :short

    # Describe additional metadata
    #
    #   meta :author => { :name => 'John', :surname => 'Doe' }
    def meta(meta)
      dsl_data[:meta] = meta
    end

    # Add tags to classes and methods group operations together.
    def tags(*args)
      tags = args.length == 1 ? args.first : args
      dsl_data[:tag_list] += tags
    end

    def deprecated(value)
      dsl_data[:deprecated] = value
    end

    # Determine if the method (class) should be included
    # in the documentation
    def show(show)
      dsl_data[:show] = show
    end
  end

  module Parameter
    SUPPORTED_TYPES = %i[required optional keyword block].freeze
    # Describe method's parameter
    #
    # Example:
    #   param :greeting, String, :desc => "arbitrary text", :type => :required
    #   def hello_world(greeting)
    #     puts greeting
    #   end
    #
    def param(name, validator, desc_or_options = nil, options = {}, &block)
      dsl_data[:params] << [name,
                            validator,
                            desc_or_options,
                            options.merge(param_group: @current_param_group),
                            block]
    end

    def required(name, validator, desc_or_options = nil, options = {}, &block)
      options[:type] = :required
      param(name, validator, desc_or_options, options, &block)
    end

    def optional(name, validator, desc_or_options = nil, options = {}, &block)
      options[:type] = :optional
      param(name, validator, desc_or_options, options, &block)
    end

    def keyword(name, validator, desc_or_options = nil, options = {}, &block)
      options[:type] = :keyword
      param(name, validator, desc_or_options, options, &block)
    end

    def block(desc_or_options = nil, options = {}, &block)
      options[:type] = :block
      name = options[:name] || :block
      param(name, Proc, desc_or_options, options)
    end

    def list(name, desc_or_options = nil, options = {})
      options[:type] = :optional
      options[:default] ||= 'empty list'
      param(name, :rest, desc_or_options, options)
    end
    alias_method :splat, :list
    alias_method :rest, :list

    def define_param_group(name, &block)
      ApipieDSL.define_param_group(class_scope, name, &block)
    end

    # Reuses param group for this method. The definition is looked up
    # in scope of this class. If the group was defined in
    # different class, the second param can be used to specify it.
    def param_group(name, scope_or_options = nil, options = {})
      if scope_or_options.is_a?(Hash)
        options.merge!(scope_or_options)
        scope = options[:scope]
      else
        scope = scope_or_options
      end
      scope ||= default_param_group_scope

      @current_param_group = {
        scope: scope,
        name: name,
        options: options
      }
      instance_exec(&ApipieDSL.get_param_group(scope, name))
    ensure
      @current_param_group = nil
    end

    # Where the group definition should be looked up when no scope
    # given. This is expected to return a class.
    def default_param_group_scope
      class_scope
    end
  end

  module Method
    include ApipieDSL::Parameter

    def method(name, desc = nil, _options = {})
      dsl_data[:name] = name
      dsl_data[:short_description] = desc
    end

    def aliases(*names)
      dsl_data[:aliases] = names
    end

    def signature(*signature)
      dsl_data[:signature] = signature
    end

    # Describe possible errors
    #
    # Example:
    #   raises :desc => "wrong argument", :error => ArgumentError, :meta => [:some, :more, :data]
    #   raises ArgumentError, "wrong argument"
    #   def print_string(string)
    #     raise ArgumentError unless string.is_a?(String)
    #     puts string
    #   end
    #
    def raises(error_or_options, desc = nil, options = {})
      dsl_data[:raises] << [error_or_options, desc, options]
    end

    def returns(retobj_or_options, desc_or_options = nil, options = {}, &block)
      raise MultipleReturnsError unless dsl_data[:returns].nil?

      if desc_or_options.is_a?(Hash)
        options.merge!(desc_or_options)
      elsif !desc_or_options.nil?
        options[:desc] = desc_or_options
      end

      if retobj_or_options.is_a?(Hash)
        options.merge!(retobj_or_options)
      elsif retobj_or_options.is_a?(Symbol)
        options[:param_group] = retobj_or_options
      else
        options[:object_of] ||= retobj_or_options
      end

      options[:scope] ||= default_param_group_scope

      raise ArgumentError, 'Block can be specified for Hash return type only' if block && (options[:object_of] != Hash)

      data = [options, block]
      dsl_data[:returns] = data unless options[:property]
      data
    end

    # Reference other similar method
    #
    #   method :print
    #   see "MyIO#puts"
    #   def print; end
    def see(method, options = {})
      args = [method, options]
      dsl_data[:see] << args
    end

    def example(example, desc_or_options = nil, options = {})
      if desc_or_options.is_a?(Hash)
        options.merge!(desc_or_options)
      elsif !desc_or_options.nil?
        options[:desc] = desc_or_options
      end
      dsl_data[:examples] << { example: example, desc: options[:desc], for: options[:for] }
    end

    def example_for(method_name, example, desc_or_options = nil, options = {})
      if desc_or_options.is_a?(Hash)
        options.merge!(desc_or_options)
      elsif !desc_or_options.nil?
        options[:desc] = desc_or_options
      end
      dsl_data[:examples] << { example: example, desc: options[:desc], for: method_name }
    end
  end

  module Klass
    def app_info(app_info)
      dsl_data[:app_info] = app_info
    end

    def class_description(&block)
      dsl_data = apipie_eval_dsl(&block)
      dsl_data[:dsl_versions] = ApipieDSL.class_versions(class_scope) if dsl_data[:dsl_versions].empty?
      versions = dsl_data[:dsl_versions]
      versions.map do |version|
        ApipieDSL.define_class_description(class_scope, version, dsl_data)
      end
      ApipieDSL.set_class_versions(class_scope, versions)
    end

    def name(new_name)
      dsl_data[:class_name] = new_name
    end
    alias_method :label, :name

    def refs(*class_names)
      dsl_data[:refs] = class_names
    end
    alias_method :referenced_on, :refs

    def sections(sec_or_options, options = {})
      if sec_or_options.is_a?(Hash)
        options.merge!(sec_or_options)
      elsif !sec_or_options.nil?
        options[:only] = sec_or_options
      end
      only = [options[:only]].flatten || ApipieDSL.configuration.sections
      except = if options[:except]
                 [options[:except]].flatten
               else
                 []
               end
      dsl_data[:sections] = only - except
    end

    def property(name, retobj_or_options, desc_or_options = nil, options = {}, &block)
      if desc_or_options.is_a?(Hash)
        options.merge!(desc_or_options)
      elsif !desc_or_options.nil?
        options[:desc] = desc_or_options
      end

      options[:property] = true
      returns = returns(retobj_or_options, desc_or_options, options, &block)
      prop_dsl_data = {
        short_description: options[:desc],
        returns: returns
      }
      dsl_data[:properties] << [name, prop_dsl_data]
    end
    alias_method :prop, :property

    def define_prop_group(name, &block)
      ApipieDSL.define_prop_group(class_scope, name, &block)
    end

    # Reuses param group for this method. The definition is looked up
    # in scope of this class. If the group was defined in
    # different class, the second param can be used to specify it.
    def prop_group(name, scope_or_options = nil, options = {})
      if scope_or_options.is_a?(Hash)
        options.merge!(scope_or_options)
        scope = options[:scope]
      else
        scope = scope_or_options
      end
      scope ||= default_prop_group_scope

      @current_prop_group = {
        scope: scope,
        name: name,
        options: options
      }
      @meta = (options[:meta] || {}).tap { |meta| meta[:class_scope] = class_scope }
      instance_exec(&ApipieDSL.get_prop_group(scope, name))
    ensure
      @current_prop_group = nil
      @meta = nil
    end

    # Where the group definition should be looked up when no scope
    # given. This is expected to return a class.
    def default_prop_group_scope
      class_scope
    end
  end

  module Delegatable
    class Delegatee
      include ApipieDSL::Base
      include ApipieDSL::Common
      include ApipieDSL::Klass
      include ApipieDSL::Method

      attr_accessor :class_scope

      def initialize(class_scope)
        @class_scope = class_scope
      end

      def with(options = {}, &block)
        @dsl_block = block if block_given?
        @options = options
        self
      end

      def eval_dsl_for(context)
        case context
        when :method
          apipie_eval_dsl(&@dsl_block)
        when :class
          class_description(&@dsl_block)
        when :param_group
          define_param_group(@options[:name], &@dsl_block)
        when :prop_group
          define_prop_group(@options[:name], &@dsl_block)
        end
      end

      def self.instance_for(class_scope)
        @instance_for = new(class_scope)
      end

      def self.instance_reset
        @instance_for = nil
      end

      def self.instance
        @instance_for
      end

      def self.extension_data
        @extension_data ||= { methods: [] }
      end

      def self.define_validators(class_scope, method_desc)
        return if method_desc.nil? || ![true, :implicitly, :explicitly].include?(ApipieDSL.configuration.validate)
        return unless [true, :implicitly].include?(ApipieDSL.configuration.validate)

        old_method = class_scope.instance_method(method_desc.name)
        old_params = old_method.parameters.map { |param| param[1] }

        class_scope.define_method(method_desc.name) do |*args|
          # apipie validations start
          if ApipieDSL.configuration.validate_value?
            documented_params = ApipieDSL.get_method_description(ApipieDSL.get_class_name(self.class), __method__)
                                         .param_descriptions
            param_values = old_params.each_with_object({}) { |param, values| values[param] = args.shift }

            documented_params.each do |param|
              param.validate(param_values[param.name]) if param_values.key?(param.name)
            end
          end
          # apipie validations end
          old_method.bind(self).call(*args)
        end
      end

      def self.update_method_desc(method_desc, dsl_data)
        method_desc.full_description = dsl_data[:description] || method_desc.full_description
        method_desc.short_description = dsl_data[:short_description] || method_desc.short_description
        if dsl_data[:meta]&.is_a?(Hash)
          method_desc.metadata&.merge!(dsl_data[:meta])
        else
          method_desc.metadata = dsl_data[:meta]
        end
        method_desc.show = dsl_data[:show]
        method_desc.raises += dsl_data[:raises].map do |args|
          ApipieDSL::ExceptionDescription.from_dsl_data(args)
        end
        # Update parameters
        params = dsl_data[:params].map do |args|
          ApipieDSL::ParameterDescription.from_dsl_data(method_desc, args)
        end
        ParameterDescription.merge(method_desc.plain_params, params)
      end
    end
  end

  module Module
    include ApipieDSL::Delegatable

    def apipie_class(name, desc_or_options = nil, options = {}, &block)
      delegatee = prepare_delegatee(self, desc_or_options, options, &block)
      delegatee.name(name)
      delegatee.with(options).eval_dsl_for(:class)

      Delegatee.instance_reset
    end

    def apipie_method(name, desc_or_options = nil, options = {}, &block)
      delegatee = prepare_delegatee(self, desc_or_options, options, &block)
      dsl_data = delegatee.eval_dsl_for(:method)
      class_scope = delegatee.class_scope
      ApipieDSL.remove_method_description(class_scope, dsl_data[:dsl_versions], name)
      ApipieDSL.define_method_description(class_scope, name, dsl_data)

      Delegatee.instance_reset
    end

    def apipie(context = :method, desc_or_options = nil, options = {}, &block)
      if desc_or_options.is_a?(Hash)
        options = options.merge(desc_or_options)
      elsif desc_or_options.is_a?(String)
        options[:desc] = desc_or_options
      end
      options[:name] ||= context.to_s

      block = proc {} unless block_given?

      delegatee = Delegatee.instance_for(self).with(&block)
      delegatee.short(options[:desc])
      # Don't eval the block, since it will be evaluated after method is defined
      return if context == :method

      delegatee.with(options).eval_dsl_for(context)
      Delegatee.instance_reset
    end

    def method_added(method_name)
      super
      if Delegatee.instance.nil?
        # Don't autoload methods if validations are enabled but no apipie block
        # was called
        return if ApipieDSL.configuration.validate?
        # If no apipie block was called but validations are disabled then
        # it's possible to autoload methods
        return unless ApipieDSL.configuration.autoload_methods?

        apipie
      end

      instance = Delegatee.instance
      class_scope = instance.class_scope
      # Mainly for Rails in case of constant loading within apipie block.
      # Prevents methods, that are being defined in other class than the class
      # where apipie block was called, to be documented with current apipie block
      return unless class_scope == self

      dsl_data = instance.eval_dsl_for(:method)

      ApipieDSL.remove_method_description(class_scope, dsl_data[:dsl_versions], method_name)
      method_desc = ApipieDSL.define_method_description(class_scope, method_name, dsl_data)

      Delegatee.instance_reset
      Delegatee.define_validators(class_scope, method_desc)
    ensure
      # Reset if we finished method describing in the right class
      Delegatee.instance_reset if class_scope == self
    end

    private

    def prepare_delegatee(scope, desc_or_options, options, &block)
      if desc_or_options.is_a?(Hash)
        options = options.merge(desc_or_options)
      elsif desc_or_options.is_a?(String)
        options[:desc] = desc_or_options
      end

      block = proc {} unless block_given?
      delegatee = Delegatee.instance_for(scope).with(&block)
      delegatee.short(options[:desc])
      delegatee
    end
  end

  module Class
    include Module
  end

  module Extension
    include ApipieDSL::Delegatable

    def apipie(context = :method, desc_or_options = nil, options = {}, &block)
      if desc_or_options.is_a?(Hash)
        options = options.merge(desc_or_options)
      elsif desc_or_options.is_a?(String)
        options[:desc] = desc_or_options
      end
      options[:name] ||= context.to_s

      block = proc {} unless block_given?

      delegatee = Delegatee.instance_for(self).with(&block)
      delegatee.short(options[:desc])
      # Don't eval the block, since it will be evaluated after method is defined
      return if context == :method

      # Currently method extensions are supported only
      Delegatee.instance_reset
    end

    def apipie_update(context = :method, &block)
      block = proc {} unless block_given?

      delegatee = Delegatee.instance_for(self).with(&block)
      delegatee.dsl_data[:update_only] = true

      return if context == :method

      # Save instance to reuse when actual scope is set
      Delegatee.extension_data[:class] = delegatee
      Delegatee.instance_reset
    end

    def prepended(klass)
      super
      Delegatee.extension_data[:class]&.class_scope = klass
      Delegatee.extension_data[:class]&.eval_dsl_for(:class)
      Delegatee.extension_data[:methods].each do |method_name, dsl_data|
        class_scope = klass
        if dsl_data[:update_only]
          class_name = ApipieDSL.get_class_name(class_scope)
          # Update the old method description
          method_desc = ApipieDSL.get_method_description(class_name, method_name)
          unless method_desc
            raise StandardError, "Could not find method description for #{class_name}##{method_name}. Was the method defined?"
          end

          Delegatee.update_method_desc(method_desc, dsl_data)
          # Define validators for the new method
          class_scope = self
        else
          ApipieDSL.remove_method_description(class_scope, dsl_data[:dsl_versions], method_name)
          method_desc = ApipieDSL.define_method_description(class_scope, method_name, dsl_data)
        end
        Delegatee.instance_reset
        Delegatee.define_validators(class_scope, method_desc)
      end
    ensure
      Delegatee.instance_reset
    end

    def method_added(method_name)
      super
      # Methods autoload is not supported for extension modules
      return if Delegatee.instance.nil?

      dsl_data = Delegatee.instance.eval_dsl_for(:method)
      Delegatee.extension_data[:methods] << [method_name, dsl_data]
    ensure
      Delegatee.instance_reset
    end
  end
end

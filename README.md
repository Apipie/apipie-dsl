# DSL Documentation Tool

Apipie-dsl is a DSL for documenting DSLs written in Ruby. Instead of traditional
use of `#comments`, ApipieDSL lets you describe the code, through the code.

## Getting started

The easiest way to get ApipieDSL up and running with your app is:

```sh
  echo "gem 'apipie-dsl'" >> Gemfile
  bundle install
  rails g apipie:install
```

Now you can start documenting your DSLs (see
[DSL Reference](#DSL-Reference) for more info):

```ruby
  apipie :method, 'Method description' do
    required :string, String, 'Required string parameter'
  end
  def print(string)
   # ...
  end
```

# Documentation
## Contents
  - [__Configuration Reference__](#Configuration-Reference)
  - [__DSL Reference__](#DSL-Reference)

### Configuration Reference

Create a configuration file (e.g. `/config/initializers/apipie-dsl.rb` for
Rails). You can set the application name, footer text, DSL and documentation
base URL and turn off validations. You can also choose your favorite markup
language for full descriptions.

  - __app_name__ - Name of your application; used in breadcrumbs navigation.

  - __app_info__ - Application long description.

  - __copyright__ - Copyright information (shown in page footer).

  - __doc_base_url__ - Documentation frontend base url.

  - __dsl_base_url__ - Base url for default version of your DSL. To set it for
    specific version use `config.dsl_base_url[version] = url`.

  - __default_version__ - Default DSL version to be used (1.0 by default).

  - __validate__ - Parameters validation is turned off when set to false. When
    set to `:explicitly`, you must do the parameters validation yourself.
    When set to `:implicitly` (or just true), your classes' methods are wrapped
    with generated methods which already contain parameters validation
    (`:implicitly` by default).

  - __validate_value__ - Check the value of params against specified validators
    (true by default).

  - __dsl_classes_matchers__ - For reloading to work properly you need to
    specify where your DSL classes are. Can be an array if multiple paths are
    needed.

  - __markup__ - You can choose markup language for descriptions of your
    application, classes and methods. __RDoc__ is the default but you can
    choose from `ApipieDSL::Markup::Markdown.new` or
    `ApipieDSL::Markup::Textile.new`. In order to use Markdown you need
    `Maruku` gem and for Textile you need `RedCloth`. Add those to your
    `Gemfile` and run bundle if you want to use them. You can also add any
    other markup language processor.

  - __ignored__ - An array of class names (strings) (might include methods as
    well) to be ignored when generating the documentation (e.g.
    `%w[DSL::Output DSL::HTML#tag]`).

  - __class_full_names__ - Use class paths instead of class names as class id.
    This prevents same named classes overwriting each other.

  - __link_extension__ - The extension to use for DSL pages ('.html' by   
    default). Link extensions in static DSL docs cannot be changed from '.html'.

  - __languages__ - List of languages the DSL documentation should be
    translated into. Empty by default.

  - __default_locale__ - Locale used for generating documentation when no
    specific locale is set. Set to 'en' by default.

  - __locale__ - Pass locale setter/getter.
  ```ruby
    config.locale = lambda { |loc| loc ? FastGettext.set_locale(loc) : FastGettext.locale }
  ```
  - __translate__ - Pass proc to translate strings using the localization
    library your project uses. For example see [Localization](#Localization).

#### Example:
```ruby
ApipieDSL.configure do |config|
  config.app_name = "Test app"
  config.copyright = "&copy; 2019 Oleh Fedorenko"
  config.doc_base_url = "/apipie-dsl"
  config.dsl_base_url = "/dsl"
  config.validate = false
  config.markup = ApipieDSL::Markup::Markdown.new
  config.dsl_controllers_matchers = [
    "#{File.dirname(__dir__)}/dsl_example/common.rb",
    "#{File.dirname(__dir__)}/dsl_example/dsl.rb"
  ]
  config.app_info["1.0"] = "
   This is where you can inform user about your application and DSL
   in general.
  "
end
```
### DSL Reference

#### Common Description

  - __short__ (also __short_description__) - Short description of the class
    (it's shown on both the list of classes, and class details).

  - __desc__ (also __description__ and __full_description__)
    Full description of the class (shown only in class details).

  - __dsl_versions__ (also __dsl_version__)
    What versions does the class define the methods (see
    [Versioning](#Versioning) for details).

  - __meta__ - Hash or array with custom metadata.

  - __deprecated__ - Boolean value indicating if the class is marked as   
    deprecated (false by default).

  - __show__ - Class/method is hidden from documentation when set to false
    (true by default).

#### Class/Module Description

Describe your class via:
```ruby
  apipie :class do
    # ...
  end
```

Inheritance is supported, so you can specify common params for group of classes
in their parent class.

The following keywords are available (all are optional):
  - __name__ - Custom class name (in case if you want to explicitly save full
    class name e.g. ParentModule::Class)

  - __property__ - Object's property (could be an `attr_reader` or public
    method with return value).

##### Example:
```ruby
  apipie :class, 'Site members' do
    dsl_version 'development'
    meta :author => {:name => 'John', :surname => 'Doe'}
    deprecated false
    description <<-EOS
      == Long description
      Example class for dsl documentation
      ...
    EOS
  end
```

#### Method Description

Then describe methods available to your DSL:
```ruby
  apipie :method do
    # ...
  end
```
  - __param__ - Look at [Parameter description](#Parameter-description) section
    for details.

  - __returns__ - Look at [Response description](#Response-description) section
    for details.

  - __raises__ - Describe each possible error that can happen while calling this
    method.

  - __param_group__ - Extract parameters defined via `apipie :param_group do ...
    end`

  - __see__ - Provide reference to another method, this has to be a string with
    `class_name#method_name`.

##### Example:
```ruby
  apipie :method, 'Short description' do
    description 'Full method description'
    required :id, String, desc: 'ID for tag'
    optional :type, String, desc: 'Optional type', default: ''
    param :css_class, String, :desc => 'CSS class', type: :optional, default: ''
    keyword :content, Hash, :desc => 'Hash with content' do
      optional :text, String, 'Text string', default: 'Default text'
    end
    returns BaseTag
    raises ArgumentError, 'String is expected'
    raises ArgumentError, 'Hash is expected'
    meta :message => 'Some very important info'
    see 'html#tag', 'Link description'
    see :link => 'html#tags', :desc => 'Another link description'
    show false
  end
  def tag(id, type = '', css_class = '', content: { text: 'Default text' })
   #...
  end
```
#### Parameter Description

Use `param` to describe every possible parameter. You can use the Hash validator
in conjunction with a block given to the param method to describe nested
parameters.

  - __name__- The first argument is the parameter name as a symbol.

  - __validator__ - Second parameter is the parameter validator, choose one
    from section [Validators](#Validators).

  - __desc__ - Parameter description.

  - __required__ Set this true/false to make it required/optional. Default is
    true.

##### Example:
```ruby
  param :user, Hash, :desc => 'User info' do
    param :username, String, desc: 'Username for login', required: true
    param :password, String, desc: 'Password for login', required: true
    param :membership, ['standard','premium'], desc: 'User membership'
    param :admin_override, String, desc: 'Not shown in documentation', show: false
  end
  def create
    #...
  end
```
#### DRY with param_group

Often, params occur together in more methods. These params can be extracted
with `def_param_group` and `param_group` keywords.

The definition is looked up in the scope of the class. If the
group is defined in a different class, it might be referenced by
specifying the second argument.

##### Example:
```ruby
  # v1/users_class.rb
  def_param_group :address do
    param :street, String
    param :number, Integer
    param :zip, String
  end

  def_param_group :user do
    param :user, Hash do
      param :name, String, 'Name of the user'
      param_group :address
    end
  end

  apipie :method, 'Create an user' do
    param_group :user
  end
  def create(user)
    # ...
  end

  apipie :method, 'Update an user' do
    param_group :user
  end
  def update(user)
    # ...
  end

  # v2/users_class.rb
  apipie :method, 'Create an user' do
    param_group :user, V1::UsersClass
  end
  def create(user)
    # ...
  end
```
#### Return Description

TODO

##### Example:
```ruby
  # TODO
```

## Rails Integration

TODO

### Validators

TODO

### TypeValidator

Check the parameter type. Only String, Hash and Array are supported
for the sake of simplicity. Read more to find out how to add
your own validator.

```ruby
  # TODO
```

### RegexpValidator

Check parameter value against given regular expression.

```ruby
  param :regexp_param, /^[0-9]* years/, desc: 'regexp param'
```

### EnumValidator

Check if parameter value is included in the given array.

```ruby
  param :enum_param, [100, 'one', 'two', 1, 2], desc: 'enum validator'
```

### ProcValidator

If you need more complex validation and you know you won't reuse it, you
can use the Proc/lambda validator. Provide your own Proc, taking the value
of the parameter as the only argument. Return true if value passes validation
or return some text about what is wrong otherwise. Don't use the keyword *return*
if you provide an instance of Proc (with lambda it is ok), just use the last
statement return property of ruby.

```ruby
  param :proc_param, lambda { |val|
    val == 'param value' ? true : "The only good value is 'param value'."
  }, desc: 'proc validator'
```

### HashValidator

You can describe hash parameters in depth if you provide a block with a
description of nested values.

```ruby
   param :user, Hash, desc: 'User info' do
     required :username, String, desc: 'Username for login'
     required :password, String, desc: 'Password for login'
     param :membership, ['standard','premium'], desc: 'User membership'
   end
```

### NumberValidator

Check if the parameter is a positive integer number or zero.

```ruby
  required :product_id, :number, desc: 'Identifier of the product'
  required :quantity, :number, desc: 'Number of products to order'
```

### DecimalValidator

Check if the parameter is a decimal number.

```ruby
  required :latitude, :decimal, desc: 'Geographic latitude'
  required :longitude, :decimal, desc: 'Geographic longitude'
```

### ArrayValidator

Check if the parameter is an array.
```ruby
  required :array_param, Array, desc: 'array param'
```

##### Additional options

  - __of__ - Specify the type of items. If not given it accepts an array of any
    item type.

  - __in__ - Specify an array of valid item values.

##### Examples:

Assert `things` is an array of any items.

```ruby
  param :things, Array
```
Assert `hits` must be an array of integer values.

```ruby
  param :hits, Array, of: Integer
```

Assert `colors` must be an array of valid string values.

```ruby
  param :colors, Array, in: ['red', 'green', 'blue']
```

The retrieving of valid items can be deferred until needed using a lambda. It is evaluated only once
```ruby
  param :colors, Array, in: ->  { Colors.all.map(&:name) }
```

### NestedValidator

You can describe nested parameters in depth if you provide a block with a
description of nested values.

```ruby
  param :comments, Array, desc: 'User comments' do
    required :name, String, desc: 'Name of the comment'
    required :comment, String, desc: 'Full comment'
  end
```

### Adding custom validator

TODO

### Versioning

TODO

### Markup

The default markup language is
[RDoc](https://rdoc.github.io/rdoc/RDoc/Markup.html). It can be changed in
the config file (`config.markup=`) to one of these:

  - __Markdown__ - Use `Apipie::Markup::Markdown.new`. You need Maruku gem.

  - __Textile__ - Use `Apipie::Markup::Textile.new`. You need RedCloth gem.

Or provide you own object with a `to_html(text)` method. For inspiration, this
is how Textile markup usage is implemented:

```ruby
  class Textile
    def initialize
      require 'RedCloth'
    end

    def to_html(text)
      RedCloth.new(text).to_html
    end
  end
```

### Localization

TODO

### Static files

TODO

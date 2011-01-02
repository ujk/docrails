require 'rails/railtie'
require 'active_support/core_ext/module/delegation'
require 'pathname'
require 'rbconfig'
require 'rails/engine/railties'

module Rails
  # Rails::Engine allows you to wrap a specific Rails application and share it accross
  # different applications. Since Rails 3.0, every Rails::Application is nothing
  # more than an Engine, allowing you to share it very easily.
  #
  # Any Rails::Engine is also a Rails::Railtie, so the same methods (like rake_tasks and
  # generators) and configuration available in the latter can also be used in the former.
  #
  # == Creating an Engine
  #
  # In Rails versions before to 3.0, your gems automatically behaved as Engine, however
  # this coupled Rails to Rubygems. Since Rails 3.0, if you want a gem to automatically
  # behave as Engine, you have to specify an Engine for it somewhere inside your plugin
  # lib folder (similar to how we specify a Railtie):
  #
  #   # lib/my_engine.rb
  #   module MyEngine
  #     class Engine < Rails::Engine
  #     end
  #   end
  #
  # Then ensure that this file is loaded at the top of your config/application.rb (or in
  # your Gemfile) and it will automatically load models, controllers and helpers
  # inside app, load routes at "config/routes.rb", load locales at "config/locales/*",
  # load tasks at "lib/tasks/*".
  #
  # == Configuration
  #
  # Besides the Railtie configuration which is shared across the application, in a
  # Rails::Engine you can access autoload_paths, eager_load_paths and autoload_once_paths,
  # which differently from a Railtie, are scoped to the current Engine.
  #
  # Example:
  #
  #   class MyEngine < Rails::Engine
  #     # Add a load path for this specific Engine
  #     config.autoload_paths << File.expand_path("../lib/some/path", __FILE__)
  #
  #     initializer "my_engine.add_middleware" do |app|
  #       app.middleware.use MyEngine::Middleware
  #     end
  #   end
  #
  # == Generators
  #
  # You can set up generators for engine with config.generators method:
  #
  #   class MyEngine < Rails::Engine
  #     config.generators do |g|
  #       g.orm             :active_record
  #       g.template_engine :erb
  #       g.test_framework  :test_unit
  #     end
  #   end
  #
  # You can also set generators for application by using config.app_generators:
  #
  #   class MyEngine < Rails::Engine
  #     # note that you can also pass block to app_generators in the same way you
  #     # can pass it to generators method
  #     config.app_generators.orm :datamapper
  #   end
  #
  # == Paths
  #
  # Since Rails 3.0, both your Application and Engines do not have hardcoded paths.
  # This means that you are not required to place your controllers at "app/controllers",
  # but in any place which you find convenient.
  #
  # For example, let's suppose you want to lay your controllers at lib/controllers, all
  # you need to do is:
  #
  #   class MyEngine < Rails::Engine
  #     paths["app/controllers"] = "lib/controllers"
  #   end
  #
  # You can also have your controllers being loaded from both "app/controllers" and
  # "lib/controllers":
  #
  #   class MyEngine < Rails::Engine
  #     paths["app/controllers"] << "lib/controllers"
  #   end
  #
  # The available paths in an Engine are:
  #
  #   class MyEngine < Rails::Engine
  #     paths["app"]                 #=> ["app"]
  #     paths["app/controllers"]     #=> ["app/controllers"]
  #     paths["app/helpers"]         #=> ["app/helpers"]
  #     paths["app/models"]          #=> ["app/models"]
  #     paths["app/views"]           #=> ["app/views"]
  #     paths["lib"]                 #=> ["lib"]
  #     paths["lib/tasks"]           #=> ["lib/tasks"]
  #     paths["config"]              #=> ["config"]
  #     paths["config/initializers"] #=> ["config/initializers"]
  #     paths["config/locales"]      #=> ["config/locales"]
  #     paths["config/routes"]       #=> ["config/routes.rb"]
  #   end
  #
  # Your Application class adds a couple more paths to this set. And as in your Application,
  # all folders under "app" are automatically added to the load path. So if you have
  # "app/observers", it's added by default.
  #
  # == Endpoint
  #
  # Engine can be also a rack application. It can be useful if you have a rack application that
  # you would like to wrap with Engine and provide some of the Engine's features.
  #
  # To do that, use endpoint method:
  #   module MyEngine
  #     class Engine < Rails::Engine
  #       endpoint MyRackApplication
  #     end
  #   end
  #
  # Now you can mount your engine in application's routes just like that:
  #
  # MyRailsApp::Application.routes.draw do
  #   mount MyEngine::Engine => "/engine"
  # end
  #
  # == Middleware stack
  #
  # As Engine can now be rack endpoint, it can also have a middleware stack. The usage is exactly
  # the same as in application:
  #
  #   module MyEngine
  #     class Engine < Rails::Engine
  #       middleware.use SomeMiddleware
  #     end
  #   end
  #
  # == Routes
  #
  # If you don't specify endpoint, routes will be used as default endpoint. You can use them
  # just like you use application's routes:
  #
  #   # ENGINE/config/routes.rb
  #   MyEngine::Engine.routes.draw do
  #     match "/" => "posts#index"
  #   end
  #
  # == Mount priority
  #
  # Note that now there can be more than one router in you application and it's better to avoid
  # passing requests through many routers. Consider such situation:
  #
  #   MyRailsApp::Application.routes.draw do
  #     mount MyEngine::Engine => "/blog"
  #     match "/blog/omg" => "main#omg"
  #   end
  #
  # MyEngine is mounted at "/blog" path and additionaly "/blog/omg" points application's controller.
  # In such situation request to "/blog/omg" will go through MyEngine and if there is no such route
  # in Engine's routes, it will be dispatched to "main#omg". It's much better to swap that:
  #
  #   MyRailsApp::Application.routes.draw do
  #     match "/blog/omg" => "main#omg"
  #     mount MyEngine::Engine => "/blog"
  #   end
  #
  # Now, Engine will get only requests that were not handled by application.
  #
  # == Asset path
  #
  # When you use engine with its own public directory, you will probably want to copy or symlink it
  # to application's public directory. To simplify generating paths for assets, you can set asset_path
  # for an Engine:
  #
  #   module MyEngine
  #     class Engine < Rails::Engine
  #       config.asset_path = "/my_engine/%s"
  #     end
  #   end
  #
  # With such config, asset paths will be automatically modified inside Engine:
  # image_path("foo.jpg") #=> "/my_engine/images/foo.jpg"
  #
  # == Serving static files
  #
  # By default, rails use ActionDispatch::Static to serve static files in development mode. This is ok
  # while you develop your application, but when you want to deploy it, assets from engine will not be
  # served by default. You should choose one of the two following strategies:
  #
  # * enable serving static files by setting config.serve_static_assets to true
  # * copy engine's public files to application's public folder with rake ENGINE_NAME:install:assets, for example
  #   rake my_engine:install:assets
  #
  # == Engine name
  #
  # There are some places where engine's name is used:
  # * routes: when you mount engine with mount(MyEngine::Engine => '/my_engine'), it's used as default :as option
  # * some of the rake tasks are based on engine name, e.g. my_engine:install:migrations, my_engine:install:assets
  #
  # Engine name is set by default based on class name. For MyEngine::Engine it will be my_engine_engine.
  # You can change it manually it manually using engine_name method:
  #
  #   module MyEngine
  #     class Engine < Rails::Engine
  #       engine_name "my_engine"
  #     end
  #   end
  #
  # == Isolated Engine
  #
  # Normally when you create controllers, helpers and models inside engine, they are treated
  # as they were created inside the application. This means all applications helpers and named routes
  # will be available to your engine controllers.
  #
  # However, sometimes you want to isolate your engine from the application, specially if your engine
  # have its own router. To do that, you simply need to call +isolate_namespace+. This method requires
  # you to pass a module where all your controllers, helpers and models should be nested to:
  #
  #   module MyEngine
  #     class Engine < Rails::Engine
  #       isolate_namespace MyEngine
  #     end
  #   end
  #
  # With such Engine, everything that is inside MyEngine module, will be isolated from application.
  #
  # Consider such controller:
  #
  #   module MyEngine
  #     class FooController < ActionController::Base
  #     end
  #   end
  #
  # If engine is marked as isolated, FooController has access only to helpers from engine and
  # url_helpers from MyEngine::Engine.routes.
  #
  # The next thing that changes in isolated engine is routes behaviour. Normally, when you namespace
  # your controllers, you also need to do namespace all your routes. With isolated engine,
  # the namespace is applied by default, so you can ignore it in routes:
  #
  #   MyEngine::Engine.routes.draw do
  #     resources :articles
  #   end
  # 
  # The routes above will automatically point to MyEngine::ApplicationContoller. Further more, you don't
  # need to use longer url helpers like "my_engine_articles_path". Instead, you shuold simply use
  # articles_path as you would do with your application.
  #
  # To make that behaviour consistent with other parts of framework, isolated engine has influence also on
  # ActiveModel::Naming. When you use namespaced model, like MyEngine::Article, it will normally
  # use the prefix "my_engine". In isolated engine, the prefix will be ommited in url helpers and
  # form fields for convenience.
  #
  #   polymorphic_url(MyEngine::Article.new) #=> "articles_path"
  #
  #   form_for(MyEngine::Article.new) do
  #     text_field :title #=> <input type="text" name="article[title]" id="article_title" />
  #   end
  #
  # Additionaly isolated engine will set its name according to namespace, so
  # MyEngine::Engine.engine_name #=> "my_engine". It will also set MyEngine.table_name_prefix
  # to "my_engine_", changing MyEngine::Article model to use my_engine_article table.
  #
  # == Using Engine's routes outside Engine
  #
  # Since now you can mount engine inside application's routes, you do not have direct access to engine's
  # url_helpers inside application. When you mount Engine in application's routes, a special helper is
  # created to allow you to do that. Consider such scenario:
  #
  #   # APP/config/routes.rb
  #   MyApplication::Application.routes.draw do
  #     mount MyEngine::Engine => "/my_engine", :as => "my_engine"
  #     match "/foo" => "foo#index"
  #   end
  #
  # Now, you can use my_engine helper inside your application:
  #
  #   class FooController < ApplicationController
  #     def index
  #       my_engine.root_url #=> /my_engine/
  #     end
  #   end
  #
  # There is also 'main_app' helper that gives you access to application's routes inside Engine:
  #
  #   module MyEngine
  #     class BarController
  #       def index
  #         main_app.foo_path #=> /foo
  #       end
  #     end
  #   end
  #
  # Note that the :as option given to mount takes the engine_name as default, so most of the time
  # you can simply ommit it.
  #
  # Finally, if you want to generate url to engine's route using polymorphic_url, you also need
  # to pass the engine helper. Let's say that you want to create a form pointing to one of the
  # engine's routes. All you need to do is pass the helper as the first element in array with
  # attributes for url:
  #
  # form_for([my_engine, @user])
  #
  # This code will use my_engine.user_path(@user) to generate the proper route.
  #
  # == Migrations & seed data
  #
  # Engines can have their own migrations. Default path for migrations is exactly the same
  # as in application: db/migrate
  #
  # To use engine's migrations in application you can use rake task, which copies them to
  # application's dir:
  #
  #   rake ENGINE_NAME:install:migrations
  #
  # Note that some of the migrations may be skipped if migration with the same name already exists
  # in application. In such situation you must decide whether to leave that migration or rename the
  # migration in application and rerun copying migrations.
  #
  # If your engine has migrations, you may also want to prepare data for the database in
  # seeds.rb file. You can load that data using load_seed method, e.g.
  #
  #   MyEngine::Engine.load_seed
  #
  class Engine < Railtie
    autoload :Configuration, "rails/engine/configuration"
    autoload :Railties,      "rails/engine/railties"

    class << self
      attr_accessor :called_from, :isolated
      alias :isolated? :isolated
      alias :engine_name :railtie_name

      def inherited(base)
        unless base.abstract_railtie?
          base.called_from = begin
            # Remove the line number from backtraces making sure we don't leave anything behind
            call_stack = caller.map { |p| p.sub(/:\d+.*/, '') }
            File.dirname(call_stack.detect { |p| p !~ %r[railties[\w.-]*/lib/rails|rack[\w.-]*/lib/rack] })
          end
        end

        super
      end

      def endpoint(endpoint = nil)
        @endpoint = endpoint if endpoint
        @endpoint
      end

      def isolate_namespace(mod)
        engine_name(generate_railtie_name(mod))

        name = engine_name
        self.routes.default_scope = {:module => name}
        self.isolated = true

        unless mod.respond_to?(:_railtie)
          _railtie = self
          mod.singleton_class.instance_eval do
            define_method(:_railtie) do
              _railtie
            end

            unless mod.respond_to?(:table_name_prefix)
              define_method(:table_name_prefix) do
                "#{name}_"
              end
            end
         end
        end
      end

      # Finds engine with given path
      def find(path)
        Rails::Engine::Railties.engines.find { |r| File.expand_path(r.root.to_s) == File.expand_path(path.to_s) }
      end
    end

    delegate :middleware, :root, :paths, :to => :config
    delegate :engine_name, :isolated?, :to => "self.class"

    def load_tasks
      super
      paths["lib/tasks"].existent.sort.each { |ext| load(ext) }
    end

    def eager_load!
      config.eager_load_paths.each do |load_path|
        matcher = /\A#{Regexp.escape(load_path)}\/(.*)\.rb\Z/
        Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
          require_dependency file.sub(matcher, '\1')
        end
      end
    end

    def railties
      @railties ||= self.class::Railties.new(config)
    end

    def app
      @app ||= begin
        config.middleware = config.middleware.merge_into(default_middleware_stack)
        config.middleware.build(endpoint)
      end
    end

    def endpoint
      self.class.endpoint || routes
    end

    def call(env)
      app.call(env.merge!(env_config))
    end

    def env_config
      @env_config ||= {
        'action_dispatch.routes' => routes,
        'action_dispatch.asset_path' => config.asset_path
      }
    end

    def routes
      @routes ||= ActionDispatch::Routing::RouteSet.new
      @routes.append(&Proc.new) if block_given?
      @routes
    end

    def initializers
      initializers = []
      railties.all { |r| initializers += r.initializers }
      initializers += super
      initializers
    end

    def config
      @config ||= Engine::Configuration.new(find_root_with_flag("lib"))
    end

    # Load data from db/seeds.rb file. It can be used in to load engines'
    # seeds, e.g.:
    #
    # Blog::Engine.load_seed
    def load_seed
      seed_file = paths["db/seeds"].existent.first
      load(seed_file) if File.exist?(seed_file)
    end

    # Add configured load paths to ruby load paths and remove duplicates.
    initializer :set_load_path, :before => :bootstrap_hook do
      _all_load_paths.reverse_each do |path|
        $LOAD_PATH.unshift(path) if File.directory?(path)
      end
      $LOAD_PATH.uniq!
    end

    # Set the paths from which Rails will automatically load source files,
    # and the load_once paths.
    #
    # This needs to be an initializer, since it needs to run once
    # per engine and get the engine as a block parameter
    initializer :set_autoload_paths, :before => :bootstrap_hook do |app|
      ActiveSupport::Dependencies.autoload_paths.unshift(*_all_autoload_paths)
      ActiveSupport::Dependencies.autoload_once_paths.unshift(*_all_autoload_once_paths)

      # Freeze so future modifications will fail rather than do nothing mysteriously
      config.autoload_paths.freeze
      config.eager_load_paths.freeze
      config.autoload_once_paths.freeze
    end

    initializer :add_routing_paths do |app|
      paths = self.paths["config/routes"].existent

      if routes? || paths.any?
        app.routes_reloader.paths.unshift(*paths)
        app.routes_reloader.route_sets << routes
      end
    end

    # I18n load paths are a special case since the ones added
    # later have higher priority.
    initializer :add_locales do
      config.i18n.railties_load_path.concat(paths["config/locales"].existent)
    end

    initializer :add_view_paths do
      views = paths["app/views"].existent
      unless views.empty?
        ActiveSupport.on_load(:action_controller){ prepend_view_path(views) }
        ActiveSupport.on_load(:action_mailer){ prepend_view_path(views) }
      end
    end

    initializer :load_environment_config, :before => :load_environment_hook do
      environment = paths["config/environments"].existent.first
      require environment if environment
    end

    initializer :append_asset_paths do
      config.asset_path ||= default_asset_path

      public_path = paths["public"].first
      if config.compiled_asset_path && File.exist?(public_path)
        config.static_asset_paths[config.compiled_asset_path] = public_path
      end
    end

    initializer :prepend_helpers_path do |app|
      if !isolated? || (app == self)
        app.config.helpers_paths.unshift(*paths["app/helpers"].existent)
      end
    end

    initializer :load_config_initializers do
      config.paths["config/initializers"].existent.sort.each do |initializer|
        load(initializer)
      end
    end

    initializer :engines_blank_point do
      # We need this initializer so all extra initializers added in engines are
      # consistently executed after all the initializers above across all engines.
    end

    rake_tasks do
      next if self.is_a?(Rails::Application)

      namespace railtie_name do
        desc "Shortcut for running both rake #{railtie_name}:install:migrations and #{railtie_name}:install:assets"
        task :install do
          Rake::Task["#{railtie_name}:install:migrations"].invoke
          Rake::Task["#{railtie_name}:install:assets"].invoke
        end

        namespace :install do
          # TODO Add assets copying to this list
          # TODO Skip this if there is no paths["db/migrate"] for the engine
          desc "Copy migrations from #{railtie_name} to application"
          task :migrations do
            ENV["FROM"] = railtie_name
            Rake::Task["railties:install:migrations"].invoke
          end

          desc "Copy assets from #{railtie_name} to application"
          task :assets do
            ENV["FROM"] = railtie_name
            Rake::Task["railties:install:assets"].invoke
          end
        end
      end
    end

  protected

    def default_asset_path
      "/#{railtie_name}%s"
    end

    def routes?
      defined?(@routes)
    end

    def find_root_with_flag(flag, default=nil)
      root_path = self.class.called_from

      while root_path && File.directory?(root_path) && !File.exist?("#{root_path}/#{flag}")
        parent = File.dirname(root_path)
        root_path = parent != root_path && parent
      end

      root = File.exist?("#{root_path}/#{flag}") ? root_path : default
      raise "Could not find root path for #{self}" unless root

      RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ?
        Pathname.new(root).expand_path : Pathname.new(root).realpath
    end

    def default_middleware_stack
      ActionDispatch::MiddlewareStack.new
    end

    def _all_autoload_once_paths
      config.autoload_once_paths
    end

    def _all_autoload_paths
      @_all_autoload_paths ||= (config.autoload_paths + config.eager_load_paths + config.autoload_once_paths).uniq
    end

    def _all_load_paths
      @_all_load_paths ||= (config.paths.load_paths + _all_autoload_paths).uniq
    end
  end
end

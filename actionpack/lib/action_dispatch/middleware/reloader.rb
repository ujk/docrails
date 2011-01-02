module ActionDispatch
<<<<<<< HEAD
  # ActionDispatch::Reloader provides prepare and cleanup callbacks,
  # intended to assist with code reloading during development.
  #
  # Prepare callbacks are run before each request, and cleanup callbacks
  # after each request. In this respect they are analogs of ActionDispatch::Callback's
  # before and after callbacks. However, cleanup callbacks are not called until the
  # request is fully complete -- that is, after #close has been called on
  # the response body. This is important for streaming responses such as the
=======
  # ActionDispatch::Reloader provides to_prepare and to_cleanup callbacks.
  # These are analogs of ActionDispatch::Callback's before and after
  # callbacks, with the difference that to_cleanup is not called until the
  # request is fully complete -- that is, after #close has been called on
  # the request body. This is important for streaming responses such as the
>>>>>>> 4c7da682b5580846867f1cce8dc63ca9b34c78cf
  # following:
  #
  #     self.response_body = lambda { |response, output|
  #       # code here which refers to application models
  #     }
  #
  # Cleanup callbacks will not be called until after the response_body lambda
  # is evaluated, ensuring that it can refer to application models and other
  # classes before they are unloaded.
  #
  # By default, ActionDispatch::Reloader is included in the middleware stack
<<<<<<< HEAD
  # only in the development environment; specifically, when config.cache_classes
  # is false. Callbacks may be registered even when it is not included in the
  # middleware stack, but are executed only when +ActionDispatch::Reloader.prepare!+
  # or +ActionDispatch::Reloader.cleanup!+ are called manually.
=======
  # only in the development environment.
>>>>>>> 4c7da682b5580846867f1cce8dc63ca9b34c78cf
  #
  class Reloader
    include ActiveSupport::Callbacks

    define_callbacks :prepare, :scope => :name
    define_callbacks :cleanup, :scope => :name

<<<<<<< HEAD
    # Add a prepare callback. Prepare callbacks are run before each request, prior
    # to ActionDispatch::Callback's before callbacks.
    def self.to_prepare(*args, &block)
      set_callback(:prepare, *args, &block)
=======
    # Add a preparation callback. Preparation callbacks are run before each
    # request.
    #
    # If a symbol with a block is given, the symbol is used as an identifier.
    # That allows to_prepare to be called again with the same identifier to
    # replace the existing callback. Passing an identifier is a suggested
    # practice if the code adding a preparation block may be reloaded.
    def self.to_prepare(*args, &block)
      first_arg = args.first
      if first_arg.is_a?(Symbol) && block_given?
        remove_method :"__#{first_arg}" if method_defined?(:"__#{first_arg}")
        define_method :"__#{first_arg}", &block
        set_callback(:prepare, :"__#{first_arg}")
      else
        set_callback(:prepare, *args, &block)
      end
>>>>>>> 4c7da682b5580846867f1cce8dc63ca9b34c78cf
    end

    # Add a cleanup callback. Cleanup callbacks are run after each request is
    # complete (after #close is called on the response body).
<<<<<<< HEAD
    def self.to_cleanup(*args, &block)
      set_callback(:cleanup, *args, &block)
    end

    # Execute all prepare callbacks.
=======
    def self.to_cleanup(&block)
      set_callback(:cleanup, &block)
    end

>>>>>>> 4c7da682b5580846867f1cce8dc63ca9b34c78cf
    def self.prepare!
      new(nil).send(:_run_prepare_callbacks)
    end

<<<<<<< HEAD
    # Execute all cleanup callbacks.
=======
>>>>>>> 4c7da682b5580846867f1cce8dc63ca9b34c78cf
    def self.cleanup!
      new(nil).send(:_run_cleanup_callbacks)
    end

<<<<<<< HEAD
=======
    def self.reload!
      prepare!
      cleanup!
    end

>>>>>>> 4c7da682b5580846867f1cce8dc63ca9b34c78cf
    def initialize(app)
      @app = app
    end

    module CleanupOnClose
      def close
        super if defined?(super)
      ensure
        ActionDispatch::Reloader.cleanup!
      end
    end

    def call(env)
      _run_prepare_callbacks
      response = @app.call(env)
      response[2].extend(CleanupOnClose)
      response
<<<<<<< HEAD
    rescue Exception
      _run_cleanup_callbacks
      raise
=======
>>>>>>> 4c7da682b5580846867f1cce8dc63ca9b34c78cf
    end
  end
end

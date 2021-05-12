module Datadog
  # Responsible for the behavior the tracer after it's completely
  # loaded, but before `require 'ddtrace'` returns control to
  # the user.
  module Initialization
    module_function

    def initialize!
      initial_configuration
      deprecation_warnings
    end

    # Ensures tracer public API is ready for use.
    #
    # We want to eager load tracer components, as
    # this allows us to have predictable initialization of
    # inter-dependent parts.
    # It also allows the remove of concurrency primitives
    # from public tracer components, as they are guaranteed
    # to be a good state immediately.
    def initial_configuration
      Datadog.configure
    end

    # Emits deprecation warnings that pertain to the
    # library as a whole.
    #
    # Specific subcomponents can still emit their own
    # deprecation warnings if needed.
    #
    # This method will only be run once per application
    # lifecycle.
    def deprecation_warnings
      if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.1')
        Datadog.logger.warn(
          "Support for Ruby versions < 2.1 in dd-trace-rb is DEPRECATED.\n" \
          "Last version to support Ruby < 2.1 will be 0.49.x, which will only receive critical bugfixes.\n" \
          'Support for Ruby versions < 2.1 will be REMOVED in version 0.50.0.'
        )
      end
    end
  end
end

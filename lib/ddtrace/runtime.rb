module Datadog
  # TODO: {Runtime} module already exists, but I want a {Runtime} class
  # TODO: {Datadog::Tracer} is already a class :(, using {Tracing} instead temporarily
  # for the tracer running state.
  module Tracing
    # This class encapsulates all tracer runtime data and objects.
    #
    # Any component or information that specifically represents the
    # currently active tracer instance should be captured here.
    #
    # Any Ruby object living outside of this class should be
    # part of the generic tracer structure, unaffected by configuration
    # or runtime state.
    #
    # Creating a new {Runtime} will effectively configure and initialized a new
    # running instance of the tracer.
    #
    # Destroying the {Runtime} will shutdown the current tracer instance
    # and remove any configuration in place.
    #
    # The tracer is shutdown if and only if (iff) the {Runtime} is shutdown.
    #
    # TODO: (double-check if true) A production user of the tracer will only initialize a single
    # {Runtime} instance throughout the lifetime of the host application.
    class Runtime
      extend Forwardable

      attr_reader :configuration

      def initialize(
        configuration = Configuration::Settings.new,
        components = build_components(configuration)
      )
        @configuration = configuration
        @components = components
      end

      def_delegators \
        :components,
        :health_metrics, :logger, :profiler, :runtime_metrics, :tracer


      def configure(target = configuration, opts = {})
        return Configuration::PinSetup.new(target, opts).call unless target.is_a?(Configuration::Settings)

        yield(target) if block_given?

        @components = replace_components!(target, @components)
      end

      # Gracefully shuts down all components.
      #
      # Components will still respond to method calls as usual,
      # but might not internally perform their work after shutdown.
      #
      # This avoids errors being raised across the host application
      # during shutdown, while allowing for graceful decommission of resources.
      def shutdown!
        @components.shutdown!
      end

      # TODO: remove
      # module Mixin
      #   def self.extended(base)
      #
      #   end
      #
      #   def_delegators \
      #   :runtime,
      #   :configuration,
      #   :health_metrics, :logger, :profiler, :runtime_metrics, :tracer
      # end

      private

      attr_reader :components

      def build_components(configuration)
        components = Configuration::Components.new(configuration)
        components.startup!(configuration)
        components
      end

      def replace_components!(configuration, old)
        components = Configuration::Components.new(configuration)

        old.shutdown!(components)
        components.startup!(configuration)
        components
      end
    end
  end
end

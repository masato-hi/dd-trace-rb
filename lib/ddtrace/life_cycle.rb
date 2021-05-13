require 'ddtrace/runtime'

module Datadog
  # Manages the {Runtime} life cycle for the host application.
  #
  # The {Runtime} is the only component of the tracer that has
  # state. This class ensure that the {Runtime} is created,
  # modified and decommissioned correctly during the host
  # application's own life cycle.
  module LifeCycle
    extend Forwardable

    def_delegators \
        :runtime,
        :configure, :shutdown!,
        :configuration,
        # :components,
        :health_metrics, :logger, :profiler, :runtime_metrics, :tracer


    def shutdown!
      @runtime.shutdown! if @runtime
    end

    protected

    def start
      raise "Already started!" if @runtime # TODO: only in tests. Warn in prod? I don't think we need it in prod.

      @runtime = Tracing::Runtime.new
      Datadog.configure(@runtime)
    end

    private

    attr_reader :runtime

    # Only used internally for testing
    def restart!
      shutdown!
      @runtime = nil
      start
    end
    #
    #
    #
    #
    # attr_reader :configuration
    #
    # def self.extended(base)
    #   base.send(:initialize_configuration)
    # end
    #
    # def configure(target = configuration, opts = {})
    #   ruby_version_deprecation_warning
    #
    #   if target.is_a?(Settings)
    #     yield(target) if block_given?
    #
    #     @components = (
    #       if @components
    #         replace_components!(target, @components)
    #       else
    #         build_components(target)
    #       end
    #     )
    #
    #     target
    #   else
    #     PinSetup.new(target, opts).call
    #   end
    # end
    #
    # def_delegators \
    #   :components,
    #   :health_metrics,
    #   :logger,
    #   :profiler,
    #   :runtime_metrics,
    #   :tracer,
    #
    #   # Gracefully shuts down all components.
    #   #
    #   # Components will still respond to method calls as usual,
    #   # but might not internally perform their work after shutdown.
    #   #
    #   # This avoids errors being raised across the host application
    #   # during shutdown, while allowing for graceful decommission of resources.
    #   #
    #   # Components won't be automatically reinitialized after a shutdown.
    #   def shutdown!
    #     @components.shutdown! if @components
    #   end
    #
    # protected
    #
    # attr_reader :components
    #
    # private
    #
    # def initialize_configuration
    #   @configuration = Settings.new
    #   @components = nil # TODO: build_components(@configuration)
    # end
    #
    # # Gracefully shuts down the tracer and disposes of component references,
    # # allowing execution to start anew.
    # #
    # # In contrast with +#shutdown!+, components will be automatically
    # # reinitialized after a reset.
    # #
    # # Used internally to ensure a clean environment between test runs.
    # def reset!
    #   @components.shutdown! if @components
    #   # @components = nil
    #   configuration.reset!
    #   # @configuration = nil
    # end
    #
    # def build_components(settings)
    #   components = Components.new(settings)
    #   components.startup!(settings)
    #   components
    # end
    #
    # def replace_components!(settings, old)
    #   components = Components.new(settings)
    #
    #   old.shutdown!(components)
    #   components.startup!(settings)
    #   components
    # end
    #
    # # Perform version check only once
    # DEPRECATED_RUBY_VERSION = Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.1')
    # private_constant :DEPRECATED_RUBY_VERSION
    #
    # RUBY_VERSION_DEPRECATION_ONLY_ONCE = Datadog::Utils::OnlyOnce.new
    # private_constant :RUBY_VERSION_DEPRECATION_ONLY_ONCE
    #
    # def ruby_version_deprecation_warning
    #   return unless DEPRECATED_RUBY_VERSION
    #
    #   RUBY_VERSION_DEPRECATION_ONLY_ONCE.run do
    #     Datadog.logger.warn(
    #       "Support for Ruby versions < 2.1 in dd-trace-rb is DEPRECATED.\n" \
    #       "Last version to support Ruby < 2.1 will be 0.49.x, which will only receive critical bugfixes.\n" \
    #       'Support for Ruby versions < 2.1 will be REMOVED in version 0.50.0.'
    #     )
    #   end
    # end
  end
end

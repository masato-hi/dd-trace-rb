require 'forwardable'
require 'ddtrace/configuration/pin_setup'
require 'ddtrace/configuration/settings'
require 'ddtrace/configuration/components'
require 'ddtrace/utils/only_once'

module Datadog
  # Configuration provides a unique access point for configurations
  # TODO: rename to {Glue}, as this is the binding of the {Runtime}
  # and the global tracer state in the host application. It manages
  # lifecycle.
  module Configuration # rubocop:disable Metrics/ModuleLength
    extend Forwardable

    attr_reader :configuration

    def self.extended(base)
      base.send(:initialize_configuration)
    end

    # TODO: moved to runtime
    # def configure(target = configuration, opts = {})
    #   ruby_version_deprecation_warning
    #
    #   if target.is_a?(Settings)
    #     yield(target) if block_given?
    #
    #     # @components = (
    #     #   if @components
    #     #     replace_components!(target, @components)
    #     #   else
    #     #     build_components(target)
    #     #   end
    #     # )
    #
    #     target
    #   else
    #     PinSetup.new(target, opts).call
    #   end
    # end

    # TODO: moved to runtime
    # def_delegators \
    #   :components,
    #   :health_metrics,
    #   :logger,
    #   :profiler,
    #   :runtime_metrics,
    #   :tracer,

    # Gracefully shuts down all components.
    #
    # Components will still respond to method calls as usual,
    # but might not internally perform their work after shutdown.
    #
    # This avoids errors being raised across the host application
    # during shutdown, while allowing for graceful decommission of resources.
    #
    # Components won't be automatically reinitialized after a shutdown.
    # TODO: moved to runtime
    # def shutdown!
    #   @components.shutdown! if @components
    # end

    protected

    attr_reader :components

    private

    def initialize_configuration
      @configuration = Settings.new
      @components = nil # TODO: build_components(@configuration)
    end

    # Gracefully shuts down the tracer and disposes of component references,
    # allowing execution to start anew.
    #
    # In contrast with +#shutdown!+, components will be automatically
    # reinitialized after a reset.
    #
    # Used internally to ensure a clean environment between test runs.
    def reset!
      @components.shutdown! if @components
      # @components = nil
      configuration.reset!
      # @configuration = nil
    end

    def build_components(settings)
      components = Components.new(settings)
      components.startup!(settings)
      components
    end

    def replace_components!(settings, old)
      components = Components.new(settings)

      old.shutdown!(components)
      components.startup!(settings)
      components
    end

    # Perform version check only once
    DEPRECATED_RUBY_VERSION = Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.1')
    private_constant :DEPRECATED_RUBY_VERSION

    RUBY_VERSION_DEPRECATION_ONLY_ONCE = Datadog::Utils::OnlyOnce.new
    private_constant :RUBY_VERSION_DEPRECATION_ONLY_ONCE

    def ruby_version_deprecation_warning
      return unless DEPRECATED_RUBY_VERSION

      RUBY_VERSION_DEPRECATION_ONLY_ONCE.run do
        Datadog.logger.warn(
          "Support for Ruby versions < 2.1 in dd-trace-rb is DEPRECATED.\n" \
          "Last version to support Ruby < 2.1 will be 0.49.x, which will only receive critical bugfixes.\n" \
          'Support for Ruby versions < 2.1 will be REMOVED in version 0.50.0.'
        )
      end
    end
  end
end

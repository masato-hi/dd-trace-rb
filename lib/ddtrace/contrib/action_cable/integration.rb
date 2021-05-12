require 'ddtrace/contrib/integration'
require 'ddtrace/contrib/action_cable/configuration/settings'
require 'ddtrace/contrib/action_cable/patcher'
require 'ddtrace/contrib/rails/utils'

module Datadog
  module Contrib
    module ActionCable
      # Description of ActionCable integration
      class Integration
        include Contrib::Integration

        MINIMUM_VERSION = Gem::Version.new('5.0.0')

        Do we have to load configuration early?
        What if we get a new configuration????
        Will this be registered again?
        maybe we can never get a fresh new config :'(

        or maybe we register these not in the config
        but on a separte, runtime-less object
        register_as :action_cable, auto_patch: false

        def self.version
          Gem.loaded_specs['actioncable'] && Gem.loaded_specs['actioncable'].version
        end

        def self.loaded?
          !defined?(::ActionCable).nil?
        end

        def self.compatible?
          super && version >= MINIMUM_VERSION
        end

        # enabled by rails integration so should only auto instrument
        # if detected that it is being used without rails
        def auto_instrument?
          !Datadog::Contrib::Rails::Utils.railtie_supported?
        end

        def default_configuration
          Configuration::Settings.new
        end

        def patcher
          Patcher
        end
      end
    end
  end
end

require 'spec_helper'

require_relative 'matchers'
require_relative 'resolver_helpers'
require_relative 'tracer_helpers'

require 'ddtrace' # Contrib testing requires full tracer setup

RSpec.configure do |config|
  config.include Contrib::TracerHelpers

  # Raise error when patching an integration fails.
  # This can be disabled by unstubbing +CommonMethods#on_patch_error+
  require 'ddtrace/contrib/patcher'
  config.before do
    allow_any_instance_of(Datadog::Contrib::Patcher::CommonMethods).to(receive(:on_patch_error)) { |_, e| raise e }
  end

  # Ensure tracer environment is clean before running tests.
  #
  # This is done :before and not :after because doing so after
  # can create noise for test assertions. For example:
  # +expect(Datadog).to receive(:shutdown!).once+
  config.before do
    # TODO there should be a Datadog.send(:restart)
    # that easily erases all tracer state, and creates a fresh one
    # without modifying/cleaning up stateful variables stored
    # in persistent objects (like cleaning up Datadog.@configuration).
    Datadog.send(:reset!)

    # The tracer is always initialized in production.
    # We ensure our tests run under that same environment.
    Datadog::Initialization.initialize!
  end
end

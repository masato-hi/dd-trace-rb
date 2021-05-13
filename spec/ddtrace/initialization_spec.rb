require 'ddtrace'

RSpec.describe Datadog::Initialization do
  subject(:initialization) { described_class.new(Datadog) }

  context '#initialize!' do
    subject(:initialize!) { initialization.initialize! }

    it 'invokes initialization steps' do
      expect(initialization).to receive(:start_life_cycle)
      expect(initialization).to receive(:deprecation_warnings)

      initialize!
    end
  end

  context '#start_life_cycle' do
    subject(:start_life_cycle) { initialization.start_life_cycle }

    it 'configures ddtrace' do
      expect(Datadog).to receive(:start)

      start_life_cycle
    end
  end

  context '#deprecation_warnings' do
    subject(:deprecation_warnings) { initialization.deprecation_warnings }

    context 'with a deprecated Ruby version' do
      before { skip unless Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.1') }

      it 'emits deprecation warning once' do
        expect(Datadog.logger).to receive(:warn)
                                    .with(/Support for Ruby versions < 2\.1 in dd-trace-rb is DEPRECATED/).once

        deprecation_warnings
      end
    end

    context 'with a supported Ruby version' do
      before { skip if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.1') }

      it 'emits no warnings' do
        expect(Datadog.logger).to_not receive(:warn)

        deprecation_warnings
      end
    end
  end
end
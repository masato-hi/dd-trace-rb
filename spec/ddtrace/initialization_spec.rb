require 'ddtrace'

RSpec.describe Datadog::Initialization do
  context '#initialize!' do
    subject(:initialize!) { described_class.initialize! }

    it 'invokes initialization steps' do
      expect(described_class).to receive(:initial_configuration)
      expect(described_class).to receive(:deprecation_warnings)

      initialize!
    end
  end

  context '#initial_configuration' do
    subject(:initial_configuration) { described_class.initial_configuration }

    it 'configures ddtrace' do
      expect(Datadog).to receive(:configure)

      initial_configuration
    end
  end

  context '#deprecation_warnings' do
    subject(:deprecation_warnings) { described_class.deprecation_warnings }

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
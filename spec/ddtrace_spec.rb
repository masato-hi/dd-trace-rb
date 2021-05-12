require 'ddtrace/initialization'

do tests pass?

RSpec.describe Datadog, :in_fork do
  describe 'class' do
    subject(:datadog) { described_class }

    before { require 'ddtrace' }

    describe 'behavior' do
      describe '#tracer' do
        subject { datadog.tracer }

        it { is_expected.to be_an_instance_of(Datadog::Tracer) }
      end

      describe '#registry' do
        subject { datadog.registry }

        it { is_expected.to be_an_instance_of(Datadog::Contrib::Registry) }
      end

      describe '#configuration' do
        subject { datadog.configuration }

        it { is_expected.to be_an_instance_of(Datadog::Configuration::Settings) }
      end

      describe '#configure' do
        let(:configuration) { datadog.configuration }

        it { expect { |b| datadog.configure(&b) }.to yield_with_args(configuration) }
      end
    end
  end

  describe 'initialization' do
    before do
      raise "'ddtrace' already required" if $LOADED_FEATURES.any? { |f| f.end_with?('/ddtrace.rb') }
    end

    it 'invokes the initialization procedure' do
      expect(Datadog::Initialization).to receive(:initialize!).once
      require 'ddtrace'
    end

    it 'initializes public API methods' do
      expect { Datadog.tracer.trace('test') }.to raise_error(NoMethodError)

      require 'ddtrace'

      expect(Datadog.tracer.trace('test')).to be_a(Datadog::Span)
    end
  end
end

require 'ddtrace/opentracer'
require 'datadog/statsd'

RSpec.describe 'ddtrace integration' do
  context 'graceful shutdown', :integration do
    subject(:shutdown) { Datadog.shutdown! }

    let(:start_tracer) do
      Datadog.tracer.trace('test.op') {}
    end

    def wait_for_tracer_sent
      try_wait_until { Datadog.tracer.writer.transport.stats.success > 0 }
    end

    context 'for threads' do
      let!(:original_thread_count) { thread_count }

      def thread_count
        Thread.list.count
      end

      it 'closes tracer threads' do
        start_tracer
        wait_for_tracer_sent

        shutdown

        expect(thread_count).to eq(original_thread_count)
      end
    end

    context 'for file descriptors' do
      def open_file_descriptors
        # Unix-specific way to get the current process' open file descriptors and the files (if any) they correspond to
        Dir['/dev/fd/*'].each_with_object({}) do |fd, hash|
          hash[fd] =
            begin
              File.realpath(fd)
            rescue SystemCallError # This can fail due to... reasons, and we only want it for debugging so let's ignore
              nil
            end
        end
      end

      it 'closes tracer file descriptors' do
        before_open_file_descriptors = open_file_descriptors

        start_tracer
        wait_for_tracer_sent

        shutdown

        after_open_file_descriptors = open_file_descriptors

        expect(after_open_file_descriptors.size)
          .to(
            eq(before_open_file_descriptors.size),
            lambda {
              "Open fds before: #{before_open_file_descriptors}\nOpen fds after:  #{after_open_file_descriptors}"
            }
          )
      end
    end
  end

  context 'after shutdown' do
    subject(:shutdown!) { Datadog.shutdown! }

    before do
      Datadog.configure do |c|
        c.diagnostics.health_metrics.enabled = true
      end

      shutdown!
    end

    after do
      Datadog.configuration.diagnostics.health_metrics.reset!
      Datadog.shutdown!
    end

    context 'calling public apis' do
      it 'does not error on tracing' do
        span = Datadog.tracer.trace('test')

        expect(span.finish).to be_truthy
      end

      it 'does not error on tracing with block' do
        value = Datadog.tracer.trace('test') do |span|
          expect(span).to be_a(Datadog::Span)
          :return
        end

        expect(value).to be(:return)
      end

      it 'does not error on logging' do
        expect(Datadog.logger.info('test')).to be true
      end

      it 'does not error on configuration access' do
        expect(Datadog.configuration.runtime_metrics.enabled).to be(true).or be(false)
      end

      it 'does not error on reporting health metrics', if: Datadog::Statsd::VERSION >= '5.0.0' do
        expect(Datadog.health_metrics.queue_accepted(1)).to be_truthy
      end

      it 'does not error on reporting health metrics', if: Datadog::Statsd::VERSION < '5.0.0' do
        expect(Datadog.health_metrics.queue_accepted(1)).to be_a(Integer)
      end

      context 'with OpenTracer' do
        before do
          skip 'OpenTracing not supported' unless Datadog::OpenTracer.supported?

          OpenTracing.global_tracer = Datadog::OpenTracer::Tracer.new
        end

        let(:tracer) do
          OpenTracing.global_tracer
        end

        it 'does not error on tracing' do
          span = tracer.start_span('test')

          expect { span.finish }.to_not raise_error
        end

        it 'does not error on tracing with block' do
          scope = tracer.start_span('test') do |scp|
            expect(scp).to be_a(OpenTracing::Scope)
          end

          expect(scope).to be_a(OpenTracing::Span)
        end

        it 'does not error on registered scope tracing' do
          span = tracer.start_active_span('test')

          expect { span.close }.to_not raise_error
        end

        it 'does not error on registered scope tracing with block' do
          scope = tracer.start_active_span('test') do |scp|
            expect(scp).to be_a(OpenTracing::Scope)
          end

          expect(scope).to be_a(OpenTracing::Scope)
        end
      end
    end
  end
end

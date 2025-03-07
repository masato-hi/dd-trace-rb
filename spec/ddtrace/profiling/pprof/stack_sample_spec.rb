require 'spec_helper'
require 'ddtrace/profiling/spec_helper'

require 'ddtrace/profiling'
require 'ddtrace/profiling/events/stack'
require 'ddtrace/profiling/pprof/stack_sample'

RSpec.describe Datadog::Profiling::Pprof::StackSample do
  before do
    skip 'Profiling is not supported.' unless Datadog::Profiling.supported?
  end

  subject(:converter) { described_class.new(builder, sample_type_mappings) }

  let(:builder) { Datadog::Profiling::Pprof::Builder.new }
  let(:sample_type_mappings) do
    described_class.sample_value_types.each_with_object({}) do |(key, _value), mappings|
      @index ||= 0
      mappings[key] = @index
      @index += 1
    end
  end

  let(:stack_samples) { Array.new(2) { build_stack_sample } }

  def string_id_for(string)
    builder.string_table.fetch(string)
  end

  describe '::sample_value_types' do
    subject(:sample_value_types) { described_class.sample_value_types }

    it do
      is_expected.to be_kind_of(Hash)
      is_expected.to have(2).items
    end

    describe 'contains :cpu_time_ns' do
      subject(:cpu_time_type) { sample_value_types[:cpu_time_ns] }

      it do
        is_expected.to eq(
          [
            Datadog::Ext::Profiling::Pprof::VALUE_TYPE_CPU,
            Datadog::Ext::Profiling::Pprof::VALUE_UNIT_NANOSECONDS
          ]
        )
      end
    end

    describe 'contains :wall_time_ns' do
      subject(:wall_time_type) { sample_value_types[:wall_time_ns] }

      it do
        is_expected.to eq(
          [
            Datadog::Ext::Profiling::Pprof::VALUE_TYPE_WALL,
            Datadog::Ext::Profiling::Pprof::VALUE_UNIT_NANOSECONDS
          ]
        )
      end
    end
  end

  describe '#add_events!' do
    subject(:add_events!) { converter.add_events!(stack_samples) }

    it do
      expect { add_events! }
        .to change { builder.samples.length }
        .from(0)
        .to(stack_samples.length)

      expect(builder.samples).to match_array(
        Array.new(stack_samples.length) { kind_of(Perftools::Profiles::Sample) }
      )
    end
  end

  describe '#stack_sample_group_key' do
    subject(:stack_sample_group_key) { converter.stack_sample_group_key(stack_sample) }

    let(:stack_sample) { build_stack_sample }

    it { is_expected.to be_kind_of(Integer) }

    context 'given stack samples' do
      let(:first_key) { converter.stack_sample_group_key(first) }
      let(:second_key) { converter.stack_sample_group_key(second) }

      let(:thread_id) { 1 }
      let(:trace_id) { 2 }
      let(:span_id) { 3 }
      let(:stack) { Thread.current.backtrace_locations }

      context 'with identical threads, stacks, trace and span IDs' do
        let(:first) { build_stack_sample(stack, thread_id, trace_id, span_id) }
        let(:second) { build_stack_sample(stack, thread_id, trace_id, span_id) }

        before { expect(first.frames).to eq(second.frames) }

        it { expect(first_key).to eq(second_key) }
      end

      context 'with identical threads and stacks but different' do
        context 'trace IDs' do
          let(:other_trace_id) { 3 }
          let(:first) { build_stack_sample(stack, thread_id, trace_id, span_id) }
          let(:second) { build_stack_sample(stack, thread_id, other_trace_id, span_id) }

          before { expect(first.frames).to eq(second.frames) }

          it { expect(first_key).to_not eq(second_key) }
        end

        context 'span IDs' do
          let(:other_span_id) { 4 }
          let(:first) { build_stack_sample(stack, thread_id, trace_id, span_id) }
          let(:second) { build_stack_sample(stack, thread_id, trace_id, other_span_id) }

          before { expect(first.frames).to eq(second.frames) }

          it { expect(first_key).to_not eq(second_key) }
        end
      end

      context 'with identical threads and different' do
        context 'stacks' do
          let(:first) { build_stack_sample(nil, thread_id, trace_id, span_id) }
          let(:second) { build_stack_sample(nil, thread_id, trace_id, span_id) }

          before { expect(first.frames).to_not eq(second.frames) }

          it { expect(first_key).to_not eq(second_key) }
        end

        context 'stack lengths' do
          let(:first) do
            Datadog::Profiling::Events::StackSample.new(
              nil,
              stack,
              stack.length,
              thread_id,
              trace_id,
              span_id,
              rand(1e9),
              rand(1e9)
            )
          end

          let(:second) do
            Datadog::Profiling::Events::StackSample.new(
              nil,
              stack,
              stack.length + 1,
              thread_id,
              trace_id,
              span_id,
              rand(1e9),
              rand(1e9)
            )
          end

          before { expect(first.total_frame_count).to_not eq(second.total_frame_count) }

          it { expect(first_key).to_not eq(second_key) }
        end
      end

      context 'with identical stacks and different thread IDs' do
        let(:first) { build_stack_sample(stack, 1) }
        let(:second) { build_stack_sample(stack, 2) }

        before do
          expect(first.frames).to eq(second.frames)
          expect(first.thread_id).to_not eq(second.thread_id)
        end

        it { expect(first_key).to_not eq(second_key) }
      end
    end
  end

  describe '#build_samples' do
    subject(:build_samples) { converter.build_samples(stack_samples) }

    let(:stack_samples) { [first, second] }

    context 'given stack samples' do
      let(:thread_id) { 1 }
      let(:trace_id) { 2 }
      let(:span_id) { 3 }
      let(:stack) { Thread.current.backtrace_locations }

      shared_examples_for 'independent stack samples' do
        it 'returns a Perftools::Profiles::Sample for each stack sample' do
          is_expected.to be_kind_of(Array)
          is_expected.to have(2).items
          is_expected.to include(kind_of(Perftools::Profiles::Sample))

          expect(build_samples[0].value).to eq(
            [
              first.cpu_time_interval_ns,
              first.wall_time_interval_ns
            ]
          )
          expect(build_samples[1].value).to eq(
            [
              second.cpu_time_interval_ns,
              second.wall_time_interval_ns
            ]
          )
        end
      end

      context 'with identical threads, stacks, trace and span IDs' do
        let(:first) { build_stack_sample(stack, thread_id, trace_id, span_id) }
        let(:second) { build_stack_sample(stack, thread_id, trace_id, span_id) }

        before { expect(first.frames).to eq(second.frames) }

        it 'returns one Perftools::Profiles::Sample' do
          is_expected.to be_kind_of(Array)
          is_expected.to have(1).item
          is_expected.to include(kind_of(Perftools::Profiles::Sample))

          expect(build_samples[0].value)
            .to eq(
              [
                first.cpu_time_interval_ns + second.cpu_time_interval_ns,
                first.wall_time_interval_ns + second.wall_time_interval_ns
              ]
            )
        end
      end

      context 'with identical threads and different' do
        context 'stacks' do
          let(:first) { build_stack_sample(nil, thread_id, trace_id, span_id) }
          let(:second) { build_stack_sample(nil, thread_id, trace_id, span_id) }

          before { expect(first.frames).to_not eq(second.frames) }

          it_behaves_like 'independent stack samples'
        end

        context 'stack lengths' do
          let(:first) do
            Datadog::Profiling::Events::StackSample.new(
              nil,
              stack,
              stack.length,
              thread_id,
              trace_id,
              span_id,
              rand(1e9),
              rand(1e9)
            )
          end

          let(:second) do
            Datadog::Profiling::Events::StackSample.new(
              nil,
              stack,
              stack.length + 1,
              thread_id,
              trace_id,
              span_id,
              rand(1e9),
              rand(1e9)
            )
          end

          before { expect(first.total_frame_count).to_not eq(second.total_frame_count) }

          it_behaves_like 'independent stack samples'
        end
      end

      context 'with identical stacks and different thread IDs' do
        let(:first) { build_stack_sample(stack, 1) }
        let(:second) { build_stack_sample(stack, 2) }

        before do
          expect(first.frames).to eq(second.frames)
          expect(first.thread_id).to_not eq(second.thread_id)
        end

        it_behaves_like 'independent stack samples'
      end
    end
  end

  describe '#build_sample' do
    subject(:build_sample) { converter.build_sample(stack_sample, values) }

    let(:stack_sample) { build_stack_sample }
    let(:values) { [stack_sample.wall_time_interval_ns] }

    context 'builds a Sample' do
      it do
        is_expected.to be_kind_of(Perftools::Profiles::Sample)
        is_expected.to have_attributes(
          location_id: array_including(kind_of(Integer)),
          value: values,
          label: array_including(kind_of(Perftools::Profiles::Label))
        )
      end

      context 'whose locations' do
        subject(:locations) { build_sample.location_id }

        it { is_expected.to have(stack_sample.frames.length).items }

        it 'each map to a Location on the profile' do
          locations.each do |id|
            expect(builder.locations.messages[id - 1])
              .to be_kind_of(Perftools::Profiles::Location)
          end
        end
      end

      context 'whose labels' do
        subject(:locations) { build_sample.label }

        it { is_expected.to have(3).items }
      end
    end
  end

  describe '#build_sample_values' do
    subject(:build_sample_values) { converter.build_sample_values(stack_sample) }

    let(:stack_sample) { build_stack_sample }

    it do
      is_expected.to eq(
        [
          stack_sample.cpu_time_interval_ns,
          stack_sample.wall_time_interval_ns
        ]
      )
    end
  end

  describe '#build_sample_labels' do
    subject(:build_sample_labels) { converter.build_sample_labels(stack_sample) }

    let(:stack_sample) { build_stack_sample }

    shared_examples_for 'contains thread ID label' do |index = 0|
      subject(:thread_id_label) { build_sample_labels[index] }

      it { is_expected.to be_kind_of(Perftools::Profiles::Label) }

      it do
        is_expected.to have_attributes(
          key: string_id_for(Datadog::Ext::Profiling::Pprof::LABEL_KEY_THREAD_ID),
          str: string_id_for(stack_sample.thread_id.to_s)
        )
      end
    end

    shared_examples_for 'contains trace ID label' do |index = 1|
      subject(:trace_id_label) { build_sample_labels[index] }

      it { is_expected.to be_kind_of(Perftools::Profiles::Label) }

      it do
        is_expected.to have_attributes(
          key: string_id_for(Datadog::Ext::Profiling::Pprof::LABEL_KEY_TRACE_ID),
          str: string_id_for(stack_sample.trace_id.to_s)
        )
      end
    end

    shared_examples_for 'contains span ID label' do |index = 2|
      subject(:span_id_label) { build_sample_labels[index] }

      it { is_expected.to be_kind_of(Perftools::Profiles::Label) }

      it do
        is_expected.to have_attributes(
          key: string_id_for(Datadog::Ext::Profiling::Pprof::LABEL_KEY_SPAN_ID),
          str: string_id_for(stack_sample.span_id.to_s)
        )
      end
    end

    context 'when thread ID is set' do
      let(:stack_sample) do
        instance_double(
          Datadog::Profiling::Events::StackSample,
          thread_id: thread_id,
          trace_id: trace_id,
          span_id: span_id
        )
      end

      let(:thread_id) { rand(1e9) }

      context 'when trace and span IDs are' do
        context 'set' do
          let(:trace_id) { rand(1e9) }
          let(:span_id) { rand(1e9) }

          it do
            is_expected.to be_kind_of(Array)
            is_expected.to have(3).items
          end

          it_behaves_like 'contains thread ID label'
          it_behaves_like 'contains trace ID label'
          it_behaves_like 'contains span ID label'
        end

        context '0' do
          let(:trace_id) { 0 }
          let(:span_id) { 0 }

          it do
            is_expected.to be_kind_of(Array)
            is_expected.to have(1).item
          end

          it_behaves_like 'contains thread ID label'
        end

        context 'nil' do
          let(:trace_id) { nil }
          let(:span_id) { nil }

          it do
            is_expected.to be_kind_of(Array)
            is_expected.to have(1).item
          end

          it_behaves_like 'contains thread ID label'
        end
      end
    end
  end
end

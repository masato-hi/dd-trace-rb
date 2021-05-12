module TestHelpers
  module_function

  # Integration tests are normally expensive (time-wise or resource-wise).
  # They run in CI by default.
  def run_integration_tests?
    ENV['TEST_DATADOG_INTEGRATION']
  end

  module RSpec
    # RSpec extension to allow for declaring integration tests
    # using example group parameters:
    #
    # ```ruby
    # describe 'end-to-end foo test', :integration do
    # ...
    # end
    # ```
    module Integration
      def self.included(base)
        base.class_exec do
          before do
            unless run_integration_tests?
              skip('Integration tests can be enabled by setting the environment variable `TEST_DATADOG_INTEGRATION=1`')
            end
          end
        end
      end
    end

    module InFork
      module Example
        def initialize(example_group_class, description, user_metadata, example_block=nil)
          new_example_block = if example_block && example_group_class.metadata[:in_fork]
                                ->(self_) {
                                  expect_in_fork { instance_exec(self_, &example_block) }
                                }
                              else
                                example_block
                              end

          super(example_group_class, description, user_metadata, new_example_block)
        end
      end

      ::RSpec::Core::Example.send(:prepend, Example)

      # module ExampleInFork
      #   def instance_exec(*args)
      #     expect_in_fork do
      #       super
      #     end
      #   end
      # end
      #
      # def self.included(base)
      #   base.class_exec do
      #     before do
      #       @_exec_in_fork = true
      #     end
      #   end
      # end
    end
  end
end

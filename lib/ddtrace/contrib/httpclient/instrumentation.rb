require 'ddtrace/ext/app_types'
require 'ddtrace/ext/http'
require 'ddtrace/ext/net'
require 'ddtrace/ext/distributed'
require 'ddtrace/contrib/analytics'
require 'ddtrace/propagation/http_propagator'
require 'ddtrace/contrib/http_annotation_helper'

module Datadog
  module Contrib
    module Httpclient
      # Instrumentation for Httpclient
      module Instrumentation
        def self.included(base)
          base.send(:prepend, InstanceMethods)
        end

        # Instance methods for configuration
        module InstanceMethods
          include Datadog::Contrib::HttpAnnotationHelper

          def do_get_block(req, proxy, conn, &block)
            host = req.header.request_uri.host
            request_options = datadog_configuration(host)
            pin = datadog_pin(request_options)

            return super unless pin && pin.tracer

            pin.tracer.trace(Ext::SPAN_REQUEST, on_error: method(:annotate_span_with_error!)) do |span|
              begin
                request_options[:service_name] = pin.service_name
                span.service = service_name(host, request_options)
                span.span_type = Datadog::Ext::HTTP::TYPE_OUTBOUND

                if pin.tracer.enabled && !should_skip_distributed_tracing?(pin)
                  Datadog::HTTPPropagator.inject!(span.context, req.header)
                end

                # Add additional request specific tags to the span.
                annotate_span_with_request!(span, req, request_options)
              rescue StandardError => e
                logger.error("error preparing span for httpclient request: #{e}, Source: #{e.backtrace}")
              ensure
                res = super
              end

              # Add additional response specific tags to the span.
              annotate_span_with_response!(span, res)

              res
            end
          end

          private

          def annotate_span_with_request!(span, req, req_options)
            http_method = req.header.request_method.upcase
            uri = req.header.request_uri

            span.resource = http_method
            span.set_tag(Datadog::Ext::HTTP::METHOD, http_method)
            span.set_tag(Datadog::Ext::HTTP::URL, uri.path)
            span.set_tag(Datadog::Ext::NET::TARGET_HOST, uri.host)
            span.set_tag(Datadog::Ext::NET::TARGET_PORT, uri.port)

            # Tag as an external peer service
            span.set_tag(Datadog::Ext::Integration::TAG_PEER_SERVICE, span.service)

            set_analytics_sample_rate(span, req_options)
          end

          def annotate_span_with_response!(span, response)
            return unless response && response.status

            span.set_tag(Datadog::Ext::HTTP::STATUS_CODE, response.status)

            case response.status.to_i
            when 400...599
              span.set_error(["Error #{response.status}", response.body])
            end
          end

          def annotate_span_with_error!(span, error)
            span.set_error(error)
          end

          def datadog_pin(config = Datadog.configuration[:httprb])
            service = config[:service_name]
            tracer = config[:tracer]

            @datadog_pin ||= Datadog::Pin.new(
              service,
              app: Ext::APP,
              app_type: Datadog::Ext::HTTP::TYPE_OUTBOUND,
              tracer: -> { config[:tracer] }
            )

            if @datadog_pin.service_name == default_datadog_pin.service_name && @datadog_pin.service_name != service
              @datadog_pin.service = service
            end
            if @datadog_pin.tracer == default_datadog_pin.tracer && @datadog_pin.tracer != tracer
              @datadog_pin.tracer = tracer
            end

            @datadog_pin
          end

          def default_datadog_pin
            config = Datadog.configuration[:httpclient]
            service = config[:service_name]

            @default_datadog_pin ||= Datadog::Pin.new(
              service,
              app: Ext::APP,
              app_type: Datadog::Ext::HTTP::TYPE_OUTBOUND,
              tracer: -> { config[:tracer] }
            )
          end

          def datadog_configuration(host = :default)
            Datadog.configuration[:httpclient, host]
          end

          def analytics_enabled?(request_options)
            Contrib::Analytics.enabled?(request_options[:analytics_enabled])
          end

          def logger
            Datadog.logger
          end

          def should_skip_distributed_tracing?(pin)
            return !pin.config[:distributed_tracing] if pin.config && pin.config.key?(:distributed_tracing)

            !Datadog.configuration[:httpclient][:distributed_tracing]
          end

          def set_analytics_sample_rate(span, request_options)
            return unless analytics_enabled?(request_options)

            Contrib::Analytics.set_sample_rate(span, request_options[:analytics_sample_rate])
          end
        end
      end
    end
  end
end

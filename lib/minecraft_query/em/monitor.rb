require 'minecraft_query/em'
require 'eventmachine'

module MinecraftQuery
  module EM
    class Monitor
      class Error < Exception; end
      class TimeoutError < Error; end

      module Watcher
        def initialize(monitor)
          @monitor = monitor
          @is_watching = true
        end

        def notify_readable
          begin
            result = @monitor.client.recv
          rescue Exception => e
            @monitor.fail e
          else
            @monitor.succeed result
          end
        end

        def watching?
          @is_watching
        end

        def unbind
          @is_watching = false
        end
      end

      attr_reader :client
      attr_reader :last_time

      def initialize(client, rate: 0.5, on_error: nil, on_succeed: nil, &block)
        @client = client
        @rate = rate
        @on_succeed = on_succeed || block
        @on_error = on_error
      end

      def start
        @watch = ::EM.watch client.send(:socket), Watcher, self
        @watch.notify_readable = true
        client.send_handshake_query
        start_timers
      end

      def stop
        unwatch
        cancel_timers
      end

      def succeed(result)
        @last_time = Time.now
        on_succeed.call result if on_succeed
      end

      def fail(e)
        on_error.call e if on_error
      end

      private

        attr_reader :on_succeed, :on_error
        attr_reader :rate

        def unwatch
          @watch.detach if @watch && @watch.watching?
        end

        def start_timers
          @timer = ::EM.add_periodic_timer(1) do
            client.send_full_stat_query
            client.send_basic_stat_query
          end

          @handshake_timer = ::EM.add_periodic_timer(30) do
            client.send_handshake_query
          end

          @timeout_timer = ::EM.add_periodic_timer(client.timeout) do
            if Time.now - last_time >= client.timeout
              self.fail TimeoutError
              client.send_handshake_query
            end
          end
        end

        def cancel_timers
          if @timer
            @timer.cancel
            @timer = nil
          end

          if @handshake_timer
            @handshake_timer.cancel
            @handshake_timer = nil
          end

          if @timeout_timer
            @timeout_timer.cancel
            @timeout_timer = nil
          end
        end
    end
  end
end
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
            @monitor.send :on_error, e
          else
            @monitor.send :on_success, result
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

      def initialize(client, rate: 0.5)
        @client = client
        @rate = rate
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

      private

        attr_reader :rate

        def on_success(result)
          @last_time = Time.now
        end

        def on_error(e)
          client.reset! if e.is_a? MinecraftQuery::Client::ConnectionError
        end

        def on_send_error(e)
          client.reset! if e.is_a? MinecraftQuery::Client::ConnectionError
        end

        def unwatch
          @watch.detach if @watch && @watch.watching?
        end

        def start_timers
          @timer = ::EM.add_periodic_timer(1) do
            safe_send do
              if client.protocol.challenge_token
                client.send_full_stat_query
                client.send_basic_stat_query
              else
                client.send_handshake
              end
            end
          end

          @handshake_timer = ::EM.add_periodic_timer(30) do
            safe_send { client.send_handshake_query }
          end

          @timeout_timer = ::EM.add_periodic_timer(client.timeout) do
            if Time.now - last_time >= client.timeout
              on_error TimeoutError.new
              safe_send { client.send_handshake_query }
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

        def safe_send
          yield
        rescue Exception => e
          on_send_error e
          client.reset!
        end
    end
  end
end

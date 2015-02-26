require 'minecraft_query'
require 'eventmachine'

module MinecraftQuery
  module EM
    class Client < ::MinecraftQuery::Client
      module Watcher
        def initialize(client, deferrable)
          @client = client
          @deferrable = deferrable
          @is_watching = true
          @timer = ::EM::Timer.new(client.timeout) do
            detach if watching?
            @deferrable.fail Client::TimeoutError.new
            @timer = nil
          end
        end

        def notify_readable
          detach
          begin
            result = @client.recv
          rescue Exception => e
            @deferrable.fail e
          else
            @deferrable.succeed result
          ensure
            cancel_timer
          end
        end

        def watching?
          @is_watching
        end

        def unbind
          @is_watching = false
        end

        def cancel_timer
          if @timer
            @timer.cancel
            @timer = nil
          end
        end
      end

      def close
        unwatch
        super
      end

      def wrap
        if ::EM.reactor_running?
          deferrable = ::EM::DefaultDeferrable.new
          begin
            @socket = nil
            yield
          rescue Exception => e
            ::EM.next_tick do
              deferrable.fail e
            end
          else
            @watch = ::EM.watch(socket, Watcher, self, deferrable)
            @watch.notify_readable = true
          end
          deferrable
        else
          super(&proc)
        end
      end

      private

        def unwatch
          @watch.detach if @watch && @watch.watching?
        end
    end
  end
end

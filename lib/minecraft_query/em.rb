require 'minecraft_query'
require 'eventmachine'


module MinecraftQuery
  module EM
    class Client < ::MinecraftQuery::Client

      class Error < MinecraftQuery::Client::Error; end
      class PreviousRequestNotFinished < Error; end
      class MonitorAlreadyStarted < Error; end

      def close
        terminate_request
        stop_monitor
        super
      end

      def wrap
        if ::EM.reactor_running?
          raise PreviousRequestNotFinished if waiting_for_response?
          deferrable = ::EM::DefaultDeferrable.new
          begin
            yield
          rescue Exception => e
            ::EM.next_tick do
              deferrable.fail e
            end
          else
            @request_watch = ::EM.watch socket, RequestWatcher, self, deferrable
            @request_watch.notify_readable = true
          end
          deferrable
        else
          super(&proc)
        end
      end

      def start_monitor(callback=nil, errback=nil, &block)
        raise PreviousRequestNotFinished if waiting_for_response?
        unless monitoring?
          callback ||= block
          @monitor_watch = ::EM.watch socket, MonitorWatcher, self, callback, errback
          @monitor_watch.notify_readable = true
        end
      end

      def stop_monitor
        if monitoring?
          @monitor_watch.detach
        end
      end

      def monitoring?
        @monitor_watch && @monitor_watch.watching?
      end

      def waiting_for_response?
        @request_watch && @request_watch.watching?
      end

      def terminate_request
        @request_watch.detach if watching_request?
      end
    end
  end
end

require 'minecraft_query/em/request_watcher'
require 'minecraft_query/em/monitor_watcher'

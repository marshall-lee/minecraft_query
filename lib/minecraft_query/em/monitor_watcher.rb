require 'minecraft_query/em'

module MinecraftQuery
  module EM
    module Client::MonitorWatcher
      def initialize(client, callback, errback)
        @client = client
        @is_watching = true
        @callback = callback
        @errback = errback
      end

      def notify_readable
        begin
          @callback.call @client.recv if @callback
        rescue Exception => e
          @errback.call e if @errback
        end
      end

      def watching?
        @is_watching
      end

      def unbind
        @is_watching = false
      end
    end
  end
end

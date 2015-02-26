require 'minecraft_query/em'

module MinecraftQuery
  module EM
    module Client::RequestWatcher
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
  end
end

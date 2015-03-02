require 'timeout'

module MinecraftQuery
  class Client
    attr_reader :protocol
    attr_reader :host, :port
    attr_reader :timeout
    attr_reader :last_basic_stat, :last_full_stat

    class Error < Exception; end
    class TimeoutError < Error; end
    class ConnectionError < Error; end

    def initialize(host, port: 25565, timeout: 1)
      @protocol = Protocol.new
      @host     = host
      @port     = port
      @timeout  = timeout
    end

    def handshake
      wrap { send_handshake_query }
    end

    def basic_stat
      wrap { send_basic_stat_query }
    end

    def full_stat
      wrap { send_full_stat_query }
    end

    def recv
      response = protocol.parse_response! socket.recv(65536)
      case response
      when Protocol::BasicStatResponse
        @last_basic_stat = response
      when Protocol::FullStatResponse
        @last_full_stat = response
      end
      response
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH
      raise ConnectionError
    end

    def close
      socket.close
    end

    def reset!
      protocol.generate_session_id!
    end

    def send_handshake_query
      send protocol.handshake_query
    end

    def send_basic_stat_query
      send protocol.basic_stat_query
    end

    def send_full_stat_query
      send protocol.full_stat_query
    end

    private

      def socket
        unless @socket
          @socket = UDPSocket.new
          @socket.connect host, port
        end
        @socket
      end

      def send(data)
        socket.send data, 0
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH
        raise ConnectionError
      end

      def wrap
        Timeout.timeout(timeout) { yield; recv }
      rescue Timeout::Error
        raise TimeoutError
      end
  end
end

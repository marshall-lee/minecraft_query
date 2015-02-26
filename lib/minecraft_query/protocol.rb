require 'ostruct'
require 'ipaddr'

module MinecraftQuery
  class Protocol
    MAGIC_BYTES = [0xFE, 0xFD].freeze
    HANDSHAKE   = [*MAGIC_BYTES, 9].pack('C*').freeze
    STAT        = [*MAGIC_BYTES, 0].pack('C*').freeze
    PADDING     = [0].pack('N').freeze
    FULL_STAT_PADDING1 = "splitnum\0\x80\0".force_encoding(Encoding::ASCII_8BIT).freeze
    FULL_STAT_PADDING2 = "\1player_\0\0".force_encoding(Encoding::ASCII_8BIT).freeze
    NULL        = "\0".force_encoding(Encoding::ASCII_8BIT).freeze

    class Error < Exception; end
    class InvalidChallengeTokenError < Error; end
    class InvalidTypeError < Error; end
    class InvalidSessionIdError < Error; end
    class InvalidPaddingError < Error; end

    class ResponseString < String
      def slice_to_null!
        slice!(0..(index NULL))[0...-1]
      end

      def slice_null_terminated_array!
        ary = []
        until self[0] == NULL
          ary << slice_to_null!
        end
        slice! 0
        ary
      end

      def slice_null_terminated_hash!
        hash = {}
        until self[0] == NULL
          key   = slice_to_null!
          value = slice_to_null!
          hash[key] = value
        end
        slice! 0
        hash
      end
    end

    class HandshakeResponse < Struct.new :challenge_token
      alias_method :to_hash, :to_h
    end

    class BasicStatResponse < Struct.new :motd,
                                         :gametype,
                                         :map,
                                         :numplayers,
                                         :maxplayers,
                                         :hostport,
                                         :hostip
      alias_method :to_hash, :to_h
    end

    class FullStatResponse < Struct.new :properties, :players
      alias_method :to_hash, :to_h
    end

    def initialize
      generate_session_id!
    end

    attr_reader :session_id, :challenge_token

    def generate_session_id!
      self.session_id = rand(0x100000000) & 0x0F0F0F0F
    end

    def session_id=(new_session_id)
      if new_session_id != session_id
        @session_id_str = [new_session_id].pack('N')
        @session_id = new_session_id
        @challenge_token = nil
      end
    end

    def challenge_token=(new_challenge_token)
      if new_challenge_token != challenge_token
        @challenge_token_str = [new_challenge_token].pack('N')
        @challenge_token = new_challenge_token
      end
    end

    def handshake_query
      HANDSHAKE + @session_id_str
    end

    def basic_stat_query
      raise InvalidChallengeTokenError unless challenge_token
      STAT + @session_id_str + @challenge_token_str
    end

    def full_stat_query
      raise InvalidChallengeTokenError unless challenge_token
      STAT + @session_id_str + @challenge_token_str + PADDING
    end

    def parse_response!(data)
      type, session_id = data.unpack('CN')

      raise InvalidSessionIdError if session_id != self.session_id

      rest = ResponseString.new data[5..-1]

      case type
      when 9
        self.challenge_token = rest.to_i
        HandshakeResponse.new challenge_token
      when 0
        unless rest[0, 11] == FULL_STAT_PADDING1
          # basic stat response
          motd       = rest.slice_to_null!
          gametype   = rest.slice_to_null!
          map        = rest.slice_to_null!
          numplayers = rest.slice_to_null!.to_i
          maxplayers = rest.slice_to_null!.to_i
          hostport   = rest.slice!(0, 2).unpack('v').first
          hostip     = IPAddr.new rest.slice_to_null!
          BasicStatResponse.new motd, gametype, map, numplayers, maxplayers, hostport, hostip
        else
          # full stat response
          rest.slice! 0, 11
          properties = OpenStruct.new(rest.slice_null_terminated_hash!)
          properties.numplayers = properties.numplayers.to_i    if properties.respond_to? :numplayers
          properties.maxplayers = properties.maxplayers.to_i    if properties.respond_to? :maxplayers
          properties.hostport   = properties.hostport.to_i      if properties.respond_to? :hostport
          properties.hostip     = IPAddr.new(properties.hostip) if properties.respond_to? :hostip
          raise InvalidPaddingError if rest[0, 10] != FULL_STAT_PADDING2
          rest.slice! 0, 10
          players = rest.slice_null_terminated_array!
          FullStatResponse.new(properties, players)
        end
      else
        raise InvalidTypeError
      end
    end
  end
end

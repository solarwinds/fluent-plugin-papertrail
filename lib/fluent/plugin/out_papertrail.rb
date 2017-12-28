module Fluent
  class Papertrail < Fluent::BufferedOutput
    attr_accessor :socket

    # if left empty in fluent config these config_param's will error
    config_param :papertrail_host, :string
    config_param :papertrail_port, :integer
    # overriding default flush_interval (60 sec) from Fluent::BufferedOutput
    config_param :flush_interval, :time, default: 1

    # register as 'papertrail' fluent plugin
    Fluent::Plugin.register_output('papertrail', self)

    def initialize
      super
      require 'syslog_protocol'
    end

    def configure(conf)
      super
      @socket = create_socket(@papertrail_host, @papertrail_port)
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each {|(tag, time, record)|
        packet = create_packet(tag, time, record)
        send_to_papertrail(packet)
      }
    end

    def create_socket(host, port)
      log.info "initializing tcp socket for #{host}:#{port}"
      begin
        socket = TCPSocket.new(host, port)
        log.debug "enabling ssl for socket #{host}:#{port}"
        ssl = OpenSSL::SSL::SSLSocket.new(socket)
        # close tcp and ssl socket when either fails
        ssl.sync_close = true
        # initiate SSL/TLS handshake with server
        ssl.connect
      rescue => e
        log.warn "failed to create tcp socket #{host}:#{port}: #{e}"
        ssl = nil
      end
      ssl
    end

    def create_packet(tag,time,record)
      # construct syslog packet from fluent record
      packet = SyslogProtocol::Packet.new
      packet.hostname = record['hostname']
      packet.facility = record['facility']
      packet.severity = record['severity']
      packet.tag      = record['program']
      packet.content  = record['message']
      packet.time     = time ? Time.at(time) : Time.now
      packet
    end

    def send_to_papertrail(packet)
      # recreate the socket if it's nil -- see below
      unless @socket
        @socket = create_socket(@papertrail_host, @papertrail_port)
      end

      if @socket
        begin
          # send it
          @socket.puts packet.assemble
        rescue => e
          log.error "connection error for #{@papertrail_host}:#{@papertrail_port}: #{e}"
          # socket failed, reset to nil to recreate for the next write
          @socket = nil
        end
      else
        log.warn "socket is nil -- failed to send: #{packet.assemble}"
      end
    end
  end
end
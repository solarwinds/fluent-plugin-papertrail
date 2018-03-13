require 'syslog_protocol'

module Fluent
  class Papertrail < Fluent::BufferedOutput
    class SocketFailureError < StandardError; end
    attr_accessor :socket

    # if left empty in fluent config these config_param's will error
    config_param :papertrail_host, :string
    config_param :papertrail_port, :integer
    # default to ENV['FLUENT_HOSTNAME'] or :default_hostname if no hostname in record
    config_param :default_hostname, :string, default: 'unidentified'
    # overriding default flush_interval (60 sec) from Fluent::BufferedOutput
    config_param :flush_interval, :time, default: 1


    # register as 'papertrail' fluent plugin
    Fluent::Plugin.register_output('papertrail', self)

    def configure(conf)
      super
      @socket = create_socket(@papertrail_host, @papertrail_port)
      @default_hostname = ENV['FLUENT_HOSTNAME'] || @default_hostname
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
      packet.hostname = record['hostname'] || @default_hostname
      packet.facility = record['facility'] || 'local0'
      packet.severity = record['severity'] || 'info'
      packet.tag      = record['program'] || tag
      packet.content  = record['message']
      packet.time     = time ? Time.at(time) : Time.now
      packet
    end

    def send_to_papertrail(packet)
      # recreate the socket if it's nil -- see below
      @socket ||= create_socket(@papertrail_host, @papertrail_port)

      papertrail_addr = "#{@papertrail_host}:#{@papertrail_port}"

      if @socket.nil?
        err_msg = "Unable to create socket with #{papertrail_addr}"
        log.error err_msg
        raise SocketFailureError, err_msg
      else
        begin
          # send it
          @socket.puts packet.assemble
        rescue => e
          err_msg = "Error writing to #{papertrail_addr}: #{e}"
          log.error err_msg
          # socket failed, reset to nil to recreate for the next write
          @socket = nil
          raise SocketFailureError, err_msg, e.backtrace
        end
      end
    end
  end
end
require 'syslog_protocol'

module Fluent
  class Papertrail < Fluent::BufferedOutput
    class SocketFailureError < StandardError; end
    attr_accessor :sockets

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
      # create initial sockets hash and socket based on config param
      @sockets = {}
      socket_key = "#{@papertrail_host}:#{@papertrail_port}"
      @sockets[socket_key] = create_socket(@papertrail_host, @papertrail_port)
      # redefine default hostname if it's been passed in through ENV
      @default_hostname = ENV['FLUENT_HOSTNAME'] || @default_hostname
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each {|(tag, time, record)|
        socket_key = pick_socket(record)
        packet = create_packet(tag, time, record)
        send_to_papertrail(packet, socket_key)
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

    def create_packet(tag, time, record)
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

    def pick_socket(record)
      # if kubernetes pod has papertrail destination as annotation, use it
      if record.dig('kubernetes', 'annotations', 'solarwinds_io/papertrail_host') && \
         record.dig('kubernetes', 'annotations', 'solarwinds_io/papertrail_port')
        host = record['kubernetes']['annotations']['solarwinds_io/papertrail_host']
        port = record['kubernetes']['annotations']['solarwinds_io/papertrail_port']
      # else if kubernetes namespace has papertrail destination as annotation, use it
      elsif record.dig('kubernetes', 'namespace_annotations', 'solarwinds_io/papertrail_host') && \
            record.dig('kubernetes', 'namespace_annotations', 'solarwinds_io/papertrail_port')
        host = record['kubernetes']['namespace_annotations']['solarwinds_io/papertrail_host']
        port = record['kubernetes']['namespace_annotations']['solarwinds_io/papertrail_port']
      # else use pre-configured destination
      else
        host = @papertrail_host
        port = @papertrail_port
      end
      socket_key = "#{host}:#{port}"
      # recreate the socket if it's nil
      @sockets[socket_key] ||= create_socket(host, port)
      socket_key
    end

    def send_to_papertrail(packet, socket_key)
      if @sockets[socket_key].nil?
        err_msg = "Unable to create socket with #{socket_key}"
        raise SocketFailureError, err_msg
      else
        begin
          # send it
          @sockets[socket_key].puts packet.assemble
        rescue => e
          err_msg = "Error writing to #{socket_key}: #{e}"
          # socket failed, reset to nil to recreate for the next write
          @sockets[socket_key] = nil
          raise SocketFailureError, err_msg, e.backtrace
        end
      end
    end
  end
end
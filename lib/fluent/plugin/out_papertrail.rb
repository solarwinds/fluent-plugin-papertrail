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
    config_param :discard_unannotated_pod_logs, :bool, default: false
    config_param :maximum_syslog_packet_size, :integer, default: 99990

    # register as 'papertrail' fluent plugin
    Fluent::Plugin.register_output('papertrail', self)

    # declare const string for nullifying token if we decide to discard records
    DISCARD_STRING = 'DISCARD'

    def configure(conf)
      super
      # create initial sockets hash and socket based on config param
      @sockets = {}
      socket_key = form_socket_key(@papertrail_host, @papertrail_port)
      @sockets[socket_key] = create_socket(socket_key)
      # redefine default hostname if it's been passed in through ENV
      @default_hostname = ENV['FLUENT_HOSTNAME'] || @default_hostname
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each {|(tag, time, record)|
        socket_key = pick_socket(record)
        unless socket_key.eql? form_socket_key(DISCARD_STRING, DISCARD_STRING)
          # recreate the socket if it's nil
          @sockets[socket_key] ||= create_socket(socket_key)
          packet = create_packet(tag, time, record)
          send_to_papertrail(packet, socket_key)
        end
      }
    end

    def form_socket_key(host, port)
      "#{host}:#{port}"
    end

    def split_socket_key(socket_key)
      socket_key_arr = socket_key.split(':')
      return socket_key_arr[0], socket_key_arr[1]
    end

    def create_socket(socket_key)
      log.info "initializing tcp socket for #{socket_key}"
      begin
        host, port = split_socket_key(socket_key)
        socket = TCPSocket.new(host, port)
        log.debug "enabling ssl for socket #{socket_key}"
        ssl = OpenSSL::SSL::SSLSocket.new(socket)
        # close tcp and ssl socket when either fails
        ssl.sync_close = true
        # initiate SSL/TLS handshake with server
        ssl.connect
      rescue => e
        log.warn "failed to create tcp socket #{socket_key}: #{e}"
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
      # else if it is a kubernetes log and we're discarding unannotated logs
      elsif @discard_unannotated_pod_logs && record.dig('kubernetes')
        host = DISCARD_STRING
        port = DISCARD_STRING
      # else use pre-configured destination
      else
        host = @papertrail_host
        port = @papertrail_port
      end
      socket_key = form_socket_key(host, port)

      if socket_key == ':'
        kubernetes_err_msg = ''
        if record.dig('kubernetes', 'namespace_name')
          namespace_name = record['kubernetes']['namespace_name']
          kubernetes_err_msg = " from Kubernetes namespace: \"#{namespace_name}\""
        end
        log.warn("Received nil socket_configuration#{kubernetes_err_msg}. Discarding message.")
        host = DISCARD_STRING
        port = DISCARD_STRING
        socket_key = form_socket_key(host, port)
      end

      socket_key
    end

    def send_to_papertrail(packet, socket_key)
      if @sockets[socket_key].nil?
        err_msg = "Unable to create socket with #{socket_key}"
        raise SocketFailureError, err_msg
      else
        begin
          # send it
          @sockets[socket_key].puts packet.assemble(max_size=@maximum_syslog_packet_size)
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

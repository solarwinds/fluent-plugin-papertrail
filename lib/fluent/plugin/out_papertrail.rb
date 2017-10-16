require 'syslog_protocol'
require 'fluent/output'

module Fluent
  class Papertrail < Fluent::Output
    attr_accessor :socket, :papertrail_host, :papertrail_port

    Fluent::Plugin.register_output('papertrail', self)

    def configure(conf)
      super
      @papertrail_host = conf["papertrail_host"]
      @papertrail_port = conf["papertrail_port"]
      @socket = UDPSocket.new
    end

    def emit(tag, es, chain)
      es.each do |time, record|
        packet = SyslogProtocol::Packet.new
        packet.hostname = record['hostname']
        packet.facility = record['facility']
        packet.severity = record['severity']
        packet.tag = record['program']
        packet.content = record['message']
        @socket.send(packet.assemble, 0, papertrail_host, papertrail_port)
      end
      chain.next
    end
  end
end

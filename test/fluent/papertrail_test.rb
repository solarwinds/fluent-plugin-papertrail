require 'test_helper'

class Fluent::PapertrailTest < Test::Unit::TestCase

  class TestSocket
    attr_reader :packets

    def initialize()
      @packets = []
    end

    def puts(message)
      @packets << message
    end
  end

  def setup
    Fluent::Test.setup
    @driver = Fluent::Test::BufferedOutputTestDriver.new(Fluent::Papertrail, 'test')
    @mock_host = 'test.host'
    @mock_port = 123
    @driver.configure("
      papertrail_host #{@mock_host}
      papertrail_port #{@mock_port}
      ")
    @driver.instance.socket = TestSocket.new
    @default_record = {
        'hostname' => 'some.host.name',
        'facility' => 'local0',
        'severity' => 'warn',
        'program' => 'someprogram',
        'message' => 'some_message'
    }
  end

  def test_create_socket_defaults_to_ssl_socket
    # override the test configuration from above to
    # create a live SSLSocket with papertrailapp.com
    @driver.configure('
      papertrail_host logs3.papertrailapp.com
      papertrail_port 12345
      ')
    assert @driver.instance.socket.is_a? OpenSSL::SSL::SSLSocket
  end

  def test_configure_empty_configuration
    begin
      @driver.configure('')
    rescue => e
      assert e.is_a? Fluent::ConfigError
    end
  end

  def test_configure_uses_papertrail_config
    assert @driver.instance.papertrail_host.eql? @mock_host
    assert @driver.instance.papertrail_port.eql? @mock_port
  end

  def test_create_packet_without_timestamp
    packet = @driver.instance.create_packet(nil, nil, @default_record)
    assert packet.hostname.to_s.eql? @default_record['hostname']
    assert packet.facility.to_s.eql? '16'
    assert packet.severity.to_s.eql? '4'
    assert packet.tag.to_s.eql? @default_record['program']
    assert packet.content.to_s.eql? @default_record['message']
  end

  def test_create_packet_with_timestamp
    epoch_time     = 550_611_383
    converted_date = '1987-06-13'
    packet = @driver.instance.create_packet(nil, epoch_time, @default_record)
    assert packet.time.to_s.include? converted_date
  end

  def test_send_to_papertrail_with_test_socket
    snt_packet = @driver.instance.create_packet(nil, nil, @default_record)
    @driver.instance.send_to_papertrail(snt_packet)
    rcv_packet = @driver.instance.socket.packets.last
    assert rcv_packet.eql? snt_packet.assemble
  end

end

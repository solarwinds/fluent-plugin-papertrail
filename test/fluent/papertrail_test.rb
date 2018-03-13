require 'test_helper'

class Fluent::PapertrailTest < Test::Unit::TestCase

  class TestSocket
    attr_reader :packets

    def initialize
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
      'hostname' => 'some_hostname',
      'facility' => 'local0',
      'severity' => 'warn',
      'program' => 'some_program',
      'message' => 'some_message'
    }
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

  def test_create_packet_without_hostname
    # default hostname is 'unidentified'
    no_hostname_record = {
      'facility' => 'local0',
      'severity' => 'warn',
      'program' => 'some_program',
      'message' => 'some_message'
    }
    default_hostname = 'unidentified'
    packet = @driver.instance.create_packet(nil, nil, no_hostname_record)
    assert packet.hostname.to_s.eql? default_hostname
    # but if FLUENT_HOSTNAME environment variable is set, then that is used instead
    # so, set FLUENT_HOSTNAME and reconfigure driver to reload from ENV
    ENV['FLUENT_HOSTNAME'] = 'my_cluster'
    @driver.configure("
      papertrail_host #{@mock_host}
      papertrail_port #{@mock_port}
      ")
    packet = @driver.instance.create_packet(nil, nil, no_hostname_record)
    assert packet.hostname.to_s.eql? ENV['FLUENT_HOSTNAME']
  end

  def test_create_packet_without_program
    no_program_record = {
      'hostname' => 'some_hostname',
      'facility' => 'local0',
      'severity' => 'warn',
      'message' => 'some_message'
    }
    some_tag = 'some_tag'
    packet = @driver.instance.create_packet(some_tag, nil, no_program_record)
    assert packet.tag.to_s.eql? some_tag
  end

  def test_send_to_papertrail_with_test_socket
    snt_packet = @driver.instance.create_packet(nil, nil, @default_record)
    @driver.instance.send_to_papertrail(snt_packet)
    rcv_packet = @driver.instance.socket.packets.last
    assert rcv_packet.eql? snt_packet.assemble
  end

end
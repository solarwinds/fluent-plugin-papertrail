require 'test_helper'

class Fluent::PapertrailTest < Test::Unit::TestCase

  class TestSocket
    attr_reader :packets

    def initialize()
      @packets = []
    end

    def send(message, flag, host, port)
      @packets << {message: message,
                   flag: flag,
                   host: host,
                   port: port}
    end
  end

  def setup
    Fluent::Test.setup
    @driver = Fluent::Test::OutputTestDriver.new(Fluent::Papertrail, 'test')
    @driver.configure(%[
      type papertrail
      papertrail_host test.host
      papertrail_port 123
      hostname  emit.host
      ])
    @driver.instance.socket = TestSocket.new
    @default_record = {
      'message' => 'some_message',
      'program' => 'someprogram',
      'severity' => 'warn',
      'facility' => 'local0',
      'hostname' => 'some.host.name'
    }
  end

  def test_defaults_to_a_udp_socket
    @driver.configure("")
    assert @driver.instance.socket.is_a? UDPSocket
  end

  def test_uses_papertrail_config
    @driver.emit(@default_record)
    packet = @driver.instance.socket.packets.last
    assert_equal packet[:host], 'test.host'
    assert_equal packet[:port], '123'
  end

  def test_takes_program_from_record
    @default_record['program'] = 'myprogram'
    @driver.emit(@default_record)
    packet = @driver.instance.socket.packets.last
    assert packet[:message].include? 'some.host.name myprogram:'
  end

  def test_takes_hostname_from_record
    @default_record['hostname'] = 'my.special.host'
    @driver.emit(@default_record)
    packet = @driver.instance.socket.packets.last
    assert packet[:message].include? 'my.special.host someprogram:'
  end

  def test_takes_severity_from_record
    @default_record['severity'] = 'debug'
    @driver.emit(@default_record)
    packet = @driver.instance.socket.packets.last
    assert packet[:message].include? '<135>'
  end

  def test_takes_facility_from_record
    @default_record['facility'] = 'cron'
    @driver.emit(@default_record)
    packet = @driver.instance.socket.packets.last
    assert packet[:message].include? '<76>'
  end

  def test_takes_message_from_record
    @default_record['message'] = 'My Very Special Message'
    @driver.emit(@default_record)
    packet = @driver.instance.socket.packets.last
    assert packet[:message].include? 'My Very Special Message'
  end

end

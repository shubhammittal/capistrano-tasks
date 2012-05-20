require "test_helper"
require "net/http"

describe CapistranoTasks::Unicorn do
  before do
    setup_configuration
  end

  def port_open?(port)
    begin
      Timeout::timeout(1) do
        begin
          s = TCPSocket.new("localhost", port)
          s.close
          return true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
          p e
          return false
        end
      end
    rescue Timeout::Error
      puts "timeout error"
      false
    end
  end

  def http_open?(port)
    begin
      Timeout::timeout(2) do
        Net::HTTP.get(URI.parse("http://localhost:#{port}"))
        true
      end
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      false
    end
  end

  def setup_configuration(params = {})
    params = { :workers => 1 }.merge(params)
    @configuration = Capistrano::Configuration.new
    @configuration.set :current_path, "/home/arnold/builds/capistrano-tasks/spec/app"
    CapistranoTasks::Unicorn.load_into(@configuration, "test_c", params)

    # some basic machine configuration
    @configuration.role(:app, "localhost")
    @configuration.set(:ssh_options, { :forward_agent => true })
    @configuration.set(:current_path, File.dirname(__FILE__) + "/app")
    @configuration.set(:default_run_options, { :env => get_env })
    @configuration.run("mkdir -p #{File.dirname(@configuration.fetch(:unicorn_pid))}")
  end

  # random test for the sake of seeing how tests work
  it "should have a bootup timeout" do
    @configuration.fetch(:bootup_timeout).must_equal 30
  end

  it "should define a few tasks" do
    @configuration.find_task("test_c:start").wont_be_nil
    @configuration.find_task("test_c:dfdfdfd").must_be_nil
  end

  it "should be able to read param variables" do
    setup_configuration(:bootup_timeout => 60)
    @configuration.fetch(:bootup_timeout).must_equal 60
  end

  it "should be able to tell if a remote file exists" do
    @configuration.remote_file_exists?("/etc/resolv.conf").must_equal true
    @configuration.remote_file_exists?("/etc/does-not-exist").must_equal false
  end

  it "should be able to stop task when nothing is running" do
    @configuration.find_and_execute_task("test_c:stop")
  end

  def get_env
    export = ["PATH", "RBENV_ROOT"]
    hs = {}
    export.each { |i| hs[i] = ENV[i] }
    hs
  end

  it "should be able to start up a unicorn" do
    # port 3000 must be closed
    port_open?(3000).must_equal(false, "port musn't already be open")
    run_task("test_c:start")
    @configuration.remote_file_exists?(@configuration.fetch(:unicorn_pid)).must_equal(true)
    port_open?(3000).must_equal(true, "port is open now")
    run_task("test_c:graceful_stop")
    run_task("test_c:wait_till_dead")
    port_open?(3000).must_equal(false, "port is back closed now")
  end

  it "restarting unicorn" do
    setup_configuration(:bootup_timeout => 10)
    # port 3000 must be closed
    http_open?(3000).must_equal(false, "port musn't already be open")
    run_task("test_c:start")
    @configuration.remote_file_exists?(@configuration.fetch(:unicorn_pid)).must_equal(true)
    http_open?(3000).must_equal(true, "port is open now")
    run_task("test_c:reload")
    http_open?(3000).must_equal(true, "port is open now")
    safe_stop
  end

  it "restarting unicorn after being KILLed" do
    setup_configuration(:bootup_timeout => 10)
    # port 3000 must be closed
    http_open?(3000).must_equal(false, "port musn't already be open")
    run_task("test_c:start")
    http_open?(3000).must_equal(true, "port is open now")
    system("kill -KILL `cat #{@configuration.fetch(:unicorn_pid)}`")
    sleep 5
    run_task("test_c:reload")
    http_open?(3000).must_equal(true, "port is open now")
    safe_stop
  end

  it "should be able to send signals to unicorn" do
    @configuration.unicorn_send_signal("QUIT")
    (1..10).each { |i|
      puts "checking if port is open"
      return if !port_open?(3000)
    }
    fail "unicorn process failed to receive signal"
  end

  it "should be able to reduce workers to zero, and then port would be closed obviously" do
    run_task "test_c:decrement"
    sleep 2
    assert !port_open?(3000), "port should no longer be opened since there's no worker"
    safe_stop
  end

  def safe_stop
    run_task("test_c:graceful_stop")
    run_task("test_c:wait_till_dead")
    port_open?(3000).must_equal(false, "port is back closed now")
  end

  def run_task(taskname, opts = {}) 
    env = opts[:env] || {}
    opts[:env] = get_env.merge(env)
    opts[:pty] = true
    p opts
    @configuration.find_and_execute_task(taskname, opts) { |e, i, data| 
      puts data
    }
  end
end

require "spec"
require "../src/nghttp"

module SpecServers
  HOST = "127.0.0.1"

  @@httpbin_url : String? = nil
  @@httpbin_process : Process? = nil
  @@keep_alive_url : String? = nil
  @@keep_alive_process : Process? = nil

  def self.httpbin_url
    if url = ENV["NGHTTP_SPEC_HTTPBIN_URL"]?
      return url
    end

    @@httpbin_url ||= begin
      port = free_port
      process = Process.new(
        "python3",
        ["-m", "httpbin.core", "--host", HOST, "--port", port.to_s],
        output: Process::Redirect::Close,
        error: Process::Redirect::Close
      )
      @@httpbin_process = process
      wait_for_port(port)
      "http://#{HOST}:#{port}"
    end
  end

  def self.keep_alive_url
    if url = ENV["NGHTTP_SPEC_KEEP_ALIVE_URL"]?
      return url
    end

    @@keep_alive_url ||= begin
      port = free_port
      process = Process.new(
        "python3",
        ["#{__DIR__}/support/keep_alive_server.py", "--host", HOST, "--port", port.to_s],
        output: Process::Redirect::Close,
        error: Process::Redirect::Close
      )
      @@keep_alive_process = process
      wait_for_port(port)
      "http://#{HOST}:#{port}"
    end
  end

  def self.free_port
    server = TCPServer.new(HOST, 0)
    server.local_address.as(Socket::IPAddress).port
  ensure
    server.close if server
  end

  def self.wait_for_port(port)
    deadline = Time.monotonic + 5.seconds
    loop do
      begin
        socket = TCPSocket.new(HOST, port, connect_timeout: 0.1)
        socket.close
        return
      rescue
        raise "Timed out waiting for spec server on #{HOST}:#{port}" if Time.monotonic > deadline
        sleep 0.05
      end
    end
  end

  def self.stop
    stop(@@httpbin_process)
    stop(@@keep_alive_process)
  end

  private def self.stop(process : Process?)
    return unless process
    return if process.terminated?

    process.terminate
    begin
      process.wait
    rescue
    end
  end
end

Spec.after_suite do
  SpecServers.stop
end

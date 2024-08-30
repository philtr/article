require "socket"
require "openssl"
require "timeout"
require "logger"

module Article
  class Client
    class ConnectionError < Article::Error; end

    class AuthenticationError < Article::Error; end

    def initialize(server, port, username, password, use_ssl: true)
      @server = server
      @port = port
      @username = username
      @password = password
      @use_ssl = use_ssl
      @logger = Logger.new($stdout)
    end

    def connect
      @logger.info "Attempting to connect to #{@server}:#{@port} (SSL: #{@use_ssl})..."
      Timeout.timeout(60) do
        tcp_socket = TCPSocket.new(@server, @port)
        if @use_ssl
          ssl_context = OpenSSL::SSL::SSLContext.new
          ssl_context.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE)
          @socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
          @socket.connect
        else
          @socket = tcp_socket
        end
      end
      @logger.info "Connection established. Reading greeting..."
      greeting = read_response
      @logger.info "Server greeting: #{greeting}"
      authenticate
      yield self
    rescue Timeout::Error
      @logger.error "Connection to #{@server}:#{@port} timed out after 60 seconds"
      raise ConnectionError, "Connection to #{@server}:#{@port} timed out"
    rescue SocketError, OpenSSL::SSL::SSLError => e
      @logger.error "Failed to connect to #{@server}:#{@port}: #{e.message}"
      raise ConnectionError, "Failed to connect to #{@server}:#{@port}: #{e.message}"
    ensure
      @socket&.close
    end

    def list
      @logger.info "Sending LIST command..."
      send_command("LIST")
      response = read_multiline_response
      @logger.info "Received #{response.size} groups"
      response.map do |line|
        name, last, first, flag = line.split(" ")
        {name: name, last: last.to_i, first: first.to_i, flag: flag}
      end
    end

    private

    def authenticate
      @logger.info "Authenticating..."
      response = send_command("AUTHINFO USER #{@username}")
      if response.start_with?("381")
        response = send_command("AUTHINFO PASS #{@password}")
        raise AuthenticationError, "Authentication failed: #{response}" unless response.start_with?("281")
      end
      @logger.info "Authentication successful"
    end

    def send_command(command)
      @logger.debug "Sending command: #{command}"
      @socket.puts(command)
      read_response
    end

    def read_response
      response = @socket.gets&.chomp
      @logger.debug "Received response: #{response}"
      raise ConnectionError, "No response from server" if response.nil?
      response
    end

    def read_multiline_response
      response = []
      while (line = @socket.gets&.chomp) != "."
        break if line.nil?
        response << line
      end
      response
    end
  end
end

require "spec_helper"

RSpec.describe Article::Client do
  let(:server) { "news.example.com" }
  let(:port) { 563 }
  let(:username) { "user" }
  let(:password) { "pass" }
  let(:client) { described_class.new(server, port, username, password) }

  describe "#initialize" do
    it "sets instance variables correctly" do
      expect(client.instance_variable_get(:@server)).to eq(server)
      expect(client.instance_variable_get(:@port)).to eq(port)
      expect(client.instance_variable_get(:@username)).to eq(username)
      expect(client.instance_variable_get(:@password)).to eq(password)
      expect(client.instance_variable_get(:@use_ssl)).to be true
    end
  end

  describe "#connect" do
    let(:tcp_socket) { instance_double(TCPSocket) }
    let(:ssl_socket) { instance_double(OpenSSL::SSL::SSLSocket) }
    let(:ssl_context) { instance_double(OpenSSL::SSL::SSLContext) }

    before do
      allow(TCPSocket).to receive(:new).with(server, port).and_return(tcp_socket)
      allow(OpenSSL::SSL::SSLContext).to receive(:new).and_return(ssl_context)
      allow(ssl_context).to receive(:set_params)
      allow(OpenSSL::SSL::SSLSocket).to receive(:new).with(tcp_socket, ssl_context).and_return(ssl_socket)
      allow(ssl_socket).to receive(:connect)
      allow(ssl_socket).to receive(:close)
      allow(client).to receive(:read_response).and_return("200 NNTP Service Ready")
      allow(client).to receive(:authenticate)
    end

    it "succeeds with proper setup" do
      expect(Timeout).to receive(:timeout).with(60).and_yield

      client.connect do |c|
        expect(c).to be_an_instance_of(described_class)
      end

      expect(ssl_context).to have_received(:set_params).with(verify_mode: OpenSSL::SSL::VERIFY_NONE)
      expect(ssl_socket).to have_received(:connect)
      expect(ssl_socket).to have_received(:close)
      expect(client).to have_received(:read_response)
      expect(client).to have_received(:authenticate)
    end

    it "raises ConnectionError on timeout" do
      allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)

      expect { client.connect }.to raise_error(Article::Client::ConnectionError, /Connection to #{server}:#{port} timed out/)
    end

    it "raises ConnectionError on socket error" do
      allow(TCPSocket).to receive(:new).and_raise(SocketError.new("Connection refused"))

      expect { client.connect }.to raise_error(Article::Client::ConnectionError, /Failed to connect to #{server}:#{port}: Connection refused/)
    end
  end

  describe "#list" do
    it "returns parsed group information" do
      expect(client).to receive(:send_command).with("LIST").and_return("215 list of newsgroups follows")
      expect(client).to receive(:read_multiline_response).and_return([
        "group1 1000 1 y",
        "group2 2000 1 n"
      ])

      result = client.list
      expect(result.size).to eq(2)
      expect(result[0]).to eq({name: "group1", last: 1000, first: 1, flag: "y"})
      expect(result[1]).to eq({name: "group2", last: 2000, first: 1, flag: "n"})
    end
  end

  describe "#authenticate" do
    it "succeeds with correct credentials" do
      expect(client).to receive(:send_command).with("AUTHINFO USER #{username}").and_return("381 Password required")
      expect(client).to receive(:send_command).with("AUTHINFO PASS #{password}").and_return("281 Authentication accepted")

      expect { client.send(:authenticate) }.not_to raise_error
    end

    it "raises AuthenticationError on failure" do
      expect(client).to receive(:send_command).with("AUTHINFO USER #{username}").and_return("381 Password required")
      expect(client).to receive(:send_command).with("AUTHINFO PASS #{password}").and_return("481 Authentication failed")

      expect { client.send(:authenticate) }.to raise_error(Article::Client::AuthenticationError)
    end
  end
end

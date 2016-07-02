module Ricer4::Connectors
  class Irc < Ricer4::Connector
    
    include Ricer4::Plugins::Irc::Lib
    include Ricer4::Plugins::Irc::Parser

    def after_initialize
      @queue_lock = Mutex.new
      @queue = {}
      @frame = Ricer4::Queue::Frame.new(server)
      @socket = nil
      @attempt = 0
      @connected = false
    end
    
    def connect!
      #require 'uri'
      #require 'socket'
      mainloop
    end
    
    def disconnect!(quit_message="")
      @server.online = false
      @server.save!
      if @connected
        @attempt = 0
        bot.log.info("Disconnecting from #{server.hostname}")
        send_quit(quit_message) if @socket && quit_message
        @queue_lock.synchronize do
          @socket.close
          @socket = nil
        end
        @connected = false
        sleep 8
        true
      end
      false
    end

    def connect_plain!
      bot.log.info("Connecting to #{server.hostname}")
      @socket = TCPSocket.new(server.hostname, server.port)
    end
    
    def connect_ssl!
      bot.log.info("Connecting via TLS to #{server.hostname}")
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE unless server.tls == 2
      sock = TCPSocket.new(server.hostname, server.port)
      @socket = OpenSSL::SSL::SSLSocket.new(sock, ssl_context)
      @socket.sync = true
      @socket.connect
    end
    
    def protocol
      server.tls? ? 'ircs' : 'irc'
    end
    
    def connect_irc!
      begin
        @attempt += 1
        server.tls? ? connect_ssl! : connect_plain!
        connected
        true
      rescue StandardError => e
        bot.log.exception(e, false)
        arm_signal(server, "irc/connect/failure", server, e)
        arm_signal(server, "server/connect/failure", server, e)
        false
      end
    end
    
    def mainloop
      connect_irc! if bot.running
      while @connected || (bot.running && server.persisted?) 
        if @connected
          if message = get_message
            arm_signal(server, "ricer/incoming", message.raw)
            setup_message(message)
            arm_signal(server, "ricer/receive", message)
            arm_signal(server, "ricer/received", message)
            arm_signal(server, "irc/#{message.type}", message)
          else
            disconnect!
          end
        else
          sleep(connect_timeout)
          connect_irc! if bot.running
        end
      end
    end
    
    def port; server.port; end;
    def hostname; server.hostname; end
      
    def get_message
      if line = @socket.gets
        message = parse(line)
        message.server = server
        message
      end
    end
    
    def connect_timeout
      ((@attempt-1) * 10).clamp(3, 600);
    end
    
    
    def connected
      bot.log.info("Connected to #{hostname}")
      @connected = true
      @server.online = true
      @server.save!
      # @queue = {}
      # @frame = Ricer4::Queue::Frame.new(server)
      send_queue
      fair_queue
      arm_signal(server, 'irc/handshake', server)
    end
    
    ###############
    ### Sending ###
    ###############
    def send_reply(reply)
      bot.log.debug("IrcConnector::send_reply(#{reply.text})")
      message = reply.message
      if reply.is_system?
        send_queued(reply)
      else
        prefix = "#{reply_code(reply)} #{reply.target.name} :"
        postfix = ""
        if reply.is_action?
          prefix += "\x01ACTION "; postfix += "\x01"
        elsif reply.is_message?
        else
          prefix += "#{message.sender.name}: " if message.to_channel?
        end
        send_splitted(reply, prefix, postfix)
      end
    end
    
    def reply_code(reply)
      case reply.type
      when Ricer4::Reply::SYSTEM,Ricer4::Reply::SUCCESS,Ricer4::Reply::FAILURE; 'PRIVMSG'
      when Ricer4::Reply::PRIVMSG; 'PRIVMSG'
      when Ricer4::Reply::ACTION,Ricer4::Reply::NOTICE; 'NOTICE'
      when Ricer4::Reply::MESSAGE; reply.target.wants_notice? ? 'NOTICE' : 'PRIVMSG'
      else; raise Ricer4::ExecutionException.new("Unkown reply code!")
      end
    end
    
    def send_raw(line); send_line(line); end
    def send_part(channelname); send_line("PART #{channelname}"); end
    def send_join(channelname, password=nil); send_line("JOIN #{channelname}#{password ?(' '+password):''}"); end
    def send_quit(quitmessage); send_line("QUIT :#{quitmessage}") if @connected; end

    def queue_with_lock(&block)
      @queue_lock.synchronize do
        yield(@queue)
      end
    end
    
    private
    
    def send_line(line, type=Ricer4::Reply::SYSTEM)
      send_queued(Ricer4::Reply.new(line, nil, type))
    end

    def send_splitted(reply, prefix, postfix='')
      length = server.max_line_length - prefix.bytesize - postfix.bytesize - 32
      # split by length and newline
      reply.text.scan(Regexp.new(".{1,#{length}}(?:\s|$)|.{1,#{length}}")).each do |line|
        send_queued(reply.split_clone(prefix+line+postfix))
      end
      nil
    end 

    def send_queued(reply)
      to = reply.message.sender
      @queue_lock.synchronize do
        @queue[to] ||= Ricer4::Queue::Object.new(to)
        @queue[to].push(reply)
      end
      nil
    end
    
    def send_socket(line)
      begin
        arm_signal(server, "ricer/outgoing", line)
        @socket.write "#{line}\r\n"
        @frame.sent
      rescue StandardError => e
        bot.log.info("Disconnect from #{server.hostname}: #{e.message}")
        bot.log.exception(e)
        disconnect!(nil)
      end
      nil
    end
    
    # Thread that reduces penalty for QueueObjects
    def fair_queue
      worker_threaded do
        while @connected
          sleep(Ricer4::Queue::Frame::SECONDS * 2)
          @queue_lock.synchronize do
            @queue.each{|to, queue| queue.reduce_penalty }
          end
        end
      end
    end
    
    # Thread that sends QueueObject lines
    def send_queue
      worker_threaded do
        while @connected
          @queue_lock.synchronize do
            @queue.each do |to, queue|
              break if @frame.exceeded?
              if reply = queue.pop
                send_socket_reply(reply)
              end
            end
            @queue.select! { |to,queue| !queue.empty? }
            @queue = Hash[@queue.sort_by { |to,queue| queue.penalty }]
          end
          sleep @frame.sleeptime
        end
      end
    end
    
    def send_socket_reply(reply)
      arm_signal(server, "ricer/replying", reply)
      send_socket(reply.text)
    end
    
  end
end

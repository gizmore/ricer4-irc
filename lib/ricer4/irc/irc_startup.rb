module Ricer4::Plugins::Irc
  class IrcStartup < Ricer4::Plugin
    
    priority_is 1

    def plugin_init
      
      arm_subscribe('irc/error') do |sender, message|
        bot.log.error(message.raw)
      end
      
      arm_subscribe('irc/ping') do |sender, message|
        message.server.send_line("PONG :#{message.args[0]}")
      end
      
      arm_subscribe('irc/handshake') do |sender, server|
        authenticate_server(server)
        login(server)
      end

      arm_subscribe('irc/433') do |sender, message|
        message.server.next_nickname!
        login(message.server)
      end
      
    end
    
    private
    
    def login(server)
      bot.log.info("Logging in as #{server.next_nickname}")
      server.send_line("USER #{server.username} #{server.hostname} #{server.userhost} :#{server.realname}")
      send_nick(server)
    end

    def send_nick(server)
      server.send_line("NICK #{server.next_nickname}")
      authenticate_nickname(server)
    end
    
    def authenticate_server(server)
      # send_line("PRIVMSG NickServ :IDENTIFY #{server.user_pass}") if server.server_authenticate?
    end
    
    def authenticate_nickname(server)
      send_line("PRIVMSG NickServ :IDENTIFY #{server.user_pass}") if server.nick_authenticate?
    end
    
  end
end
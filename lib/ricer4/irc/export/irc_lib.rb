module Ricer4::Plugins::Irc
  module Lib
    
    include Ricer4::Include::UserConnector

    def nickname_valid?(nickname)
      !!/^[^\x00-\x1F\XFF!@%+]+$/i.match(nickname)
    end

    def channelname_valid?(channelname)
      !!/^[&#]#?[^\x00-\x1F,\x7F]{1,199}$/iu.match(channelname.force_encoding('UTF-8'))
    end
    
    ###############
    ### Message ###
    ###############
    def setup_message(message)
      message.sender = message.server
      return unless message.prefix && message.prefix.starts_with?(':')
      if message.prefix.index('!')
        setup_user_message(message)
      end
    end
    
    private
    
    def setup_user_message(message)
      # Gather data
      server = message.server
      prefix = message.prefix[1..-1]
      nickname = prefix.substr_to('!')
      realname = prefix.substr_from('!')
      hostmask = realname.substr_from('@'); realname = realname.substr_to('@')
      # Setup sender
      message.sender = load_or_create_user(server, nickname)
      message.sender.set_online(true)
      message.sender.hostmask = hostmask
      # Setup channel target
      case message.args[0][0] # if arg begins with # or &
      when '#','&'; message.target = load_or_create_channel(server, message.args[0])
      end
    end
    
  end
end

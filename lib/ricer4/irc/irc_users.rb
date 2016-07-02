module Ricer4::Plugins::Irc
  class IrcUsers < Ricer4::Plugin
    
    include Ricer4::Plugins::Irc::Lib
    include Ricer4::Include::UserConnector
    include Ricer4::Include::ChannelConnector

    priority_is 1

    def plugin_init
      arm_subscribe('irc/nick') { |sender, message| on_user_nick(message) }
      arm_subscribe('irc/quit') { |sender, message| on_user_quit(message) }
      arm_subscribe('irc/mode') { |sender, message| on_user_mode(message) }
    end
    
    # Nickname change
    def on_user_nick(message)
      bot.log.debug("IrcUsers.on_user_nick(#{message.raw})")
      new_user = load_or_create_user(server, message.args[0])
      new_user.logout! if (sender.hostmask != new_user.hostmask)
      sender.all_chanperms.online.each do |chanperm|
        new_chanperm = new_user.chanperm_for(chanperm.channel)
        new_chanperm.chanmode.permission = chanperm.chanmode.permission
        new_chanperm.set_online(true)
        chanperm.set_online(false)
      end
      sender.set_online(false)
      message.sender = new_user
    end

    # User quit    
    def on_user_quit(message)
      bot.log.debug("IrcUsers.on_user_quit(#{message.raw})")
    end

    ### Mode
    
    # On mode
    def on_set_mode(message)
      bot.log.debug("IrcUsers.on_user_mode(#{message.raw})")
      if channel = get_channel(server, message.args[0])
        if args.length == 2
          on_channel_mode(channel, message.args[1])
        else
          on_user_channel_mode(channel, message)
        end
      else
        on_user_mode(message)
      end
    end
    def on_channel_mode(channel, mode)
      
    end
    def on_user_channel_mode(channel, message)
      
    end
    def on_user_mode(message)
      
    end

  end
end

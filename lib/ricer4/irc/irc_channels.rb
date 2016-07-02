module Ricer4::Plugins::Irc
  class IrcChannels < Ricer4::Plugin
    
    include Ricer4::Plugins::Irc::Lib
    include Ricer4::Include::ChannelConnector

    priority_is 1

    def plugin_init
      arm_subscribe('irc/353') do |sender, message|; on_names_list(message); end
      arm_subscribe('irc/join') do |sender, message|; on_user_joined(message); end
      arm_subscribe('irc/part') do |sender, message|; on_user_parted(message); end
    end
    
    def on_names_list(message)
      bot.log.debug("IrcChannel.on_names_list(#{message.raw})")
      channel = load_or_create_channel(server, message.args[2])
      message.args.last.split(' ').each do |username|
        username.strip!
        unless username.empty?
          permission = Ricer4::Permission.by_nickname(username) || Ricer4::Permission::PUBLIC
          username.ltrim!(Ricer4::Permission.all_symbols)
          user = load_or_create_user(server, username)
          chanperm = user.chanperm_for(channel)
          chanperm.set_online(true)
          chanperm.chanmode.permission = permission
        end
      end
    end
    
    def on_user_joined(message)
      bot.log.debug("IrcChannel.on_user_joined(#{message.raw})")
      sender.chanperm_for(channel).set_online(true)
    end

    def on_user_parted(message)
      bot.log.debug("IrcChannel.on_user_parted(#{message.raw})")
      sender.chanperm_for(channel).set_online(false)
    end
    
  end
end

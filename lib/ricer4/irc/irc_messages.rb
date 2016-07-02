module Ricer4::Plugins::Irc
  class IrcMessages < Ricer4::Plugin
    
    include Ricer4::Plugins::Irc::Lib
    
    priority_is 1
    
    def plugin_init
      
      arm_subscribe('irc/notice') do |sender, message|
        received_irc_message('notice', message)
      end
      
      arm_subscribe('irc/privmsg') do |sender, message|
        received_irc_message('privmsg', message)
      end
      
    end
    
    def received_irc_message(type, message)
      arm_publish('ricer/messaged', message) unless message.from_server?
    end
    
  end
end

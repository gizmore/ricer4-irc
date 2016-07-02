# IRC Message parser
# Converts a line into a Ricer4::Message object
module Ricer4::Plugins::Irc
  module Parser

    def parse(line)
      
      line.rtrim!("\r\n")
      
      message = Ricer4::Message.new
      
      raw = message.raw = line
      
      s = 0 # start index
      e = raw.index(' ') # end index
      l = false # Last processed?
      
      # Prefixes start with ':'
      if raw[s] == ':'
        message.prefix = raw[s..e-1]
      else
        e = -1
        message.prefix = nil
      end
      
      # Now the type
      s = e + 1
      e = raw.index(' ', s)
      if e.nil?
        # Which could be the last thing, without any args
        message.type = raw[s..-1].downcase
        return message
      end
      message.type = raw[s..e-1].downcase
      
      args = [];
      s = e + 1
      
      while !(e = raw.index(' ', s)).nil?
        if (raw[s] == ':')
          s = s + 1
          arg = raw[s..-1]
          s = raw.length
          l = true
        else
          arg = raw[s..e-1]
          s = e + 1
        end
        args.push(arg)
      end

      # Last arg
      if l == false
        s = s + 1 if raw[s] == ':'
        args.push(raw[s..-1])
      end
      message.args = args
      return message
    end    
    
  end
end
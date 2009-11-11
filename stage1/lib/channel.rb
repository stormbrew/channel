module Channel
	class ChannelError < ::RuntimeError
	end	
end

require 'channel/parser'
require 'channel/compiler'
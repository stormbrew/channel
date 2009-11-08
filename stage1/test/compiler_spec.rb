require "lib/channel/parser"
require "lib/channel/compiler"

class StringIO
	alias :inspect_orig :inspect
	def inspect
		return inspect_orig + "(#{self.string})"
	end
end

describe Channel::Compiler do
	module Channel::Compiler
	end
end
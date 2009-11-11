require 'channel/parser'

module Channel
	# The compiler is responsible for transforming a program document into a series of commands.
	# It does this by searching the passed TupleSet for Tuples and turning them into StatementTuples,
	# which are a superset of the Tuples they're derived from and contain information about
	# execution. Notably, they will have transformed most operator combinations into reverse
	# polish notation and certain built in constructs (if, switch, etc) will be in a specialized
	# format.
	module Compiler
		
	end
end
require 'channel/parser'

module Channel
	# The compiler is responsible for transforming a program document into a series of commands.
	# It does this by searching the passed TupleSet for Tuples and turning them into CommandTuples,
	# which are a superset of the Tuples they're derived from and contain information about
	# execution. Notably, they will have transformed most operator combinations into reverse
	# polish notation and certain built in constructs (if, switch, etc) will be in a specialized
	# format.
	module Compiler
		class CommandTuple < Parser::Tuple
			
		end
		
		# var x = blah
		class VariableDeclarationCommand < CommandTuple
			
		end
		
		# if (cond1): {action1} (cond2): {action2} else: {fallback}
		class IfCommand < CommandTuple
			
		end
		
		# switch value (eq1): {action1} (eq2): {action2} else: {fallback}
		# (roughly equiv to if (value == eq1): {action1}...)
		class SwitchCommand < CommandTuple
			
		end
		
		# methodname arg1 arg2 blockname: {block}
		class MethodInvokeCommand < CommandTuple
			
		end
	end
end
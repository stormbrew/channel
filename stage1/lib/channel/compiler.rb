require 'channel/parser'

module Channel
	# The compiler is responsible for transforming a program document into a series of commands.
	# It does this by searching the passed TupleSet for Tuples and turning them into StatementTuples,
	# which are a superset of the Tuples they're derived from and contain information about
	# execution. Notably, they will have transformed most operator combinations into reverse
	# polish notation and certain built in constructs (if, switch, etc) will be in a specialized
	# format.
	module Compiler
		class CompilerError < ::RuntimeError
			attr_reader :tuple
			def initialize(tuple)
				@tuple = tuple
			end
		end
		
		BareWord = Parser::BareWord
		Reference = Parser::Reference
		StringConstant = Parser::StringConstant

		OPERATORS = ['==', '+', '-', '/', '*', '%'].collect{|x| BareWord[x]}
		VARNAME_MATCH = %r{[a-zA-Z][a-zA-Z0-9_]*}
		
		class Tree < Parser::TupleSet
			attr_reader :original, :statements
			
			def initialize(parse_tree)
				super(parse_tree.type, parse_tree.tuples)
				@original = parse_tree
				@statements = parse_tree.tuples.collect {|tuple|
					Tree.process_tuple(tuple)
				}
			end
			
			def self.process_tuple(tuple)
				if (tuple.values.first == BareWord['var'])
					return VariableDeclarationStatement.new(tuple)
				elsif (tuple.values.first == BareWord['if'])
					return IfStatement.new(tuple)
				elsif (tuple.values.first == BareWord['switch'])
					return SwitchStatement.new(tuple)
				elsif (tuple.values.first == BareWord['return'])
					return ReturnStatement.new(tuple)
				elsif (tuple.values[1] == BareWord['='])
					return AssignmentStatement.new(tuple)
				elsif (OPERATORS.include?(tuple.values[1]))
					return ExpressionStatement.new(tuple)
				else
					return MethodInvokeStatement.new(tuple)
				end
			end
		end
		
		class StatementTuple < Parser::Tuple
			attr_reader :original
			
			def initialize(parse_tuple)
				@original = parse_tuple
				super(parse_tuple.type, parse_tuple.values)
			end
		end
		
		# var x = expr
		class VariableDeclarationStatement < StatementTuple
			attr_reader :name, :value_expr
			
			def initialize(parse_tuple)
				super(parse_tuple)
				
				err = CompilerError.new(parse_tuple)
				
				if (parse_tuple.values.length < 4)
					raise err, "Incomplete variable assignment"
				end
				name_word = parse_tuple.values[1]
				if (!name_word.kind_of?(BareWord))
					raise err, "Invalid variable name: expected BareWord, got #{name_word.class}"
				end
				if (name_word.string !~ VARNAME_MATCH)
					raise err, "Invalid variable name: '#{name_word.string}'"
				end
				@name = name_word.string
				
				if (parse_tuple.values[2].string != '=')
					raise err, "Malformed assignment: #{parse_tuple.values[2].string} should be '='"
				end
				
				# now create a new expression out of the remainder of the tuple.
				remain = parse_tuple.values.length - 3
				remainder = parse_tuple.values[-remain, remain]
				@value_expr = Tree::process_tuple(Parser::Tuple.new(parse_tuple.type, remainder))			
			end
		end
		
		# if (cond1): {action1} (cond2): {action2} else: {fallback}
		class IfStatement < StatementTuple
			
		end
		
		# switch value (eq1): {action1} (eq2): {action2} else: {fallback}
		# (roughly equiv to if (value == eq1): {action1}...)
		class SwitchStatement < StatementTuple
			
		end
		
		# return expr...
		class ReturnStatement < StatementTuple
			
		end
		
		# reference = ...
		# TupleSet[Reference...] = ...
		class AssignmentStatement < StatementTuple
			
		end
		
		# operand operator ...
		class ExpressionStatement < StatementTuple
			
		end
		
		# methodname arg1 arg2 blockname: {block}
		# (note: because of ExpressionStatement, arg1 cannot be anything considered an 'operator')
		class MethodInvokeStatement < StatementTuple
			
		end
	end
end
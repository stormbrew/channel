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
		
		Operator = Struct.new(:token, :precedence, :associativity, :terms)
		pc = 0
		Operators = {
			'.' => Operator['.', pc, :ltr, 2],
			'U.' => Operator['.', pc, :ltr, 1],
			'U+' => Operator['+', pc+=1, :rtl, 1],
			'U-' => Operator['-', pc, :rtl, 1],
			'U!' => Operator['!', pc, :rtl, 1],
			'U~' => Operator['~', pc, :rtl, 1],
			'U*' => Operator['*', pc, :rtl, 1],
			'*' => Operator['*', pc+=1, :ltr, 2],
			'/' => Operator['/', pc, :ltr, 2],
			'%' => Operator['%', pc, :ltr, 2],
			'+' => Operator['+', pc+=1, :ltr, 2],
			'-' => Operator['-', pc, :ltr, 2],
			'..' => Operator['..', pc+=1, :ltr, 2],
			'...' => Operator['...', pc, :ltr, 2],
			'<<' => Operator['<<', pc+=1, :ltr, 2],
			'>>' => Operator['>>', pc, :ltr, 2],
			'<' => Operator['<', pc+=1, :ltr, 2],
			'>' => Operator['>', pc, :ltr, 2],
			'<=' => Operator['<=', pc, :ltr, 2],
			'>=' => Operator['>=', pc, :ltr, 2],
			'==' => Operator['==', pc+=1, :ltr, 2],
			'!=' => Operator['!=', pc, :ltr, 2],
			'&' => Operator['&', pc+=1, :ltr, 2],
			'^' => Operator['^', pc+=1, :ltr, 2],
			'|' => Operator['|', pc+=1, :ltr, 2],
			'&&' => Operator['&&', pc+=1, :ltr, 2],
			'||' => Operator['||', pc+=1, :ltr, 2],
		}
		class Operator
			def Operator.find(terms, text)
				if (terms == 1)
					return Operators["U#{text}"]
				else
					return Operators[text]
				end
			end
			def inspect_r(l = 0)
				return %Q{Operator.find(#{terms}, #{token.inspect_r})}
			end
		end

		VARNAME_MATCH = %r{[a-zA-Z][a-zA-Z0-9_]*}
		
		class CompiledTree < Parser::TupleSet
			attr_reader :original, :statements
			
			def initialize(parse_tree)
				super(parse_tree.type, parse_tree.tuples)
				@original = parse_tree
				@statements = parse_tree.tuples.collect {|tuple|
					CompiledTree.process_tuple(tuple)
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
				else
					return ExpressionStatement.new(tuple)
				end
			end
			
			def inspect_r(l = 0)
				t = ' '*l
				s = StringIO.new
				s << t << "CompiledTree[\n"
				s << statements.collect {|statement|
					statement.inspect_r(l+1)
				}.join(",\n") << "\n"
				s << t << "]"
				s.string
			end				
		end
		
		class StatementTuple < Parser::Tuple
			attr_reader :original
			
			def initialize(parse_tuple)
				@original = parse_tuple
				super(parse_tuple.type, parse_tuple.values)
			end
		end
		
		# value
		class ValueStatement < StatementTuple
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
				
				if (values.length < 4)
					raise err, "Incomplete variable assignment"
				end
				name_word = values[1]
				if (!name_word.kind_of?(BareWord))
					raise err, "Invalid variable name: expected BareWord, got #{name_word.class}"
				end
				if (name_word.string !~ VARNAME_MATCH)
					raise err, "Invalid variable name: '#{name_word.string}'"
				end
				@name = name_word.string
				
				if (values[2].string != '=')
					raise err, "Malformed assignment: #{parse_tuple.values[2].string} should be '='"
				end
				
				# now create a new expression out of the remainder of the tuple.
				remain = values.length - 3
				remainder = values[-remain, remain]
				@value_expr = CompiledTree::process_tuple(Parser::Tuple.new(type, remainder))			
			end
			
			def inspect_r(l=0)
				t = ' '*l
				s = StringIO.new
				s << t << "VariableDeclarationStatement[" << name.inspect_r << ",\n"
				s << value_expr.inspect_r(l+1) << "\n"
				s << t << "]"
				s.string
			end
		end
		
		# if (cond1): {action1} (cond2): {action2} else: {fallback}
		class IfStatement < StatementTuple
			class ConditionStatement < Parser::Label
				attr_reader :original, :condition, :body
				
				def initialize(parse_label)
					err = CompilerError.new(parse_label)
					
					if (!parse_label.kind_of? Parser::Label)
						raise err, "Malformed if condition, expected label and got #{parse_label.class}"
					end
					
					@original = original
					super(parse_label.key, parse_label.value)
										
					if (key.class != Parser::TupleSet)
						raise err, "Malformed if condition, condition must be a tuple."
					end
					if (value.class != Parser::TupleSet)
						raise err, "Malformed if condition, body must be a tuple."
					end
					@condition = CompiledTree.new(key)
					@body = CompiledTree.new(value)
				end
				
				def inspect_r(l = 0)
					t = " "*l
					s = StringIO.new
					s << t << "IfStatement::ConditionStatement[\n"
					s << condition.inspect_r(l+1) << ",\n"
					s << body.inspect_r(l+1) << "\n"
					s << t << "]"
				end
			end

			attr_reader :conditions
			
			def initialize(parse_tuple)
				super(parse_tuple)
				
				err = CompilerError.new(parse_tuple)
				
				if (values.length < 2)
					raise err, "Incomplete if statement, needs at least one condition."
				end
				
				remain = values.length - 1
				remainder = values[-remain, remain]
				conditions = remainder.each {|value|
					ConditionStatement.new(value)
				}
			end
			
			def inspect_r(l=0)
				t = ' '*l
				s = StringIO.new
				s << t << "IfStatement[\n"
				s << conditions.collect {|condition|
					condition.inspect_r(l+1)
				}.join(",\n") << "\n"
				s << t << "]"
				s.string
			end
		end
		
		# switch value (eq1): {action1} (eq2): {action2} else: {fallback}
		# (roughly equiv to if (value == eq1): {action1}...)
		class SwitchStatement < StatementTuple
			
		end
		
		# return expr...
		class ReturnStatement < StatementTuple
			attr :return_expr
			
			def initialize(parse_tuple)
				super(parse_tuple)
				
				if (values.length > 1)
					remain = values.length - 3
					remainder = values[-remain, remain]
					@return_expr = CompiledTree::process_tuple(Parser::Tuple.new(type, remainder))
				else
					@return_expr = nil
				end		
			end
			
			def inspect_r(l = 0)
				if (return_expr.nil?)
					"ReturnStatement[]"
				else
					t = ' '*l
					s = StringIO.new
					s << t << "ReturnStatement[\n"
					s << return_expr.inspect_r(l+1)
					s << t << "]"
					s.string
				end
			end
		end
		
		# reference = ...
		# TupleSet[Reference...] = TupleSet[...]
		class AssignmentStatement < StatementTuple
			attr_reader :left, :right_expr
			
			def initialize(parse_tuple)
				super(parse_tuple)
				
				err = CompilerError.new(parse_tuple)
				
				if (values.length < 3)
					raise err, "Malformed assignment: not enough tokens."
				end
				if (values[0].kind_of? Parser::Reference) # single assignment
					@left = values[0]
					remain = values.length - 2
					remainder = values[-remain, remain]
					@right_expr = CompiledTree::process_tuple(Parser::Tuple.new(type, remainder))
				elsif (values[0].kind_of? Parser::TupleSet) # multi assignment/swap
					raise err, "Multi-assign not yet implemented."
				else
					raise err, "Malformed assignment: Expected either Reference or TupleSet of References on left hand side, got #{values[0].class}"
				end
			end
			
			def inspect_r(l = 0)
				t = ' '*l
				s = StringIO.new
				s << t << "AssignmentStatement[\n"
				s << left.inspect_r(l+1) << ",\n"
				s << right_expr.inspect_r(l+1) << "\n"
				s << t << "]"
				s.string
			end
		end
		
		class OperatorStatement < Parser::BareWord
			attr_reader :original, :info, :terms
			
			def initialize(operator, info)
				super(operator.string)
				
				@original = operator
				@info = info
				@terms = []
			end
			
			def consume(term_list)
				err = CompilerError.new(self)
				
				(0...@info.terms).each {|term_num|
					if (term_list.empty?)
						raise err, "Expected #{@info.terms} terms to operator #{string}, got #{terms.length}"
					end
					term = term_list.shift
					if (term.kind_of?(Array)) # regular term. (later do processing on it as a value or function call)
						@terms.unshift(term)
					else # is an operator, recurse.
						@terms.unshift(OperatorStatement.new(term.token, term.info).consume(term_list))
					end
				}
				return self
			end
			
			def inspect_r(l = 0)
				t = ' '*l
				s = StringIO.new
				s << t << %Q{OperatorStatement[#{info.inspect_r(0)},\n}
				s << @terms.collect {|term|
					term.inspect_r(l+1)
				}.join(",\n")
				s << "\n" << t << "]"
				s.string
			end
		end
		
		# Anything else. Parses tokens for operator precedence and deals with them.
		class ExpressionStatement < StatementTuple
			attr_reader :action
			
			def initialize(parse_tuple)
				super(parse_tuple)
				
				op_stack_item = Struct.new(:info, :token)
				op_stack = []
				output = []
				
				# this is an implementation of the shunting yard algorithm. Note that it
				# outputs a polish notation, not reverse polish notation. The resulting
				# stack is consumed below into an actual execution graph.
				unary = true
				values.each {|val|
					op_info = nil
					if (val.kind_of?(Parser::BareWord) &&
						  op_info = Operator.find(unary ? 1 : 2, val.string))
						last_op = op_stack.last
						if (last_op)
							while (last_op &&
								     ((op_info.associativity == :ltr && op_info.precedence >= last_op.info.precedence) ||
							       (op_info.associativity == :rtl && op_info.precedence > last_op.info.precedence)))
								output.unshift(op_stack.pop)
								last_op = op_stack.last
							end
						end
						op_stack.push(op_stack_item[op_info, val])
						output.unshift(nil) # we're done a 'term' of the parse, so push an nil to act as a sequence point
						unary = true # operator after operator is unary
					else
						if (output.last.kind_of? Array)
							output.first.push(val)
						else
							output.unshift([val])
						end
						unary = false # operator after value is binary
					end
				}
				while (!op_stack.empty?)
					output.unshift(op_stack.pop)
				end
				# remove any extra empty 'terms'
				output = output.collect {|item|
					if (item.nil?)
						item # ignore it, it'll be compacted out later.
					if (item.kind_of?(Array)) # item is a term
						# there can't be more than one 
						
						# if the first element of the term is a bareword, re-evaluate it as a
						# method call with a . prefix.
						
					else 
						OperatorStatement.new(first_action.token, first_action.info).consume(output)
					end
				}.compact
			end
			
			def inspect_r(l = 0)
				t = ' '*l
				s = StringIO.new
				s << t << "ExpressionStatement[\n"
				s << action.inspect_r(l+1) << "\n"
				s << t << "]"
				s.string
			end
		end
	end
end
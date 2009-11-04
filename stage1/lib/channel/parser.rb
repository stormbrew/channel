# This parser is implemented purely by brute force with no attempt at elegance or performance.
require 'stringio'

module Channel
 	module Parser
		def self.node_type_from_first_character(char)
			return case char
			when '{' then TupleSet.new(:line)
			when '(' then TupleSet.new(:comma)
			when '"' then StringConstant.new(:complex)
			when "'" then StringConstant.new(:simple)
			else BareWord.new(char)
			end
		end
		
		class Tuple
			attr_reader :values
			
			def initialize(type, splitter, terminator)
				@type = type
				@splitter = splitter
				@terminator = terminator
				
				@values = []
				@current_value = nil
			end
			def next(char)
				if (@current_value)
					status = @current_value.next(char)
					return false if (status == false)
					
					@values << @current_value
					@current_value = nil
					return false if (status == :done) # no character was passed back, so do nothing 'til the next character
					char = status # if we get here, a character was passed back so process it.
				end

				# if we've hit the end of the tuple, let it fall back to the container.
				case char
				when @splitter
					return :done
				when @terminator
					return @terminator
				when ' ', "\t", "\n"
					return false
				end
				
				# otherwise, figure out what the next node is.
				@current_value = Parser::node_type_from_first_character(char)
				return false
			end
			def inspect_r(l = 0)
				t = "\n" + ' ' * l
				s = StringIO.new()
				s << t << "Tuple[\n"
				@values.each {|val|
					s << val.inspect_r(l + 1)
				}
				s << t << "]\n"
				return s.string
			end
		end
		
		class TupleSet
			attr_reader :tuples
			
			def initialize(type)
				@type = type
				case type
				when :file
					@splitter = '\n'
					@terminator = nil
				when :line
					@splitter = '\n'
					@terminator = '}'
				when :comma
					@splitter = ','
					@terminator = ')'
				end
				@tuples = []
				@current_tuple = Tuple.new(@type, @splitter, @terminator)
			end
			def next(char)
				if (@current_tuple)
					status = @current_tuple.next(char)
					return false if (status == false)
					
					@tuples << @current_tuple
					@current_tuple = Tuple.new(@type, @splitter, @terminator)
					return false if (status == :done) # no character was passed back, so do nothing 'til the next character
					char = status # if we get here, a character was passed back so process it.
				end
				
				if (char == @terminator)
					return :done
				end
				return false
			end
			
			def inspect_r(l = 0)
				t = "\n" + " " * l
				s = StringIO.new
				s << t << "TupleSet["
				@tuples.each {|tuple|
					s << tuple.inspect_r(l + 1)
				}
				s << t << "]\n"
				return s.string
			end
		end
		
		class StringConstant
			def string
				@string.string
			end
			
			def initialize(type)
				@type = type
				@terminator = case type
					when :simple then "'"
					when :complex then '"'
					end
				@string = StringIO.new()
				@escape = false
			end
			def next(char)
				if (@escape)
					@string << char
					@escape = false
					return false
				end
				
				case char
				when "\\"
					@escape = true
					return false
				when @terminator
					return :done # hit the end of the string
				else
					@string << char
					return false
				end
			end
			
			def inspect_r(l = 0)
				return "#{' '*l}String[#{@terminator}#{@string.string}#{@terminator}]"
			end
		end
		
		class BareWord
			def string
				@string.string
			end
			
			def initialize(first_char = nil)
				@string = StringIO.new
				@string << first_char if (first_char)
			end
			def next(char)
				case char
				when ' ', "\t", "\n", '(', ')', '{', '}', ',', nil
					return char # hit a termination case for a bareword
				else
					@string << char
					return false
				end
			end
			def inspect_r(l = 0)
				return "#{' '*l}BareWord[#{@string.string}]"
			end
		end
		
		class Tree < TupleSet
			def initialize()
				super(:file)
			end
			
			# Takes an input stream and returns a parse Tree object 
			# with the full graph of the input.
			def Tree.parse(input_stream)
				# always start a stream in the line tuple mode.
				tree = self.new

				input_stream.each_byte {|b|
					c = b.chr
					tree.next(c)
				}
				tree.next(nil)
				return tree
			end
		end
	end
end
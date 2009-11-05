# This parser is implemented purely by brute force with no attempt at elegance or performance.
require 'stringio'

module Channel
 	module Parser		
		# base class for parse tree nodes provides
		# tools for the node-type subclasses.
		class Node
		  def self.node_type_from_first_character(char)
  			return case char
  			when '{' then TupleSet.new(:line)
  			when '(' then TupleSet.new(:comma)
  			when '"' then StringConstant.new(:complex)
  			when "'" then StringConstant.new(:simple)
  		  when '$', '@' then Reference.new(char) 
  			else BareWord.new(char)
  			end
  		end
	  end
		
		# A tuple is a set of values separated by spaces in the input document.
		# Tuples are (almost?) always part of a TupleSet, which is either a 
		# comma or \n separated set of tuples.
		class Tuple < Node
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
				@current_value = Node::node_type_from_first_character(char)
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
		
		# A tuple set is a container of tuples (see above). These are usually
		# surrounded by a {} or (), depending on what type of tuple set they
		# are (usually based on context). A .ch file is also a special case
		# of a tuple set. 
		class TupleSet < Node
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
		
		# A string constant is a quoted string of arbitrary length and
		# content. It's surrounded by either "s or 's.
		class StringConstant < Node
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
		
		# A bareword is a short, whitespace or symbol separated,
		# string that can be used either as a control term by the
		# underlying language or as just a special string by the 
		# code itself.
		class BareWord < Node
		  attr_reader :type
		  
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
		
		# A reference is similar to a bareword, except is prefixed
		# by a $ or @ symbol. It is expected to be used to identify
		# variable use in the language.
		class Reference < Node
		  attr_reader :type
		  def string
		    @string.string
	    end
	    
	    def initialize(type)
	      @type = type
	      @string = StringIO.new
      end
      def next(char)
        case char
        when 'a'..'z', 'A'..'Z', '0'..'9', '_'
          @string << char
          return false
        else
          return char
        end
      end
      def inspect_r(l = 0)
        return "#{' '*l}Reference[#{@type}#{@string.string}]"
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
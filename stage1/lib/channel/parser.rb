# This parser is implemented purely by brute force with no attempt at elegance or performance.
require 'stringio'

module Channel
 	module Parser		
		# base class for parse tree nodes provides
		# tools for the node-type subclasses.
		class Node
		  def self.node_type_from_first_character(char)
  			return case char
  			when '{', '(' then TupleSet.new_parser
  			when '"', "'" then StringConstant.new_parser
  		  when '$', '@' then Reference.new_parser
  			else BareWord.new_parser
  			end
  		end

			# Use this to initialize a new parser instance of the 
			# node. Calls initialize_parser() after normal initialization.
			# Initialize() of all parser derivatives should at least be
			# able to take 0 arguments, but should otherwise be usable
			# to construct nodes for comparison or tree manipulation.
			def Node.new_parser(*args)
				x = self.new
				x.initialize_parser(*args)
				return x
			end
			
			def initialize_parser(); end

			# Takes an input stream and returns a parse Tree object 
			# with the full graph of the input.
			def Node.parse(input_stream, *context)
				# always start a stream in the line tuple mode.
				node = self.new_parser(*context)

				input_stream.each_byte {|b|
					c = b.chr
					if (node.next(c))
						return node # early finish, bail out.
					end
				}
				node.next(nil)
				return node
			end
	  end
		
		# A tuple is a set of values separated by spaces in the input document.
		# Tuples are (almost?) always part of a TupleSet, which is either a 
		# comma or \n separated set of tuples.
		class Tuple < Node
			attr_reader :type
			attr_reader :values
			
			def initialize(values = [], type = :comma)
				@type = type
				@values = values
			end
			def initialize_parser(type, splitter, terminator)
				@type = type
				@splitter = splitter
				@terminator = terminator
				
				@current_value = nil
			end
			def ==(other)
				@type == other.type && @values == other.values
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
				@current_value.next(char)
				return false
			end
			
			def empty?
			  return @values.empty?
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
			attr_reader :type, :tuples
			
			def initialize(tuples = [], type = :comma)
				@type = type
				@tuples = tuples
			end
			def initialize_parser(type = :unknown)
				@type = type
				case type
				when :file
					@splitter = "\n"
					@terminator = nil
					@current_tuple = Tuple.new_parser(@type, @splitter, @terminator)
				when :unknown
					@splitter = nil
					@terminator = nil
					@current_tuple = nil
				end
				@tuples = []
			end
			def ==(other)
				@type == other.type && @tuples == other.tuples
			end
			def next(char)
				if (@type == :unknown)
					case char
					when '{'
						@type = :line
						@splitter = "\n"
						@terminator = '}'
					when '('
						@type = :comma
						@splitter = ','
						@terminator = ')'
					end
					@current_tuple = Tuple.new_parser(@type, @splitter, @terminator)
					return false
				end
				
				if (@current_tuple)
					status = @current_tuple.next(char)
					return false if (status == false)
					
					@tuples << @current_tuple if (!@current_tuple.empty?) # only if not empty.
					@current_tuple = Tuple.new_parser(@type, @splitter, @terminator)
					return false if (status == :done) # no character was passed back, so do nothing 'til the next character
					char = status # if we get here, a character was passed back so process it.
				end
				
				if (char == @terminator)
					return :done
				end
				return false
			end
			
			def empty?
			  return @tuples.empty?
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
			attr_reader :type
			
			def initialize(string = "", type = :complex)
				@string = StringIO.new
				@string << string
				@type = type
			end
			def initialize_parser()
				@type = :unknown
				@terminator = nil
				@string = StringIO.new()
				@escape = false
			end
			def ==(other)
				string == other.string && type == other.type
			end
			def next(char)
				if (@type == :unknown)
					@type = case char
						when '"' then :complex
						when "'" then :simple
						end
					@terminator = char
					return false
				end
				
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
			
			def initialize(string = "")
				@string = StringIO.new
				@string << string
			end
			def initialize_parser(first_char = nil)
				@string = StringIO.new
				@string << first_char if (first_char)
			end
			def ==(other)
				type == other.type && string == other.string
			end
			def next(char)
				case char
				when ' ', "\t", "\n", '(', ')', '{', '}', ',', '"', "'", '$', '@', nil
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
	    
			def initialize(string = "", type = '$')
				@type = type
				@string = StringIO.new
				@string << string
			end
	    def initialize_parser()
	      @type = :unknown
	      @string = StringIO.new
      end
			def ==(other)
				type == other.type && string == other.string
			end
      def next(char)
				if (@type == :unknown)
					@type = char
					return false
				end
	
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
			def initialize_parser()
				super(:file)
			end
		end
	end
end
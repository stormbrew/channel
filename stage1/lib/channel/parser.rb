# This parser is implemented purely by brute force with no attempt at elegance or performance.
require 'stringio'

class Symbol
	def inspect_r()
		return ":#{to_s}"
	end
end
class String
	def inspect_r()
		return "'#{gsub("\\", "\\\\")}'"
	end
end

module Channel
 	module Parser
		# base class for parse tree nodes provides
		# tools for the node-type subclasses.
		class Node
		  def self.node_type_from_first_character(char)
  			return case char
  			when '{', '(' then TupleSet.new_parser
  			when '"', "'", '#' then StringConstant.new_parser
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
			
			# use to generate a tree of nodes in a prettier way than NodeType.new(...) which
			# gets almost impossible to read more than one or two levels deep.
			# Node subtypes can overload new_pretty in order to deal with child items,
			# which should be run back through Node[] to generate the proper objects.
			def Node.[](*args)
				self.new(*args)
			end
	  end
		
		# A tuple is a set of values separated by spaces in the input document.
		# Tuples are (almost?) always part of a TupleSet, which is either a 
		# comma or \n separated set of tuples.
		class Tuple < Node
			attr_reader :type
			attr_reader :values
						
			def initialize(type = :comma, values = [])
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
				self.class == other.class && @type == other.type && @values == other.values
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
				when ':'
					@current_value = Label.new_parser(@values.pop) # take the last value off the list and make it the lhs of the pair.
					return false
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
				t = ' '*l
				s = StringIO.new()
				s << t << %Q{Tuple[:#{type}, [\n}
				s << @values.collect {|val|
					val.inspect_r(l+1)
				}.join(",\n")
				s << "\n" << t << %Q{]]}
				return s.string
			end
		end
		
		class Label < Node
			attr_reader :key, :value
			
			def initialize(key = nil, value = nil)
				@key, @value = key, value
			end
			def initialize_parser(key)
				@key = key
			end
			
			def next(char)
				if (@value == nil)
					if (char =~ /[\n\t ]/) # eat leading whitespace
						return false
					end
					@value = Node::node_type_from_first_character(char)
				end
				return @value.next(char)
			end
			
			def ==(other)
				self.class == other.class && @key == other.key && @value == other.value
			end
			
			def inspect_r(l = 0)
				t = ' '*l
				s = StringIO.new()
				s << t << %Q{Label[\n}
				s << @key.inspect_r(l + 1) << ",\n"
				s << @value.inspect_r(l + 1) << "\n"
				s << t << "]"
				return s.string
			end
		end
		
		# A tuple set is a container of tuples (see above). These are usually
		# surrounded by a {} or (), depending on what type of tuple set they
		# are (usually based on context). A .ch file is also a special case
		# of a tuple set. 
		class TupleSet < Node
			attr_reader :type, :tuples
			
			def TupleSet.new_pretty(type = :comma, tuples = [])
				self.new(tuples.collect {|val| Node[*val] }, type)
			end
			
			def initialize(type = :comma, tuples = [])
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
				self.class == other.class && @type == other.type && @tuples == other.tuples
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
				t = " " * l
				s = StringIO.new
				s << t << "TupleSet[:#{type}, [\n"
				s << @tuples.collect {|tuple|
					tuple.inspect_r(l + 1)
				}.join(",\n")
				s << "\n" << t << "]]"
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
			
			def self.map_terminator(char)
				char.tr('{([', '})]') # these three, give their opposite. Otherwise, leave it the same.
			end
			
			def initialize(type = '"', string = "")
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
				self.class == other.class && string == other.string && type == other.type
			end
			def next(char)
				if (@type == :unknown)
					@type = char
					if (@type != '#')
						@terminator = char
					end
					return false
				elsif (@type == '#') # # is incomplete, needs a subtype
					@type << char
					case @type # handle special cases for comments
					when '##', '# ' # line end 'comments'
						@terminator = "\n"
					# when '#*' later make this a multiline comment ending with *#, but figure out later.
					end
					return false
				elsif (@type =~ /#./ && @terminator.nil?) # #x is still incomplete without a terminator
					@terminator = StringConstant.map_terminator(char)
					return false
				end
				
				if (@escape)
					if (char == @terminator) # only escape the terminator, leave everything else to the next level.
						@string << char
					else
						@string << "\\" << char
					end	
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
				return %Q{#{' '*l}StringConstant[:#{@type}, #{string.inspect_r}]}
			end
		end
		
		# A bareword is a short, whitespace or symbol separated,
		# string that can be used either as a control term by the
		# underlying language or as just a special string by the 
		# code itself.
		class BareWord < Node
			def string
				@string.string
			end
			
			def initialize(string = "")
				@string = StringIO.new
				@string << string
			end
			def initialize_parser()
				@string = StringIO.new
				@type = :unknown
			end
			def ==(other)
				self.class == other.class && string == other.string
			end
			def next(char)
				if (char =~ /[ \t\n(){},"'$@]/ || char.nil?)
					return char
				end
				
				char_type = (char =~ /[a-zA-Z0-9_]/)? :alnumunder : :symbol
				if (@type == :unknown)
					@type = char_type
				end
				
				case @type
				when :alnumunder
					if (char_type == :alnumunder)
						@string << char
						return false
					else
						return char
					end
				when :symbol
					if (char_type == :symbol)
						@string << char
						return false
					else
						return char
					end
				end
			end
			def inspect_r(l = 0)
				return "#{' '*l}BareWord[#{string.inspect_r}]"
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
	    
			def initialize(type = '$', string = "")
				@type = type
				@string = StringIO.new
				@string << string
			end
	    def initialize_parser()
	      @type = :unknown
	      @string = StringIO.new
      end
			def ==(other)
				self.class == other.class && type == other.type && string == other.string
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
        return "#{' '*l}Reference[#{@type.inspect_r}, #{string.inspect_r}]"
      end
    end
		
		class Tree < TupleSet
			def initialize_parser()
				super(:file)
			end
			def initialize(*tuples)
				super(:file, tuples)
			end
			def inspect_r(l = 0)
				t = " " * l
				s = StringIO.new
				s << t << "Tree[\n"
				s << @tuples.collect {|tuple|
					tuple.inspect_r(l + 1)
				}.join(",\n")
				s << "\n" << t << "]"
				return s.string
			end				
		end
	end
end
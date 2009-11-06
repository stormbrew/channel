require "lib/channel/parser"

class StringIO
	alias :inspect_orig :inspect
	def inspect
		return inspect_orig + "(#{self.string})"
	end
end

describe Channel::Parser do
	module Channel::Parser
		describe Node do
			it "should let you build a simple node set using array syntax" do
				Tree[] == Tree.new()
			end
			
			it "should be able to figure out a node type from a recognized first character" do
				# note: these match :unknown because they haven't actually been passed the first character.
				Node::node_type_from_first_character("{").should == TupleSet[:unknown]
				Node::node_type_from_first_character("(").should == TupleSet[:unknown]
				Node::node_type_from_first_character("'").should == StringConstant[:unknown]
				Node::node_type_from_first_character('"').should == StringConstant[:unknown]
				Node::node_type_from_first_character("$").should == Reference[:unknown]
				Node::node_type_from_first_character("@").should == Reference[:unknown]
			end
			
			it "should assume anything else is a 'bareword'" do
				# note: these match :unknown because they haven't actually been passed the first character.
				Node::node_type_from_first_character("a").should == BareWord[]
				Node::node_type_from_first_character("1").should == BareWord[]
			end
			
			it "should let you build complex node sets using array syntax" do
				TupleSet[:line, [
					Tuple[:line, [BareWord['blah']]], 
					Tuple[:line, [BareWord['blorp']]], 
				]].should == TupleSet.new(:line, [Tuple.new(:line, [BareWord.new('blah')]), Tuple.new(:line, [BareWord.new('blorp')])])
			end
		end
		
		describe BareWord do
			it "should accept a simple set of allowable characters as a bareword" do
				BareWord::parse("abcd").should == BareWord["abcd"]
			end
			it "should stop parsing on a recognized end character" do
				BareWord::parse("abcd{}").should == BareWord["abcd"]
				BareWord::parse("abcd()").should == BareWord["abcd"]
				BareWord::parse("abcd'").should == BareWord["abcd"]
				BareWord::parse("abcd\"").should == BareWord["abcd"]
				BareWord::parse("abcd$").should == BareWord["abcd"]
				BareWord::parse("abcd@").should == BareWord["abcd"]
				BareWord::parse("abcd,").should == BareWord["abcd"]
				BareWord::parse("abcd ").should == BareWord["abcd"]
				BareWord::parse("abcd\n").should == BareWord["abcd"]
				BareWord::parse("abcd\t").should == BareWord["abcd"]
			end
		end

		describe StringConstant do
			it "should accept a simple string" do
				StringConstant::parse(%Q{'blah'}).should == StringConstant[:simple, 'blah']
			end
			it "should accept a complex string" do
				StringConstant::parse(%Q{"blah"}).should == StringConstant[:complex, 'blah']
			end
			it "should allow escaping on a complex string" do
				StringConstant::parse(%Q{"blorp\\"blah"}).should == StringConstant[:complex, %Q{blorp"blah}]
			end
			it "should not allow escaping on a simple string" do
				StringConstant::parse(%Q{'blorp\\'blah'}).should == StringConstant[:simple, %{blah\\'blorp}]
			end
		end
		
		describe Reference do
			it "should accept a $ value" do
				Reference::parse(%Q{$blah}).should == Reference['$', %Q{blah}]
			end
			it "should accept an @ value" do
				Reference::parse(%Q{@blah}).should == Reference['@', %Q{blah}]
			end
		end
		
		describe Tuple do
			it "should create an empty tuple from an empty string" do
				Tuple::parse(%Q{}, :file, "\n", nil).should == Tuple[:file, []]
			end
			it "should create a single value tuple from any of the scalar subtypes" do
				Tuple::parse(%Q{blah}, :file, "\n", nil).should == Tuple[:file, [BareWord['blah']]]
				Tuple::parse(%Q{"blah"}, :file, "\n", nil).should == Tuple[:file, [StringConstant[:complex, 'blah']]]
				Tuple::parse(%Q{'blah'}, :file, "\n", nil).should == Tuple[:file, [StringConstant[:simple, 'blah']]]
				Tuple::parse(%Q{$blah}, :file, "\n", nil).should == Tuple[:file, [Reference['$', 'blah']]]
				Tuple::parse(%Q{@blah}, :file, "\n", nil).should == Tuple[:file, [Reference['@', 'blah']]]
			end
			it "should be able to have TupleSets within it" do
				Tuple::parse(%Q|()|, :file, "\n", nil).should == Tuple[:file, [TupleSet[:comma, []]]]
				Tuple::parse(%Q|{}|, :file, "\n", nil).should == Tuple[:file, [TupleSet[:line, []]]]
			end
			it "should create composite tuples from multiple values" do
				Tuple::parse(%Q{blah "blah" $blorp}, :file, "\n", nil).should == Tuple[:file, [BareWord['blah'], StringConstant[:complex, 'blah'], Reference['$', 'blorp']]]
			end
			it "should ignore leading and trailing whitespace" do
			  Tuple::parse(%Q{   blah\tblorp }, :file, "\n", nil).should == Tuple[:file, [BareWord['blah'], BareWord['blorp']]]
		  end
		end
		
		describe TupleSet do
			it "should create an empty tupleset from empty braces" do
				TupleSet::parse(%Q|{}|).should == TupleSet[:line, []]
				TupleSet::parse(%Q|()|).should == TupleSet[:comma, []]
			end
			it "should create a tupleset with a single tuple in it" do
				TupleSet::parse(%Q|{blah}|).should == TupleSet[:line, [Tuple[:line, [BareWord['blah']]]]]
				TupleSet::parse(%Q|(blah)|).should == TupleSet[:comma, [Tuple[:comma, [BareWord['blah']]]]]
			end
			it "should create a tupleset with multiple tuples in it" do
				TupleSet::parse(%Q|{blah\nblorp}|).should == TupleSet[:line, [Tuple[:line, [BareWord['blah']]], Tuple[:line, [BareWord['blorp']]]]]
				TupleSet::parse(%Q|(blah,blorp)|).should == TupleSet[:comma, [Tuple[:comma, [BareWord['blah']]], Tuple[:comma, [BareWord['blorp']]]]]
			end
		end
	
		describe Tree do
			it "should be able to parse a very simple file" do
				File.open("test/data/really_simple.ch") {|f|
					Tree::parse(f).should == Tree[[Tuple[:file, [BareWord['a']]]]]
				}
			end
			it "should be able to parse the baseline sample file" do
				File.open("test/data/sample.ch") {|f|
					#Tree::parse(f).should == TupleSet.new([Tuple.new([BareWord['a')], :file)], :file) # TODO: generate matching data
				}
			end
			it "should be able to parse the closure sample file" do
				File.open("test/data/closure_sample.ch") {|f|
					#Tree::parse(f).should == TupleSet.new([Tuple.new([BareWord['a')], :file)], :file) # TODO: generate matching data
				}
			end
			it "should be able to parse the object sample file" do
				File.open("test/data/object_sample.ch") {|f|
					#Tree::parse(f).should == TupleSet.new([Tuple.new([BareWord['a')], :file)], :file) # TODO: generate matching data
				}
			end
		end
	end
end
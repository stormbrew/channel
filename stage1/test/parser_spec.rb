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
			it "should be able to figure out a node type from a recognized first character" do
				# note: these match :unknown because they haven't actually been passed the first character.
				Node::node_type_from_first_character("{").should == TupleSet.new([], :unknown)
				Node::node_type_from_first_character("(").should == TupleSet.new([], :unknown)
				Node::node_type_from_first_character("'").should == StringConstant.new("", :unknown)
				Node::node_type_from_first_character('"').should == StringConstant.new("", :unknown)
				Node::node_type_from_first_character("$").should == Reference.new("", :unknown)
				Node::node_type_from_first_character("@").should == Reference.new("", :unknown)
			end
			
			it "should assume anything else is a 'bareword'" do
				# note: these match :unknown because they haven't actually been passed the first character.
				Node::node_type_from_first_character("a").should == BareWord.new("")
				Node::node_type_from_first_character("1").should == BareWord.new("")
			end
		end
		
		describe BareWord do
			it "should accept a simple set of allowable characters as a bareword" do
				BareWord::parse("abcd").should == BareWord.new("abcd")
			end
			it "should stop parsing on a recognized end character" do
				BareWord::parse("abcd{}").should == BareWord.new("abcd")
				BareWord::parse("abcd()").should == BareWord.new("abcd")
				BareWord::parse("abcd'").should == BareWord.new("abcd")
				BareWord::parse("abcd\"").should == BareWord.new("abcd")
				BareWord::parse("abcd$").should == BareWord.new("abcd")
				BareWord::parse("abcd@").should == BareWord.new("abcd")
				BareWord::parse("abcd,").should == BareWord.new("abcd")
				BareWord::parse("abcd ").should == BareWord.new("abcd")
				BareWord::parse("abcd\n").should == BareWord.new("abcd")
				BareWord::parse("abcd\t").should == BareWord.new("abcd")
			end
		end

		describe StringConstant do
			it "should accept a simple string" do
				StringConstant::parse(%Q{'blah'}).should == StringConstant.new('blah', :simple)
			end
			it "should accept a complex string" do
				StringConstant::parse(%Q{"blah"}).should == StringConstant.new('blah', :complex)
			end
			it "should allow escaping on a complex string" do
				StringConstant::parse(%Q{"blorp\\"blah"}).should == StringConstant.new(%Q{blorp"blah}, :complex)
			end
			it "should not allow escaping on a simple string" do
				StringConstant::parse(%Q{'blorp\\'blah'}).should == StringConstant.new(%{blah\\'blorp}, :simple)
			end
		end
		
		describe Reference do
			it "should accept a $ value" do
				Reference::parse(%Q{$blah}).should == Reference.new(%Q{blah}, '$')
			end
			it "should accept an @ value" do
				Reference::parse(%Q{@blah}).should == Reference.new(%Q{blah}, '@')
			end
		end
		
		describe Tuple do
			it "should create an empty tuple from an empty string" do
				Tuple::parse(%Q{}, :file, "\n", nil).should == Tuple.new([], :file)
			end
			it "should create a single value tuple from any of the scalar subtypes" do
				Tuple::parse(%Q{blah}, :file, "\n", nil).should == Tuple.new([BareWord.new('blah')], :file)
				Tuple::parse(%Q{"blah"}, :file, "\n", nil).should == Tuple.new([StringConstant.new('blah', :complex)], :file)
				Tuple::parse(%Q{'blah'}, :file, "\n", nil).should == Tuple.new([StringConstant.new('blah', :simple)], :file)
				Tuple::parse(%Q{$blah}, :file, "\n", nil).should == Tuple.new([Reference.new('blah', '$')], :file)
				Tuple::parse(%Q{@blah}, :file, "\n", nil).should == Tuple.new([Reference.new('blah', '@')], :file)
			end
			it "should be able to have TupleSets within it" do
				Tuple::parse(%Q|()|, :file, "\n", nil).should == Tuple.new([TupleSet.new([], :comma)], :file)
				Tuple::parse(%Q|{}|, :file, "\n", nil).should == Tuple.new([TupleSet.new([], :line)], :file)
			end
			it "should create composite tuples from multiple values" do
				Tuple::parse(%Q{blah "blah" $blorp}, :file, "\n", nil).should == Tuple.new([BareWord.new('blah'), StringConstant.new('blah', :complex), Reference.new('blorp', '$')], :file)
			end
		end
		
		describe TupleSet do
			it "should create an empty tupleset from empty braces" do
				TupleSet::parse(%Q|{}|).should == TupleSet.new([], :line)
				TupleSet::parse(%Q|()|).should == TupleSet.new([], :comma)
			end
			it "should create a tupleset with a single tuple in it" do
				TupleSet::parse(%Q|{blah}|).should == TupleSet.new([Tuple.new([BareWord.new('blah')], :line)], :line)
				TupleSet::parse(%Q|(blah)|).should == TupleSet.new([Tuple.new([BareWord.new('blah')], :comma)], :comma)
			end
			it "should create a tupleset with multiple tuples in it" do
				TupleSet::parse(%Q|{blah\nblorp}|).should == TupleSet.new([Tuple.new([BareWord.new('blah')], :line), Tuple.new([BareWord.new('blorp')], :line)], :line)
				TupleSet::parse(%Q|(blah,blorp)|).should == TupleSet.new([Tuple.new([BareWord.new('blah')], :comma), Tuple.new([BareWord.new('blorp')], :comma)], :comma)
			end
		end
	
		describe Tree do
			it "should be able to parse a very simple file" do
				File.open("test/data/really_simple.ch") {|f|
					Tree::parse(f).should == TupleSet.new([Tuple.new([BareWord.new('a')], :file)], :file)
				}
			end
			it "should be able to parse the baseline sample file" do
				File.open("test/data/sample.ch") {|f|
					Tree::parse(f).should == TupleSet.new([Tuple.new([BareWord.new('a')], :file)], :file) # TODO: generate matching data
				}
			end
			it "should be able to parse the closure sample file" do
				File.open("test/data/closure_sample.ch") {|f|
					Tree::parse(f).should == TupleSet.new([Tuple.new([BareWord.new('a')], :file)], :file) # TODO: generate matching data
				}
			end
			it "should be able to parse the object sample file" do
				File.open("test/data/object_sample.ch") {|f|
					Tree::parse(f).should == TupleSet.new([Tuple.new([BareWord.new('a')], :file)], :file) # TODO: generate matching data
				}
			end
		end
	end
end
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
				StringConstant::parse(%Q{"blorp\"blah"}).should == StringConstant.new('blah"blorp', :complex)
			end
			it "should not allow escaping on a simple string" do
				StringConstant::parse(%Q{'blorp\"blah"}).should == StringConstant.new('blah\"blorp', :simple)
			end
		end
	end
end
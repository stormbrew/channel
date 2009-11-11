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
				Node::node_type_from_first_character('a').should == BareWord['']
				Node::node_type_from_first_character('1').should == Number['']
				Node::node_type_from_first_character('<').should == Symbolic['']
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
				BareWord::parse("abcd:").should == BareWord["abcd"]
				BareWord::parse("abcd#").should == BareWord["abcd"]
			end
		end
		describe Number do
			it "should accept any number of numeric characters" do
				Number::parse("1124342342342342").should == Number["1124342342342342"]
			end
			it "should accept one decimal, and no more than one decimal, in the string" do
				Number::parse("12343242.324").should == Number["12343242.324"]
				Number::parse("12343242.324.32").should == Number["12343242.324"]
			end
		end
		
		describe Symbolic do
			it "should accept any number of symbolic characters" do
				Symbolic::parse("!$%&*+-./;<=>?`|~").should == Symbolic["!$%&*+-./;<=>?`|~"]
				Symbolic::parse("!$%&*+-./;<=>?`|~safs").should == Symbolic["!$%&*+-./;<=>?`|~"]
				Symbolic::parse("!$%&*+-./;<=>?`|~,").should == Symbolic["!$%&*+-./;<=>?`|~"]
				Symbolic::parse("!$%&*+-./;<=>?`|~3432").should == Symbolic["!$%&*+-./;<=>?`|~"]
			end
		end

		describe StringConstant do
			it "should accept a simple string" do
				StringConstant::parse(%Q{'blah'}).should == StringConstant["'", 'blah']
			end
			it "should accept a complex string" do
				StringConstant::parse(%Q{"blah"}).should == StringConstant['"', 'blah']
			end
			it "should accept an arbitrary delimited string with a simple delimiter" do
				StringConstant::parse('#r|blah|').should == StringConstant['#r', 'blah']
				StringConstant::parse('#rAblahA').should == StringConstant['#r', 'blah']
				StringConstant::parse('#r/blah/').should == StringConstant['#r', 'blah']
			end
			it "should accept an arbitrary delimited string with a bracket delimiter" do
				StringConstant::parse('#r{blah}').should == StringConstant['#r', 'blah']
				StringConstant::parse('#r[blah]').should == StringConstant['#r', 'blah']
				StringConstant::parse('#r(blah)').should == StringConstant['#r', 'blah']
			end
			it "should accept hash-space or hash-hash as line end comments" do
				StringConstant::parse("\# blah\nblorp").should == StringConstant['# ', 'blah']
				StringConstant::parse("\#\#blah\nblorp").should == StringConstant['##', 'blah']
			end
			it "should accept hash-star as a multiline comment terminated by star-hash" do
				# StringConstant::parse("\#*blah blah\nblorp blorp*# womper doodle").should == StringConstant['#*', "blah blah\nblorp blorp"]
			end
			it "should escape the terminator" do
				StringConstant::parse(%Q{"blorp\\"blah"}).should == StringConstant['"', %Q{blorp"blah}]
				StringConstant::parse(%Q{'blorp\\'blah'}).should == StringConstant["'", %Q{blorp'blah}]
				StringConstant::parse('#r{blorp\\}blah}').should == StringConstant['#r', %Q|blorp}blah|]
			end
			it "should not escape anything that's not the terminator" do
				StringConstant::parse(%Q{'blorp\\"blah'}).should == StringConstant["'", %Q{blorp\\"blah}]
			end
			it "should ignore an escaped backslash before the terminator, but pass through the double backslash (and terminate the string)" do
				StringConstant::parse(%Q{'blorp\\\\'blah'}).should == StringConstant["'", %Q{blorp\\\\}]
			end
		end
		
		describe Tuple do
			it "should create an empty tuple from an empty string" do
				Tuple::parse(%Q{}, :file, "\n", nil).should == Tuple[:file, []]
			end
			it "should create a single value tuple from any of the scalar subtypes" do
				Tuple::parse(%Q{blah}, :file, "\n", nil).should == Tuple[:file, [BareWord['blah']]]
				Tuple::parse(%Q{11.2}, :file, "\n", nil).should == Tuple[:file, [Number['11.2']]]
				Tuple::parse(%Q{<<}, :file, "\n", nil).should == Tuple[:file, [Symbolic['<<']]]
				Tuple::parse(%Q{"blah"}, :file, "\n", nil).should == Tuple[:file, [StringConstant['"', 'blah']]]
				Tuple::parse(%Q{'blah'}, :file, "\n", nil).should == Tuple[:file, [StringConstant["'", 'blah']]]
			end
			it "should be able to have TupleSets within it" do
				Tuple::parse(%Q|()|, :file, "\n", nil).should == Tuple[:file, [TupleSet[:comma, []]]]
				Tuple::parse(%Q|{}|, :file, "\n", nil).should == Tuple[:file, [TupleSet[:line, []]]]
			end
			it "should create composite tuples from multiple values" do
				Tuple::parse(%Q{blah "blah" 11.5}, :file, "\n", nil).should == Tuple[:file, [BareWord['blah'], StringConstant['"', 'blah'], Number['11.5']]]
			end
			it "should ignore leading and trailing whitespace" do
			  Tuple::parse(%Q{   blah\tblorp }, :file, "\n", nil).should == Tuple[:file, [BareWord['blah'], BareWord['blorp']]]
		  end
		end
		
		describe Label do
			it "should generate a label from a tuple with a : in it" do
				Tuple::parse(%Q{blah:blorp}, :file, "\n", nil).should == Tuple[:file, [Label[BareWord['blah'], BareWord['blorp']]]]
			end
			it "should properly deal with tuple values preceeding or succeeding the label not being part of the label" do
				Tuple::parse(%Q{blah blorp: what wut}, :file, "\n", nil).should == Tuple[:file, [BareWord['blah'], Label[BareWord['blorp'], BareWord['what']], BareWord['wut']]]
			end
			it "should allow composite types on either or both sides of the :" do
				Tuple::parse(%Q{(a, b): c}, :file, "\n", nil).should == Tuple[:file, [
				 Label[
				  TupleSet[:comma, [
				   Tuple[:comma, [
				    BareWord['a']
				   ]],
				   Tuple[:comma, [
				    BareWord['b']
				   ]]
				  ]],
				  BareWord['c']
				 ]
				]]
				Tuple::parse(%Q{c: (a, b)}, :file, "\n", nil).should == Tuple[:file, [
				 Label[
				  BareWord['c'],
				  TupleSet[:comma, [
				   Tuple[:comma, [
				    BareWord['a']
				   ]],
				   Tuple[:comma, [
				    BareWord['b']
				   ]]
				  ]]
				 ]
				]]
				
				Tuple::parse(%Q{(a, b): (a, b)}, :file, "\n", nil).should == Tuple[:file, [
				 Label[
				  TupleSet[:comma, [
				   Tuple[:comma, [
				    BareWord['a']
				   ]],
				   Tuple[:comma, [
				    BareWord['b']
				   ]]
				  ]],
				  TupleSet[:comma, [
				   Tuple[:comma, [
				    BareWord['a']
				   ]],
				   Tuple[:comma, [
				    BareWord['b']
				   ]]
				  ]]
				 ]
				]]
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
					Tree::parse(f).should == Tree[Tuple[:file, [BareWord['a']]]]
				}
			end
			it "should be able to parse the baseline sample file" do
				File.open("test/data/sample.ch") {|f|
					Tree::parse(f).should == Tree[
					 Tuple[:file, [
					  BareWord['function'],
					  BareWord['blah'],
					  TupleSet[:comma, [
					   Tuple[:comma, [
					    BareWord['arg1']
					   ]],
					   Tuple[:comma, [
					    BareWord['arg2']
					   ]],
					   Tuple[:comma, [
					    BareWord['arg3']
					   ]]
					  ]],
					  Label[
					   BareWord['do'],
					   TupleSet[:line, [
					    Tuple[:line, [
					     BareWord['if'],
					     Label[
					      TupleSet[:comma, [
					       Tuple[:comma, [
					        Symbolic['$'], BareWord['arg1'],
					        Symbolic['=='],
					        Symbolic['$'], BareWord['arg2']
					       ]]
					      ]],
					      TupleSet[:line, [
					       Tuple[:line, [
					        BareWord['echo'],
					        TupleSet[:comma, [
					         Tuple[:comma, [
					          StringConstant['"', '"boom"']
					         ]]
					        ]]
					       ]]
					      ]]
					     ],
					     Label[
					      BareWord['else'],
					      TupleSet[:line, [
					       Tuple[:line, [
					        BareWord['echo'],
					        TupleSet[:comma, [
					         Tuple[:comma, [
					          Symbolic['$'], BareWord['arg3']
					         ]]
					        ]]
					       ]]
					      ]]
					     ]
					    ]]
					   ]]
					  ]
					 ]]
					]
				}
			end
			it "should be able to parse the closure sample file" do
				File.open("test/data/closure_sample.ch") {|f|
					Tree::parse(f).should == Tree[
					 Tuple[:file, [
					  BareWord['var'],
					  BareWord['x'],
					  Symbolic['='],
					  BareWord['proc'],
					  TupleSet[:comma, [
					   Tuple[:comma, [
					    BareWord['arg']
					   ]]
					  ]],
					  Label[
					   BareWord['do'],
					   TupleSet[:line, [
					    Tuple[:line, [
					     BareWord['echo'],
					     TupleSet[:comma, [
					      Tuple[:comma, [
					       Symbolic['$'], BareWord['arg']
					      ]]
					     ]]
					    ]]
					   ]]
					  ]
					 ]],
					 Tuple[:file, [
					  Symbolic['$'], BareWord['x'],
					  Symbolic['.'],
					  BareWord['call'],
					  TupleSet[:comma, [
					   Tuple[:comma, [
					    StringConstant['"', 'blah']
					   ]]
					  ]]
					 ]],
					 Tuple[:file, [
					  Symbolic['$'], BareWord['x'],
					  TupleSet[:comma, [
					   Tuple[:comma, [
					    StringConstant['"', 'blah']
					   ]]
					  ]]
					 ]]
					]
				}
			end
			it "should be able to parse the object sample file" do
				File.open("test/data/object_sample.ch") {|f|
					Tree::parse(f).should == Tree[
					 Tuple[:file, [
					  BareWord['class'],
					  BareWord['Blah'],
					  Label[
					   BareWord['define'],
					   TupleSet[:line, [
					    Tuple[:line, [
					     BareWord['function'],
					     BareWord['blah'],
					     TupleSet[:comma, [
					      Tuple[:comma, [
					       BareWord['arg1']
					      ]],
					      Tuple[:comma, [
					       BareWord['arg2']
					      ]]
					     ]],
					     Label[
					      BareWord['do'],
					      TupleSet[:line, [
					       Tuple[:line, [
					        BareWord['echo'],
					        TupleSet[:comma, [
					         Tuple[:comma, [
					          Symbolic['$'], BareWord['arg1']
					         ]]
					        ]]
					       ]],
					       Tuple[:line, [
					        Symbolic['@'], BareWord['tmp'],
					        Symbolic['='],
					        Symbolic['$'], BareWord['arg2']
					       ]]
					      ]]
					     ]
					    ]],
					    Tuple[:line, [
					     BareWord['function'],
					     BareWord['blorp'],
					     TupleSet[:comma, [

					     ]],
					     Label[
					      BareWord['do'],
					      TupleSet[:line, [
					       Tuple[:line, [
					        BareWord['echo'],
					        TupleSet[:comma, [
					         Tuple[:comma, [
					          Symbolic['@'], BareWord['tmp']
					         ]]
					        ]]
					       ]]
					      ]]
					     ]
					    ]]
					   ]]
					  ]
					 ]],
					 Tuple[:file, [
					  BareWord['var'],
					  BareWord['x'],
					  Symbolic['='],
					  BareWord['Blah'],
					  Symbolic['.'],
					  BareWord['new']
					 ]],
					 Tuple[:file, [
					  Symbolic['$'], BareWord['x'],
					  Symbolic['.'],
					  BareWord['blah'],
					  TupleSet[:comma, [
					   Tuple[:comma, [
					    StringConstant['"', 'blorp']
					   ]],
					   Tuple[:comma, [
					    StringConstant['"', 'bloom']
					   ]]
					  ]]
					 ]],
					 Tuple[:file, [
					  Symbolic['$'], BareWord['x'],
					  Symbolic['.'],
					  BareWord['blorp'],
					  TupleSet[:comma, [

					  ]]
					 ]]
					]
				}
			end
		end
	end
end
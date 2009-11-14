$: << "lib"
require "channel"

$ta = [:file, '\n', nil]

include Channel::Compiler
include Channel::Parser

class Compiler
	def inspect
		return inspect_r
	end
end

describe Channel::Compiler do
	describe Compiler do
		describe '#reorder_operators' do
			it "should leave a single value roughly the same as it found it." do
				Compiler.reorder_operators(Tuple::parse("1", *$ta)).should == [[Number["1"]]]
			end
			it "should leave any number of values in the same order." do
				Compiler.reorder_operators(Tuple::parse("1 2 3 4", *$ta)).should == [[Number["1"], Number["2"], Number["3"], Number["4"]]]
			end
			it "should re-order a simple math expression into RPN" do
				Compiler.reorder_operators(Tuple::parse("1 + 2", *$ta)).should == [[Number["1"]], [Number["2"]], OperatorNode[2, Symbolic["+"]]]
			end
			it "should re-order a more complex math expression into RPN" do
				Compiler.reorder_operators(Tuple::parse("1 / !2 + 3", *$ta)).should == [
					[Number["1"]],
					[Number["2"]],
					OperatorNode[1, Symbolic["!"]],
					OperatorNode[2, Symbolic["/"]],
					[Number["3"]],
					OperatorNode[2, Symbolic["+"]]
				]
			end
			it "should be able to deal with multiple values between operators" do
				Compiler.reorder_operators(Tuple::parse("a b c d + x y / z", *$ta)).should == [
					[BareWord["a"], BareWord["b"], BareWord["c"], BareWord["d"]],
					[BareWord["x"], BareWord["y"]],
					[BareWord["z"]],
					OperatorNode[2, Symbolic["/"]],
					OperatorNode[2, Symbolic["+"]]
				]
			end
			# should end up with specs for each operator and their associativity.
		end
		describe '#dispatch_value' do
			it "should treat an array with a non-bareword and non-symbolic as a value" do
				Compiler.dispatch_value(Node.new, [Number["1"]]).should == Value[Number["1"]]
			end
			it "should raise an exception if given a multivalue (more than one value type)" do
				proc { Compiler.dispatch_value(Node.new, [Number["1"], Number["2"]]) }.should raise_error(CompilerError)
			end
			it "should treat an array with only a bareword or symbolic as the first value as a method with no arguments" do
				Compiler.dispatch_value(Node.new, [BareWord["boom"]]).should == Expression[nil, BareWord["boom"], []]
				Compiler.dispatch_value(Node.new, [Symbolic["*"]]).should == Expression[nil, Symbolic["*"], []]
			end
			it "should treat an array with a bareword as the first value of many as a method with arguments" do
				Compiler.dispatch_value(Node.new, [BareWord["x"], BareWord["blah"], Number["1"]]).should == Expression[nil, BareWord["x"], [Value[BareWord["blah"]], Value[Number["1"]]]]
			end
		end
	end
	describe Expression do
		it "should leave a single value roughly the same as it found it." do
			Tuple::parse("1", *$ta).compile.should == Statement[Value[Number["1"]]]
		end
		it "should compile a simple math expression" do
			Tuple::parse("1 + 2", *$ta).compile.should == Statement[
				Expression[
					Value[Number["1"]],
					Symbolic["+"],
					[Value[Number["2"]]],
				]
			]
		end
		it "should compile a more complicated parse tree into a working execution tree" do
			Tuple::parse("1 / !2 + 3", *$ta).compile.should == Statement[ # (1./(2.!)).+(3)
				Expression[
					Expression[						
						Value[Number["1"]],
						Symbolic["/"],
						[
							Expression[
								Value[Number["2"]],
								Symbolic["!"],
								[],
							],
						],
					],
					Symbolic["+"],
					[Value[Number["3"]]],					
				]
			]
		end
		
		it "should be able to deal with method calls between operators" do
			Tuple::parse("a b c d + x y / z", *$ta).compile.should == Statement[
				Expression[
					Expression[
						nil,
						BareWord["a"],
						[Value[BareWord["b"]], Value[BareWord["c"]], Value[BareWord["d"]]],
					],
					Symbolic["+"],
					[
						Expression[
							Expression[
								nil,
								BareWord["x"],
								[Value[BareWord["y"]]],
							],
							Symbolic["/"],
							[
								Expression[nil, BareWord["z"], []]
							],
						]
					]
				]
			]
		end
	end
end
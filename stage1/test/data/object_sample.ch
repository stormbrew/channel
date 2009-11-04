class Blah define: {
	function blah(arg1, arg2) do: {
		echo($arg1)
		@tmp = $arg2
	}
	function blorp() do: {
		echo(@tmp)
	}
}
var x = Blah.new
$x.blah("blorp", "bloom")
$x.blorp()
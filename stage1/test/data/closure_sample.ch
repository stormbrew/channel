var x = proc(arg) do: { echo($arg) }
$x.call("blah")
$x("blah")
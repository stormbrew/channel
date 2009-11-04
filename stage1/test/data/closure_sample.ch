var x = proc(arg) do: { echo($arg) }
$x.call("blah") # => "blah"
$x("blah")
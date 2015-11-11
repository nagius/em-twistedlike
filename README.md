# em-twistedlike

This Monkeypatch implement some of Twisted's defer funtionnalities to EventMachine Deferrable.
This provide convenient helper and also a better exception management during callbacks execution, ie the double callback cross-chains of Twisted.

Each Exception raised during this chain execution is wrapped into a Failure object and passed to the next error callback. The original exception can be retrieved with Failure#value.

I suggest you to be familiar with the behavior of Twisted. For more information, see http://twistedmatrix.com/documents/current/core/howto/defer.html#visual-explanation.

## Main features

 - New funtions `Deferrable#add_callback`, `Deferrable#add_errback`, `Deferrable#add_both`, `Deferrable#add_callbacks` that manage callbacks with error management, the Twisted way.
 - DeferrableList object to merge multiple Deferrable.
 - Automatically wrap Exception raised within callbacks and params sent to Deferrable#fail into a Failure object.
 - New helpers `DefaultDeferrable#failed` and `DefaultDeferrable#succeeded` to create already fired Deferrable.

## Example

```
require 'em-twistedlike'

EM.run {

    d = EM::DefaultDeferrable.new
    d.add_callback { |result|
        puts result
        raise "An error"
    }

    d.add_errback { |failure|
        puts "Errback 1: #{failure}"
        failure # Forward the error to the next errback
    }

    d.add_callback { |result|
        puts "This is not executed"
    }

    d.add_errback { |failure|
        puts "Errback 2: #{failure.value}"
        "Error is resolved" # This is the result for the next callback
    }

    d.add_callback { |result|
        puts "Final result: #{result}"
    }

    d.add_both { |result_or_failure|
        EM.stop
    }

    EM.next_tick {
        d.succeed("The result")
    }
}
```

Will produce the output :

```
The result
Errback 1: RuntimeError - An error
Errback 2: An error
Final result: Error is resolved
```

## License

Copyleft 2015 - Nicolas AGIUS
This module is released under the terms of the GNU GENERAL PUBLIC LICENSE version 3.


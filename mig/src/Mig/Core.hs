{-| Re-exports everything

With library mig we can build lightweight and composable servers.
There are only couple of combinators to assemble servers from parts.
It supports generic handler functions as servant does. But strives to use more
simple model for API. It does not go to describing Server API at type level which
leads to simpler error messages.

The main features are:

* lightweight library

* expressive DSL to compose servers

* type-safe handlers

* handlers are encoded with generic haskell functions

* built on top of WAI and warp server libraries.

Example of hello world server. To run example use library @mig-server@ which is based on core library:

> import Mig.Json.IO
>
> -- | We can render the server and run it on port 8085.
> -- It uses wai and warp.
> main :: IO ()
> main = runServer 8085 server
>
> -- | Init simple hello world server which
> -- replies on a single route
> server :: Server IO
> server =
>   "api" /. "v1" /.
>     mconcat
>       [ "hello" /. hello
>       , "bye" /. bye
>       ]
>
> -- | Handler takes no inputs and marked as Get HTTP-request that returns Text.
> hello :: Get (Resp Text)
> hello = Get $ pure $ ok "Hello World"
>
> -- | Handle with URL-param query and json body input as Post HTTP-request that returns Text.
> bye :: Query "name" Text -> Body ByeRequest -> Post (Resp Text)
> bye (Query name) (Body req) = Post $
>   pure $ ok $ "Bye to " <> name <> " " <> req.greeting

References:

* quick start guide at <https://github.com/anton-k/mig#readme>

* examples directory for more fun servers: at <https://github.com/anton-k/mig/tree/main/examples/mig-example-apps#readme>
-}
module Mig.Core (
  module X,
) where

import Mig.Core.Api as X
import Mig.Core.Class as X
import Mig.Core.OpenApi as X
import Mig.Core.Server as X
import Mig.Core.ServerFun as X
import Mig.Core.Types as X

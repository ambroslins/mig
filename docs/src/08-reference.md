# Reference

Here is the list of main functions, types and classes

### How to build server

```haskell
-- server on path
(/.) :: ToServer a => Path -> a -> Server (MonadOf m)

-- alternative cases for server:
mconcat, (<>)

-- | take sub-server at path
atPath :: Path -> Server m -> Server m

toServer :: ToServer a => a -> Server (MonadOf m)
```

### How to run server

```haskell
runServer :: Int -> Server IO -> IO ()

runServer' :: ServerConfig -> Int -> Server IO -> IO ()
```

### Server presets

* `Mig` - generic types
* `Mig.IO` - `IO`-based servers with generic return types
* `Mig.Json` - JSON-based servers
* `Mig.Html` - HTML-based servers
* `Mig.Json.IO` - JSON and IO-based servers 
* `Mig.Html.IO` - HTML and IO-based servers 


### Media types

```haskell
* Json
* Text
* Html
* FormUrlEncoded
* AnyMedia
* OctetStream
```

### Request inputs

```haskell
-- rewquired query parameter
newtype Body media value = Body value

-- rewquired query parameter
newtype Query name value = Query value

-- optional query parameter
newtype Optional name value = Optional (Maybe value)

-- rewquired header parameter
newtype Header name value = Header value

-- optional header parameter
newtype OptionalHeader name value = OptionalHeader (Maybe value)

-- capture in path parameter
newtype Capture name value = Capture value

-- boolean query flag parameter
newtype QueryFlag name = QueryFlag Bool

-- Is connection made over SSL
newtype IsSecure = IsSecure Bool

-- full path with query parameters
newtype PathInfo = Path [Text]

-- | low-level request
newtype RawRequest = RawRequest Request
```

### Request outputs

```haskell
-- | generic route handler
newtype Send method m a = Send (m a)

-- Sepcific methos
type Get m a = Send GET m a
type Post m a = Send POST m a
...

-- Response where type of the value and error are the same
-- or only succesful result is expected
data Resp media a = Resp ...

-- Response where error and result have different types but media type is the same
data RespOr media err a = RespOr ...
```

The response type class:

```haskell
class IsResp a where
  -- | the type of response body value
  type RespBody a :: Type

  -- | the type of an error
  type RespError a :: Type

  -- | Returns valid repsonse with 200 status
  ok :: RespBody a -> a

  -- | Returns an error with given status
  bad :: Status -> RespError a -> a

  -- | response with no content
  noContent :: Status -> a

  -- | Add some header to the response
  addHeaders :: ResponseHeaders -> a -> a

  -- | Sets repsonse status
  setStatus :: Status -> a -> a

  -- | Set the media type of the response
  setMedia :: MediaType -> a -> a

  -- | Reads the media type by response type
  getMedia :: MediaType

  -- | Converts value to low-level response
  toResponse :: a -> Response

setHeader :: (IsResp a, ToHttpApiData h) => HeaderName -> h -> a -> a

-- | Bad request. The @bad@ response with 400 status.
badReq :: (IsResp a) => RespError a -> a

-- | Internal server error. The @bad@ response with 500 status.
internalServerError :: (IsResp a) => RespError a -> a

-- | Not implemented route. The @bad@ response with 501 status.
notImplemented :: (IsResp a) => RespError a -> a

-- | Redirect to url. It is @bad@ response with 302 status 
-- and set header of "Location" to a given URL.
redirect :: (IsResp a) => Text -> a
```

### Middlewares

```haskell
applyMiddleware, ($:) :: ToMiddleware a => 
  a -> Server (MonadOf a) -> Server (MonadOf a)

-- composition of middlewares:
Monoid(..): mconcat, (<>), mempty
```

### specific servers

```haskell
-- | add wagger to server
withSwagger :: SwaggerConfig m -> Server m -> Server m

-- | add link from one route to another
addPathLink :: Path -> Path -> Server m

-- static files
staticFiles :: [(FilePath, ByteString)] -> Server m
```

### specific middlewares


```haskell
-- prepend or append some acction to all routes
prependServerAction, appendServerAction :: MonadIO m => m () -> Middleware m

-- change the response
processResponse :: (m (Maybe Response) -> m (Maybe Response)) -> Middleware m

-- only secure routes are allowed
whenSecure :: forall m. (MonadIO m) => Middleware m

-- logging with putStrLn for debug traces
logHttp :: Verbosity -> Middleware m

-- logging with custom logger
logHttpBy :: (Json.Value -> m ()) -> Verbosity -> Middleware m

-- | simple authorization
withHeaderAuth :: WithHeaderAuth -> Middleware m
```

### How to use Reader

```haskell
-- Derive instance of HasServer class for your Reader-IO based application:
newtype App a = App (ReaderT Env IO a)
  deriving newtype (Functor, Applicative, Monad, MonadReader Env, MonadIO, HasServer)

renderServer :: Server App -> Env -> IO (Server IO)
```

### OpenApi and Swagger

```haskell
-- | Get OpenApi
toOpenApi :: Server m -> OpenApi

-- add swagger to server
withSwagger :: SwaggerConfig m -> Server m -> Server m

-- create swagger server
swagger :: SwaggerConfig m -> m OpenApi -> Server m

-- | Print OpenApi schema
printOpenApi :: Server m -> IO ()

-- | Writes openapi schema to file
writeOpenApi :: FilePath -> Server m -> IO ()
```
The Swagger config:

```haskell
-- | Swagger config
data SwaggerConfig m = SwaggerConfig
  { staticDir :: Path
  -- ^ path to server swagger (default is "/swagger-ui")
  , swaggerFile :: Path
  -- ^ swagger file name (default is "swaggger.json")
  , mapSchema :: OpenApi -> m OpenApi
  -- ^ apply transformation to OpenApi schema on serving OpenApi schema.
  -- it is useful to add additional info or set current date in the examples
  -- or apply any real-time transformation.
  }

instance (Applicative m) => Default (SwaggerConfig m) where
  def =
    SwaggerConfig
      { staticDir = "swagger-ui"
      , swaggerFile = "swagger.json"
      , mapSchema = pure
      }
```

Set swagger title and description:

```haskell
-- | Default info that is often added to OpenApi schema
data DefaultInfo = DefaultInfo
  { title :: Text
  , description :: Text
  , version :: Text
  }

-- adds default info, use it in the mapSwagger field of SwaggerConfig record
addDefaultInfo :: DefaultInfo -> OpenApi -> OpenApi
```

Describe routes with swagger:

```haskell
-- | Sets description of the route
setDescription :: Text -> Server m -> Server m

-- | Sets summary of the route
setSummary :: Text -> Server m -> Server m

-- | Adds OpenApi tag to the route
addTag :: Text -> Server m -> Server m

{-| Appends descriptiton for the inputs. It passes pairs for @(input-name, input-description)@.
special name request-body is dedicated to request body input
nd raw-input is dedicated to raw input
-}
describeInputs :: [(Text, Text)] -> Server m -> Server m
```


-- | Internal types and functions
module Mig.Internal.Types
  ( -- * types
    Server (..)
  , Req (..)
  , Resp (..)
  , RespBody (..)
  , QueryMap
  , ToText (..)
  , Error (..)
  -- * constructors
  , toConst
  , toMethod
  , toWithBody
  , toWithCapture
  , toWithPath
  , toWithHeader
  , toWithFormData
  , toWithPathInfo
  , FormBody (..)
  -- * responses
  , text
  , json
  , html
  , raw
  , ok
  , badRequest
  , setContent
  -- * WAI
  , Config (..)
  , Kilobytes
  , toApplication
  -- * utils
  , setRespStatus
  , handleError
  , toResponse
  , fromRequest
  , pathHead
  ) where

import Data.Bifunctor
import Data.String
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Lazy qualified as TL
import Data.Aeson (ToJSON)
import Data.Aeson qualified as Json
import Data.ByteString (ByteString)
import Data.ByteString qualified as B
import Data.ByteString.Lazy qualified as BL
import Text.Blaze.Html (Html)
import Text.Blaze.Html (ToMarkup)
import Text.Blaze.Html qualified as Html
import Network.HTTP.Types.Method (Method)
import Network.HTTP.Types.Header (ResponseHeaders, RequestHeaders, HeaderName)
import Network.HTTP.Types.Status (Status, ok200, status500, status413)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text.Encoding qualified as Text
import Data.List qualified as List
import Network.Wai
import Text.Blaze.Renderer.Utf8 qualified as Html
import Data.Maybe
import Data.Sequence (Seq (..), (|>))
import Data.Sequence qualified as Seq
import Data.Foldable
import Control.Monad.IO.Class
import Control.Monad.Catch
import Data.Typeable
import Network.Wai.Parse qualified as Parse

-- | Http response
data Resp = Resp
  { status :: Status
    -- ^ status
  , headers :: ResponseHeaders
    -- ^ headers
  , body :: RespBody
    -- ^ response body
  }

instance IsString Resp where
  fromString = text . TL.pack

-- | Http response body
data RespBody
  = TextResp Text
  | HtmlResp Html
  | JsonResp Json.Value
  | FileResp FilePath
  | StreamResp
  | RawResp BL.ByteString

-- | Http request
data Req = Req
  { path :: [Text]
    -- ^ URI path
  , query :: QueryMap
    -- ^ query parameters
  , headers :: RequestHeaders
    -- ^ request headers
  , method :: Method
    -- ^ request method
  , readBody :: IO (Either (Error Text) BL.ByteString)
    -- ^ lazy body reader. Error can happen if size is too big (configured on running the server)
  , readFormBody :: IO (Either (Error Text) FormBody)
  }

data FormBody = FormBody
  { params :: [(ByteString, ByteString)]
  , files :: [(ByteString, Parse.FileInfo BL.ByteString)]
  }

-- Errors

-- | Errors
data Error a = Error
  { status :: Status
    -- error status
  , body :: a
    -- message or error details
  }
  deriving (Show)

instance (Typeable a, Show a) => Exception (Error a) where

-- | Map of query parameters for fast-access
type QueryMap = Map ByteString ByteString

-- | Bad request response
badRequest :: Text -> Resp
badRequest message =
  Resp
    { status = status500
    , headers = setContent "text/plain"
    , body = TextResp message
    }

-- | Server type. It is a function fron request to response.
-- Some servers does not return valid value. We use it to find right path.
--
-- Example:
--
-- > server :: Server IO
-- > server =
-- >   "api" /. "v1" /.
-- >      mconcat
-- >        [ "foo" /. (\(Query @"name" arg) -> Get  @Json (handleFoo arg)
-- >        , "bar" /. Post @Json handleBar
-- >        ]
-- >
-- > handleFoo :: Int -> IO Text
-- > handleBar :: IO Text
--
-- Note that server is monoid and it can be constructed with Monoid functions and
-- path constructor @(/.)@. To pass inputs for handler we can use special newtype wrappers:
--
-- * Query - for required query parameters
-- * Optional - for optional query parameters
-- * Capture - for parsing elements of URI
-- * Body - fot JSON-body input
-- * RawBody - for raw ByteString input
-- * Header - for headers
--
-- To distinguish by HTTP-method we use corresponding constructors: Get, Post, Put, etc.
-- Let's discuss the structure of the constructor. Let's take Get for example:
--
-- > newtype Get ty m a = Get (m a)
--
--  Let's look at the arguments of he type
--
-- * @ty@ - type of the response. it can be: Text, Html, Json, ByteString
-- * @m@ - underlying server monad
-- * @a@ - result type. It should be convertible to the type of the response.
--
-- also result can be wrapped to special data types to modify Http-response.
-- we have wrappers:
--
-- * @SetStatus@ - to set status
-- * @AddHeaders@ - to append headers
-- * @Either (Error err)@ - to response with errors
newtype Server m = Server { unServer :: Req -> m (Maybe Resp) }

toConst :: Functor m => m Resp -> Server m
toConst act = Server $ const $ Just <$> act

toMethod :: Monad m => Method -> m Resp -> Server m
toMethod method act = Server $ checkMethod method act

checkMethod :: Monad m => Method -> m Resp -> Req -> m (Maybe Resp)
checkMethod method act req
  | null req.path && req.method == method = Just <$> act
  | otherwise = pure Nothing

toWithBody :: MonadIO m => (BL.ByteString -> Server m) -> Server m
toWithBody act = Server $ \req -> do
  eBody <- liftIO req.readBody
  case eBody of
    Right body -> unServer (act body) req
    Left err -> pure $ Just $ setRespStatus err.status (text err.body)

-- TODO: make it size limited by HTTP-body size
toWithFormData :: MonadIO m => (FormBody -> Server m) -> Server m
toWithFormData act = Server $ \req -> do
  eFormBody <- liftIO req.readFormBody
  case eFormBody of
    Right formBody -> unServer (act formBody) req
    Left err -> pure $ Just $ setRespStatus err.status (text err.body)


-- | Size of the input body
type Kilobytes = Int

-- | Read request body in chunks
readRequestBody :: IO B.ByteString -> Maybe Kilobytes -> IO (Either (Error Text) [B.ByteString])
readRequestBody readChunk maxSize = loop 0 Seq.empty
  where
    loop :: Kilobytes -> Seq B.ByteString -> IO (Either (Error Text) [B.ByteString])
    loop !currentSize !result
      | isBigger currentSize = pure outOfSize
      | otherwise = do
          chunk <- readChunk
          if B.null chunk
            then pure $ Right (toList result)
            else loop (currentSize + B.length chunk) (result |> chunk)

    outOfSize :: Either (Error Text) a
    outOfSize = Left (Error status413 (Text.pack $ "Request is too big Jim!"))

    isBigger = case maxSize of
      Just size -> \current -> current > size
      Nothing -> const False

toWithPath :: Monad m => Text -> Server m -> Server m
toWithPath route act = Server $ \req ->
  case hasPath route req.path of
    Just restPath -> unServer act (req { path = restPath })
    _ -> pure Nothing

type Path = [Text]

hasPath :: Text -> Path -> Maybe Path
hasPath route (path:restPath)
  | route == path = Just restPath
  | otherwise = Nothing
hasPath _ _ = Nothing

toWithCapture :: Monad m => (Text -> Server m) -> Server m
toWithCapture act = Server $ \req ->
  case pathHead req of
    Just (arg, nextReq) -> unServer (act arg) nextReq
    Nothing -> pure Nothing

pathHead :: Req -> Maybe (Text, Req)
pathHead req =
  case req.path of
    hd : tl -> Just (hd, req { path = tl })
    _ -> Nothing

toWithHeader :: HeaderName -> (Maybe ByteString -> Server m) -> Server m
toWithHeader name act = Server $ \req ->
  unServer (act (fmap snd $ List.find ((== name) . fst) req.headers)) req

toWithPathInfo :: ([Text] -> Server m) -> Server m
toWithPathInfo act = Server $ \req ->
  unServer (act req.path) req

instance Monad m => Semigroup (Server m) where
  (<>) (Server serverA) (Server serverB) = Server $ \req -> do
    mRespA <- serverA req
    maybe (serverB req) (pure . Just) mRespA

instance Monad m => Monoid (Server m) where
  mempty = Server (const $ pure Nothing)

-- | Values convertible to lazy text
class ToText a where
  toText :: a -> Text

instance ToText TL.Text where
  toText = TL.toStrict

instance ToText Text where
  toText = id

instance ToText Int where
  toText = Text.pack . show

instance ToText Float where
  toText = Text.pack . show

instance ToText String where
  toText = fromString

{-# INLINE setContent #-}
-- | Headers to set content type
setContent :: ByteString -> ResponseHeaders
setContent contentType =
  [("Content-Type", contentType <>"; charset=utf-8")]

setRespStatus :: Status -> Resp -> Resp
setRespStatus status (Resp _ headers body) = Resp status headers body

-- | Json response constructor
json :: (ToJSON resp) => resp -> Resp
json = (ok (setContent "text/json") . JsonResp . Json.toJSON)

-- | Text response constructor
text :: ToText a => a -> Resp
text = ok (setContent "text/plain") . TextResp . toText

-- | Html response constructor
html :: (ToMarkup a) => a -> Resp
html = ok (setContent "text/html") . HtmlResp . Html.toHtml

-- | Raw bytestring response constructor
raw :: BL.ByteString -> Resp
raw = ok (setContent "text/plain") . RawResp

-- | Respond with ok 200-status
ok :: ResponseHeaders -> RespBody -> Resp
ok headers body = Resp ok200 headers body

-- | Handle errors
handleError ::(Exception a, MonadCatch m) => (a -> Server m) -> Server m -> Server m
handleError handler (Server act) = Server $ \req ->
  (act req) `catch` (\err -> unServer (handler err) req)

-------------------------------------------------------------------------------------
-- render to WAI

-- | Server config
data Config = Config
  { maxBodySize :: Maybe Kilobytes
  }

-- | Convert server to WAI-application
toApplication :: Config -> Server IO -> Application
toApplication config server req processResponse = do
  mResp <- unServer (handleError onErr server) =<< fromRequest config.maxBodySize req
  processResponse $ toResponse $ fromMaybe noResult mResp
  where
    noResult = badRequest "Server produces nothing"

    onErr :: SomeException -> Server IO
    onErr err = toConst $ pure $ badRequest $ "Error: Exception has happened: " <> toText (show err)

-- | Convert response to low-level WAI-response
toResponse :: Resp -> Response
toResponse resp =
  case resp.body of
    TextResp textResp -> lbs $ BL.fromStrict (Text.encodeUtf8 textResp)
    HtmlResp htmlResp -> lbs (Html.renderMarkup htmlResp)
    JsonResp jsonResp -> lbs (Json.encode jsonResp)
    FileResp file -> responseFile resp.status resp.headers file Nothing
    RawResp str -> lbs str
    StreamResp -> undefined
  where
    lbs = responseLBS resp.status resp.headers

-- | Read request from low-level WAI-request
-- First argument limits the size of input body. The body is read in chunks.
fromRequest :: Maybe Kilobytes -> Request -> IO Req
fromRequest maxSize req =
  pure $ Req
    { path = pathInfo req
    , query = Map.fromList $ mapMaybe (\(key, mVal) -> (key, ) <$> mVal) (queryString req)
    , headers = requestHeaders req
    , method = requestMethod req
    , readBody = fmap (fmap BL.fromChunks) $ readRequestBody (getRequestBodyChunk req) maxSize
    , readFormBody = getReadFormBody req
    }

getReadFormBody :: Request -> IO (Either (Error Text) FormBody)
getReadFormBody req = do
  case Parse.getRequestBodyType req of
    Nothing -> pure $ Right (FormBody [] [])
    Just reqBodyType -> do
      eResult <- try @IO @SomeException (Parse.sinkRequestBody Parse.lbsBackEnd reqBodyType (getRequestBodyChunk req))
      pure $ bimap (const toError) (uncurry FormBody) eResult
  where
    toError = Error status413 (Text.pack $ "Request is too big!")


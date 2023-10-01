module Mig.Core.Middleware (
  -- * class
  ToMiddleware (..),
  Middleware,
  applyMiddleware,

  -- * specific middlewares
  prependServerAction,
  appendServerAction,
  processResponse,
) where

import Control.Monad.IO.Class
import Data.Kind
import Data.Proxy
import Data.String
import GHC.TypeLits
import Web.HttpApiData

import Mig.Core.Route
import Mig.Core.Server
import Mig.Core.ServerFun
import Mig.Core.Types

type Middleware m = ServerFun m -> ServerFun m

class (MonadIO (MiddlewareMonad f)) => ToMiddleware f where
  type MiddlewareMonad f :: Type -> Type
  toMiddleware :: f -> Middleware (MiddlewareMonad f)

applyMiddleware :: (ToMiddleware f) => f -> Server (MiddlewareMonad f) -> Server (MiddlewareMonad f)
applyMiddleware a = mapServerFun (toMiddleware a)

-- identity
instance (MonadIO m) => ToMiddleware (ServerFun m -> ServerFun m) where
  type MiddlewareMonad (ServerFun m -> ServerFun m) = m
  toMiddleware = id

-- path info
instance (ToMiddleware a) => ToMiddleware (PathInfo -> a) where
  type MiddlewareMonad (PathInfo -> a) = MiddlewareMonad a
  toMiddleware f = \fun -> withPathInfo (\path -> toMiddleware (f (PathInfo path)) fun)

-- request body
instance (MimeUnrender media a, ToMiddleware b) => ToMiddleware (ReqBody media a -> b) where
  type MiddlewareMonad (ReqBody media a -> b) = MiddlewareMonad b
  toMiddleware f = \fun -> withBody @media (\body -> toMiddleware (f (ReqBody body)) fun)

-- header
instance (FromHttpApiData a, ToMiddleware b, KnownSymbol sym) => ToMiddleware (Header sym a -> b) where
  type MiddlewareMonad (Header sym a -> b) = MiddlewareMonad b
  toMiddleware f = \fun -> withHeader (getName @sym) (\a -> toMiddleware (f (Header a)) fun)

-- optional header
instance (FromHttpApiData a, ToMiddleware b, KnownSymbol sym) => ToMiddleware (OptionalHeader sym a -> b) where
  type MiddlewareMonad (OptionalHeader sym a -> b) = MiddlewareMonad b
  toMiddleware f = \fun -> withOptionalHeader (getName @sym) (\a -> toMiddleware (f (OptionalHeader a)) fun)

-- query
instance (FromHttpApiData a, ToMiddleware b, KnownSymbol sym) => ToMiddleware (Query sym a -> b) where
  type MiddlewareMonad (Query sym a -> b) = MiddlewareMonad b
  toMiddleware f = \fun -> withQuery (getName @sym) (\a -> toMiddleware (f (Query a)) fun)

-- optional query
instance (FromHttpApiData a, ToMiddleware b, KnownSymbol sym) => ToMiddleware (Optional sym a -> b) where
  type MiddlewareMonad (Optional sym a -> b) = MiddlewareMonad b
  toMiddleware f = \fun -> withOptional (getName @sym) (\a -> toMiddleware (f (Optional a)) fun)

-- query flag
instance (ToMiddleware b, KnownSymbol sym) => ToMiddleware (QueryFlag sym -> b) where
  type MiddlewareMonad (QueryFlag sym -> b) = MiddlewareMonad b
  toMiddleware f = \fun -> withQueryFlag (getName @sym) (\a -> toMiddleware (f (QueryFlag a)) fun)

-- capture
instance (FromHttpApiData a, ToMiddleware b, KnownSymbol sym) => ToMiddleware (Capture sym a -> b) where
  type MiddlewareMonad (Capture sym a -> b) = MiddlewareMonad b
  toMiddleware f = \fun -> withCapture (getName @sym) (\a -> toMiddleware (f (Capture a)) fun)

---------------------------------------------
-- specific middlewares

-- | Prepends action to the server
prependServerAction :: (Monad m) => m () -> Middleware m
prependServerAction act f = \req -> do
  act
  f req

-- | Post appends action to the server
appendServerAction :: (Monad m) => m () -> Middleware m
appendServerAction act f = \req -> do
  resp <- f req
  act
  pure resp

-- | Applies transformation to the response
processResponse :: (m (Maybe Response) -> m (Maybe Response)) -> Middleware m
processResponse act f = \req -> do
  act (f req)

---------------------------------------------
-- utils

getName :: forall sym a. (KnownSymbol sym, IsString a) => a
getName = fromString (symbolVal (Proxy @sym))

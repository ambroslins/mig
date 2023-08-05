-- | Module for HTML-based servers
module Mig.Json.IO
  (
  -- * methods
    Get (..)
  , Post (..)
  , Put (..)
  , Delete (..)
  , Patch (..)
  , Options (..)

  -- * common
  -- | Common re-exports
  , module X
  ) where

import Mig.Common as X
import Mig (ToServer (..), ToJsonResp (..))
import Mig.Internal.Types (toMethod)
import Network.HTTP.Types.Method

-- Get

newtype Get a = Get (IO a)

instance (ToJsonResp a) => ToServer (Get a) where
  type ServerMonad (Get a) = IO
  onParam (Get act) = toMethod methodGet (toJsonResp <$> act)

-- Post

newtype Post a = Post (IO a)

instance (ToJsonResp a) => ToServer (Post a) where
  type ServerMonad (Post a) = IO
  onParam (Post act) = toMethod methodPost (toJsonResp <$> act)

-- Put

newtype Put a = Put (IO a)

instance (ToJsonResp a) => ToServer (Put a) where
  type ServerMonad (Put a) = IO
  onParam (Put act) = toMethod methodPut (toJsonResp <$> act)

-- Delete

newtype Delete a = Delete (IO a)

instance (ToJsonResp a) => ToServer (Delete a) where
  type ServerMonad (Delete a) = IO
  onParam (Delete act) = toMethod methodDelete (toJsonResp <$> act)

-- Patch

newtype Patch a = Patch (IO a)

instance (ToJsonResp a) => ToServer (Patch a) where
  type ServerMonad (Patch a) = IO
  onParam (Patch act) = toMethod methodPatch (toJsonResp <$> act)

-- Options

newtype Options a = Options (IO a)

instance (ToJsonResp a) => ToServer (Options a) where
  type ServerMonad (Options a) = IO
  onParam (Options act) = toMethod methodOptions (toJsonResp <$> act)
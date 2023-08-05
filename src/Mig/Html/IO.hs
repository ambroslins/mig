-- | Module for HTML-based servers
module Mig.Html.IO
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
import Mig.Internal.Types (toMethod)
import Network.HTTP.Types.Method

-- Get

newtype Get a = Get (IO a)

instance (ToHtmlResp a) => ToServer (Get a) where
  type ServerMonad (Get a) = IO
  toServer (Get act) = toMethod methodGet (toHtmlResp <$> act)

-- Post

newtype Post a = Post (IO a)

instance (ToHtmlResp a) => ToServer (Post a) where
  type ServerMonad (Post a) = IO
  toServer (Post act) = toMethod methodPost (toHtmlResp <$> act)

-- Put

newtype Put a = Put (IO a)

instance (ToHtmlResp a) => ToServer (Put a) where
  type ServerMonad (Put a) = IO
  toServer (Put act) = toMethod methodPut (toHtmlResp <$> act)

-- Delete

newtype Delete a = Delete (IO a)

instance (ToHtmlResp a) => ToServer (Delete a) where
  type ServerMonad (Delete a) = IO
  toServer (Delete act) = toMethod methodDelete (toHtmlResp <$> act)

-- Patch

newtype Patch a = Patch (IO a)

instance (ToHtmlResp a) => ToServer (Patch a) where
  type ServerMonad (Patch a) = IO
  toServer (Patch act) = toMethod methodPatch (toHtmlResp <$> act)

-- Options

newtype Options a = Options (IO a)

instance (ToHtmlResp a) => ToServer (Options a) where
  type ServerMonad (Options a) = IO
  toServer (Options act) = toMethod methodOptions (toHtmlResp <$> act)

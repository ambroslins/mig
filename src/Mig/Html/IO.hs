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
import Mig (ToServer (..))
import Mig.Internal.Types (toMethod)
import Network.HTTP.Types.Method

-- Get

newtype Get a = Get (IO a)

instance (ToHtmlResp a) => ToServer (Get a) where
  type ServerMonad (Get a) = IO
  onParam (Get act) = toMethod methodGet (toHtmlResp <$> act)

-- Post

newtype Post a = Post (IO a)

instance (ToHtmlResp a) => ToServer (Post a) where
  type ServerMonad (Post a) = IO
  onParam (Post act) = toMethod methodPost (toHtmlResp <$> act)

-- Put

newtype Put a = Put (IO a)

instance (ToHtmlResp a) => ToServer (Put a) where
  type ServerMonad (Put a) = IO
  onParam (Put act) = toMethod methodPut (toHtmlResp <$> act)

-- Delete

newtype Delete a = Delete (IO a)

instance (ToHtmlResp a) => ToServer (Delete a) where
  type ServerMonad (Delete a) = IO
  onParam (Delete act) = toMethod methodDelete (toHtmlResp <$> act)

-- Patch

newtype Patch a = Patch (IO a)

instance (ToHtmlResp a) => ToServer (Patch a) where
  type ServerMonad (Patch a) = IO
  onParam (Patch act) = toMethod methodPatch (toHtmlResp <$> act)

-- Options

newtype Options a = Options (IO a)

instance (ToHtmlResp a) => ToServer (Options a) where
  type ServerMonad (Options a) = IO
  onParam (Options act) = toMethod methodOptions (toHtmlResp <$> act)
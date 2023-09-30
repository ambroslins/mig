module Mig.Core.Types.MediaType (
  MediaType (..),
  ToMediaType (..),
  MimeRender (..),
  Json,
  Form,
  OctetStream,
  MimeUnrender (..),
) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Aeson qualified as Json
import Data.Aeson.Parser qualified
import Data.Aeson.Types (
  parseEither,
 )
import Data.Attoparsec.ByteString.Char8 (
  endOfInput,
  parseOnly,
  skipSpace,
  (<?>),
 )
import Data.Bifunctor
import Data.ByteString (ByteString)
import Data.ByteString.Lazy qualified as BL
import Data.Proxy
import Data.String
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import GHC.TypeLits
import Text.Blaze.Html (Html, ToMarkup (..))
import Text.Blaze.Html.Renderer.Utf8 (renderHtml)

newtype MediaType = MediaType Text
  deriving (Show, Eq, Ord, IsString)

class ToMediaType a where
  toMediaType :: MediaType

instance ToMediaType Text where
  toMediaType = MediaType "text/plain"

instance ToMediaType Html where
  toMediaType = MediaType "text/html"

data OctetStream

instance ToMediaType OctetStream where
  toMediaType = MediaType "application/octet-stream"

instance ToMediaType BL.ByteString where
  toMediaType = MediaType "application/octet-stream"

data Json

instance ToMediaType Json where
  toMediaType = MediaType "application/json"

data RawMedia (sym :: Symbol)

data Form

instance ToMediaType Form where
  toMediaType = MediaType ""

instance (KnownSymbol sym) => ToMediaType (RawMedia sym) where
  toMediaType = MediaType (fromString (symbolVal (Proxy @sym)))

-------------------------------------------------------------------------------------
-- mime render (everything that can be rendered as HTTP-output)

class (ToMediaType ty) => MimeRender ty b where
  mimeRender :: b -> BL.ByteString

instance (ToJSON a) => MimeRender Json a where
  mimeRender = Json.encode

instance MimeRender Text Text where
  mimeRender = BL.fromStrict . Text.encodeUtf8

instance (ToMarkup a) => MimeRender Html a where
  mimeRender = renderHtml . toMarkup

instance MimeRender OctetStream BL.ByteString where
  mimeRender = id

instance MimeRender OctetStream ByteString where
  mimeRender = BL.fromStrict

instance MimeRender BL.ByteString BL.ByteString where
  mimeRender = id

-------------------------------------------------------------------------------------
-- mime unrender (everything that can be parsed from HTTP-input)

class (ToMediaType ty) => MimeUnrender ty b where
  mimeUnrender :: BL.ByteString -> Either Text b

instance MimeUnrender Text Text where
  mimeUnrender = bimap (Text.pack . show) id . Text.decodeUtf8' . BL.toStrict

instance MimeUnrender OctetStream BL.ByteString where
  mimeUnrender = Right

instance MimeUnrender OctetStream ByteString where
  mimeUnrender = Right . BL.toStrict

instance (FromJSON a) => MimeUnrender Json a where
  mimeUnrender = eitherDecodeLenient

{-| Like 'Data.Aeson.eitherDecode' but allows all JSON values instead of just
objects and arrays.

Will handle trailing whitespace, but not trailing junk. ie.

>>> eitherDecodeLenient "1 " :: Either String Int
Right 1

>>> eitherDecodeLenient "1 junk" :: Either String Int
Left "trailing junk after valid JSON: endOfInput"
-}
eitherDecodeLenient :: (FromJSON a) => BL.ByteString -> Either Text a
eitherDecodeLenient input =
  bimap Text.pack id $
    parseOnly parser (BL.toStrict input) >>= parseEither Json.parseJSON
  where
    parser =
      skipSpace
        *> Data.Aeson.Parser.value
        <* skipSpace
        <* (endOfInput <?> "trailing junk after valid JSON")

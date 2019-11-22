module Main
  ( main
  ) where

import Control.Applicative
import Data.Char

data JsonValue
  = JsonNull
  | JsonBool Bool
  | JsonNum Int
  | JsonString String
  | JsonArray [JsonValue]
  | JsonObject [(String, JsonValue)]
  deriving (Show, Eq)

newtype Parser a =
  Parser
    { runParser :: String -> Maybe (String, a)
    }

instance Functor Parser where
  fmap f (Parser p) =
    Parser $ \input -> do
      (input', x) <- p input
      Just (input', f x)

instance Applicative Parser where
  pure x = Parser $ \input -> Just (input, x)
  (Parser p1) <*> (Parser p2) =
    Parser $ \input -> do
      (input', f) <- p1 input
      (input'', a) <- p2 input'
      Just (input'', f a)

instance Alternative Parser where
  empty = Parser $ const Nothing
  (Parser p1) <|> (Parser p2) = Parser $ \input -> p1 input <|> p2 input

charP :: Char -> Parser Char
charP x = Parser f
  where
    f :: String -> Maybe (String, Char)
    f (y:ys)
      | y == x = Just (ys, x)
      | otherwise = Nothing
    f _ = Nothing

stringP :: String -> Parser String
stringP = traverse charP

jsonNull :: Parser JsonValue
jsonNull = JsonNull <$ stringP "null"

jsonBool :: Parser JsonValue
jsonBool = jsonTrue <|> jsonFalse
  where
    jsonTrue = JsonBool True <$ stringP "true"
    jsonFalse = JsonBool False <$ stringP "false"

spanP :: (Char -> Bool) -> Parser String
spanP f =
  Parser $ \input ->
    let (token, rest) = span f input
     in Just (rest, token)

notNull :: Parser [a] -> Parser [a]
notNull (Parser p) =
  Parser $ \input -> do
    (input', xs) <- p input
    if null xs
      then Nothing
      else Just (input', xs)

jsonNum :: Parser JsonValue
jsonNum = f <$> notNull (spanP isDigit)
  where
    f ds = JsonNum $ read ds

stringLiteral :: Parser String
stringLiteral = charP '"' *> spanP (/= '"') <* charP '"'

jsonString :: Parser JsonValue
jsonString = JsonString <$> stringLiteral

whitespace :: Parser String
whitespace = spanP isSpace

sepBy :: Parser a -> Parser b -> Parser [b]
sepBy separator element =
  (:) <$> element <*> many (separator *> element) <|> pure []

jsonArray :: Parser JsonValue
jsonArray =
  JsonArray <$> (charP '[' *> whitespace *> elements <* whitespace <* charP ']')
  where
    elements = sepBy (whitespace *> charP ',' <* whitespace) jsonValue

jsonObject :: Parser JsonValue
jsonObject =
  JsonObject <$>
  (charP '{' *> whitespace *> sepBy (whitespace *> charP ',' <* whitespace) pair <*
   whitespace <*
   charP '}')
  where
    pair =
      (\key _ value -> (key, value)) <$> stringLiteral <*>
      (whitespace *> charP ':' <* whitespace) <*>
      jsonValue

jsonValue :: Parser JsonValue
jsonValue =
  jsonNull <|> jsonBool <|> jsonNum <|> jsonString <|> jsonArray <|> jsonObject

parseFile :: FilePath -> Parser a -> IO (Maybe a)
parseFile fileName parser = do
  input <- readFile fileName
  return (snd <$> runParser parser input)

--parseFile :: FilePath -> IO ()
--parseFile fileName = do
main :: IO ()
main = undefined
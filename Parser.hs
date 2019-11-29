module Parser
  ( Parser
  , charP
  , stringP
  , spanP
  , notNull
  , whitespace
  , sepBy
  , parseFile
  ) where

import Control.Applicative
import Data.Char

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

whitespace :: Parser String
whitespace = spanP isSpace

sepBy :: Parser a -> Parser b -> Parser [b]
sepBy separator element =
  (:) <$> element <*> many (separator *> element) <|> pure []

parseFile :: FilePath -> Parser a -> IO (Maybe a)
parseFile fileName parser = do
  input <- readFile fileName
  return (snd <$> runParser parser input)

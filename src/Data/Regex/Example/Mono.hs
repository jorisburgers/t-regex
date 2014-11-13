{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverlappingInstances #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE PostfixOperators #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- | Example of tree regular expressions over a regular data type.
--   Click on @Source@ to view the code.
module Data.Regex.Example.Mono (
  -- * Data type definition
  Tree'(..), Tree,
  -- ** Useful pattern synonyms
  pattern Leaf, pattern Branch,
  -- ** Some 'Tree' values
  aTree1, aTree2, aTree3,
  -- * Tree regular expressions
  -- ** Useful pattern synonyms
  pattern Leaf_, pattern Branch_,
  -- ** Some stand-alone expressions
  rTree1, rTree2, rTree3,
  -- ** Using 'with' views
  eWith1, eWith2,
  -- ** Using the 'rx' quasi-quoter
  eWith2Bis, eWith3, eWith4,
  -- * Grammar and rules
  grammar1, grammar2
) where

import Control.Lens hiding (at, (#), children)
import Data.Map ((!))
import qualified Data.Map as M
import Data.Regex.Generics
import Data.Regex.Rules
import Data.Regex.TH
import GHC.Generics

-- | The pattern functor, which should be kept open.
--   Recursion is done by using the argument.
data Tree' f = Leaf' | Branch' { elt :: Int, left :: f, right :: f }
  deriving (Generic1, Show)
-- | Closes the data type by creating its fix-point.
type Tree = Fix Tree'

-- | Pattern synonym for the 'Leaf' constructor inside 'Fix'.
pattern Leaf = Fix Leaf'
-- | Pattern synonym for the 'Branch' constructor inside 'Fix'.
pattern Branch n l r = Fix (Branch' n l r)

instance Show Tree where
  show (Fix Leaf') = "Leaf"
  show (Fix (Branch' n t1 t2)) = "(Branch " ++ show n ++ " " ++ show t1 ++ " " ++ show t2 ++ ")"

aTree1 :: Tree
aTree1 = Branch 2 (Branch 3 Leaf Leaf) Leaf

aTree2 :: Tree
aTree2 = Branch 2 (Branch 2 Leaf Leaf) Leaf

aTree3 :: Tree
aTree3 = Branch 2 Leaf Leaf

rTree1 :: Regex String Tree'
rTree1 = Regex $
           iter $ \k ->
             capture "x" $
                    inj (Branch' 2 (square k) (square k))
               <||> inj Leaf'

rTree2 :: Integer -> Regex Integer Tree'
rTree2 c = Regex $
             iter $ \k ->
               capture c $
                      inj (Branch' 2 (square k) (square k))
                 <||> inj Leaf'

pattern Branch_ n l r = Inject (Branch' n l r)
pattern Leaf_         = Inject Leaf'

rTree3 :: Integer -> Integer -> Regex Integer Tree'
rTree3 c1 c2 = Regex ( (\k -> c1 <<- Branch_ 2 (k#) (k#) <||> c2 <<- Leaf_)^* )

eWith1 :: Tree -> [Tree]
eWith1 (with rTree2 -> Just e) = e
eWith1 _                       = error "What?"

eWith2 :: Tree -> [Tree]
eWith2 (with rTree3 -> Just (_,e)) = e
eWith2 _                           = error "What?"

eWith2Bis :: Tree -> [Tree]
eWith2Bis [rx| (\k -> x <<- Branch_ 2 (k#) (k#) <||> e <<- Leaf_)^* |] = e
eWith2Bis _  = error "What?"

eWith3 :: Tree -> [Tree]
eWith3 [rx| x <<- Leaf_ |] = x
eWith3 _                   = error "What?"

eWith4 :: Tree -> [Int]
eWith4 [rx| (\k -> x <<- shallow (Branch' __ (k#) (k#)) <||> e <<- Leaf_)^* |] = map (elt . unFix) x
eWith4 _  = error "What?"

unFix :: Fix f -> f (Fix f)
unFix (Fix x) = x

grammar1 :: Grammar String Tree' () String
grammar1 = [ ( Regex $ inj (Branch' 2 ("l" <<- any_) ("r" <<- any_))
             , \_ _ children ->
                  ( M.fromList [("l",()),("r",())]
                  , "(" ++ children ! "l"
                    ++ ")-SPECIAL-("
                    ++ children ! "r" ++ ")" ) )
           , ( Regex $ shallow (Branch' __ ("l" <<- any_) ("r" <<- any_))
             , \(Branch e _ _) _ children ->
                  ( M.fromList [("l",()),("r",())]
                  , "(" ++ children ! "l"
                    ++ ")-" ++ show e  ++ "-("
                    ++ children ! "r" ++ ")" ) )
           , ( Regex $ Leaf_, \_ _ _ -> (M.empty, "leaf") )
           ]

grammar2 :: Grammar Integer Tree' () String
grammar2 = [
    rule $ \l r ->
     inj (Branch' 2 (l <<- any_) (r <<- any_)) ->> do
       lText <- use (at l . syn)
       rText <- use (at r . syn)
       this . syn .= "(" ++ lText ++ ")-SPECIAL-(" ++ rText ++ ")"
  , rule $ \l r ->
     shallow (Branch' __ (l <<- any_) (r <<- any_)) ->>> \(Branch e _ _) -> do
       lText <- use (at l . syn)
       rText <- use (at r . syn)
       this . syn .= "(" ++ lText ++ ")-" ++ show e ++ "-(" ++ rText ++ ")"
  , rule $ Leaf_ ->> do
       this . syn .= "leaf"
  ]

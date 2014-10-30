{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ImpredicativeTypes #-}
{-# LANGUAGE GADTs #-}
module Data.TreeRegex.Multi where

import Data.MultiGenerics

import Unsafe.Coerce -- :(

-- As defined in page 58 of "Tree Automata Techniques and Applications"
-- * f -> set of constructors
-- * s -> set of iteration and concatenation positions
-- * ix -> index over the data types
data TreeRegex' s (f :: (k -> *) -> k -> *) (ix :: k)
  = Empty
  | Any
  | In (f (TreeRegex' s f) ix)
  | Square s
  | Choice (TreeRegex' s f ix) (TreeRegex' s f ix)
  | Concat (s -> TreeRegex' s f ix) (TreeRegex' s f ix)
  | Iter (s -> TreeRegex' s f ix)
newtype TreeRegex f ix = TreeRegex { unTreeRegex :: forall s. TreeRegex' s f ix }

newtype Fix (f :: (k -> *) -> k -> *) (ix :: k) = Fix { unFix :: f (Fix f) ix }

match :: (Generic1m f, MatchG' (Rep1m f))
      => TreeRegex f ix -> Fix f ix -> Bool
match r t = match' (unTreeRegex r) t 0 []

match' :: (Generic1m f, MatchG' (Rep1m f))
       => TreeRegex' Integer f ix
       -> Fix f ix
       -> Integer  -- Fresh variable generator
       -> [(Integer, forall h ix. TreeRegex' Integer h ix)]  -- Ongoing substitution
       -> Bool
match' Empty          _ _ _ = False
match' Any            _ _ _ = True
match' (In r)   (Fix t) i s = matchG' (from1k r) (from1k t) i s
match' (Square n)     t i s = let Just r = unsafeCoerce (lookup n s) in match' r t i s
match' (Choice r1 r2) t i s = match' r1 t i s || match' r2 t i s
match' (Concat r1 r2) t i s = match' (r1 i) t (i+1) ((i, unsafeCoerce r2):s)
match' (Iter r)       t i s = match' (Concat r (Iter r)) t i s

class MatchG' (f :: (k -> *) -> k -> *) where
  matchG' :: (Generic1m g, MatchG' (Rep1m g))
          => f (TreeRegex' Integer g) ix -> f (Fix g) ix
          -> Integer -> [(Integer, forall h xi. TreeRegex' Integer h xi)] -> Bool


instance MatchG' U1m where
  matchG' _ _ _ _ = True

instance MatchG' (Par1m xi) where
  matchG' (Par1m r) (Par1m t) = match' r t

instance MatchG' f => MatchG' (Rec1m f xi) where
  matchG' (Rec1m r) (Rec1m t) = matchG' r t

instance Eq c => MatchG' (K1m i c) where
  matchG' (K1m r) (K1m t) _ _ = r == t

instance (MatchG' a, MatchG' b) => MatchG' (a :++: b) where
  matchG' (L1m r) (L1m t) i s = matchG' r t i s
  matchG' (R1m r) (R1m t) i s = matchG' r t i s
  matchG' _       _       _ _ = False

instance (MatchG' a, MatchG' b) => MatchG' (a :**: b) where
  matchG' (r1 :**: r2) (t1 :**: t2) i s = matchG' r1 t1 i s && matchG' r2 t2 i s

instance MatchG' f => MatchG' (Tag1m f xi) where
  matchG' (Tag1m r) (Tag1m t) = matchG' r t

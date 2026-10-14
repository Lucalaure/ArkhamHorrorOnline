{-# LANGUAGE TemplateHaskell #-}

{- | The printed investigator values the debug panel can rewrite. See
@DebugSetInvestigatorStat@ in "Arkham.Message".
-}
module Arkham.Debug.InvestigatorStat where

import Arkham.Prelude
import Data.Aeson.TH

data DebugInvestigatorStat
  = DebugStatHealth
  | DebugStatSanity
  | DebugStatWillpower
  | DebugStatIntellect
  | DebugStatCombat
  | DebugStatAgility
  deriving stock (Show, Eq, Ord, Enum, Bounded, Data)

$(deriveJSON defaultOptions ''DebugInvestigatorStat)

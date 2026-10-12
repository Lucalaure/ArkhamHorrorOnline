{-# LANGUAGE TemplateHaskell #-}

module Arkham.Matcher.History where

import Arkham.Id
import Arkham.Matcher.Value
import Arkham.Prelude
import Arkham.Trait (Trait)
import Data.Aeson.TH

data HistoryMatcher
  = DefeatedEnemiesWithTotalHealth ValueMatcher
  | -- | How many enemies were defeated, whatever their health: "if an enemy has been defeated this round".
    DefeatedEnemiesCount ValueMatcher
  | DefeatedEnemyWithTraitAt Trait LocationId
  | AttackedByAnyEnemies
  | CluesDiscoveredAt ValueMatcher LocationId
  deriving stock (Show, Eq, Ord, Data)

$(deriveJSON defaultOptions ''HistoryMatcher)

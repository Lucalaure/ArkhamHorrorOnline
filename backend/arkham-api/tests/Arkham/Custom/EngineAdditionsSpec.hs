module Arkham.Custom.EngineAdditionsSpec (spec) where

import Arkham.Asset.Cards qualified as Assets
import Arkham.Card.CustomCard (CustomCard (..), registerCustomCards)
import Arkham.Helpers.History (hasHistory)
import Arkham.History (HistoryType (RoundHistory))
import Arkham.Matcher qualified as Matcher
import Data.Aeson (Value, object, (.=))
import Data.Map.Strict qualified as Map
import TestImport.New

{- | A custom card, registered so the engine can build it, and its def.

The engine looks custom codes up in a process-wide registry, so a code is
minted per test to keep one test's card from answering for another's.
-}
customCard :: CardType -> (CardDef -> CardDef) -> [(Text, Value)] -> TestAppT CardDef
customCard cardType f meta = do
  n :: Int <- getRandomR (0, maxBound)
  let
    code = CardCode $ "*enginetest" <> tshow n <> "0"
    def = (f $ emptyCardDef code ("Engine test card" :: Name) cardType) {cdMeta = Map.fromList meta}
  registerCustomCards $ Map.singleton code (CustomCard def Nothing)
  pure def

tagged :: Text -> [Value] -> Value
tagged tag = \case
  [] -> object ["tag" .= tag, "contents" .= ([] :: [Value])]
  [x] -> object ["tag" .= tag, "contents" .= x]
  xs -> object ["tag" .= tag, "contents" .= xs]

spec :: Spec
spec = describe "Engine additions for custom cards" $ do
  it "CardWithCostAtLeast matches a printed cost at or above the bound" . gameTest $ \_ -> do
    machete <- genCard Assets.machete
    knife <- genCard Assets.knife
    liftIO $ do
      cardMatch machete (Matcher.CardWithCostAtLeast 3) `shouldBe` True
      cardMatch knife (Matcher.CardWithCostAtLeast 3) `shouldBe` False

  it "DefeatedEnemiesCount counts enemies defeated this round" . gameTest $ \self -> do
    location <- testLocation
    self `moveTo` location
    enemy <- testEnemy
    enemy `spawnAt` location
    let anyDefeated = Matcher.DefeatedEnemiesCount (Matcher.GreaterThan (Static 0))
    hasHistory RoundHistory anyDefeated self `shouldReturn` False
    run $ DefeatEnemy (toId enemy) (toId self) (TestSource mempty)
    hasHistory RoundHistory anyDefeated self `shouldReturn` True

  it "WithNegativeModifierFor values tokens as the named investigator" . gameTest $ \self -> do
    setChaosTokens [MinusOne, PlusOne]
    tokens <- select $ Matcher.WithNegativeModifierFor (Matcher.InvestigatorWithId (toId self))
    map (.face) tokens `shouldBe` [MinusOne]

  it "a treachery that cannot leave play stays unless it discards itself" . gameTest $ \self -> do
    def <-
      customCard
        PlayerTreacheryType
        (\d -> d {cdCardSubType = Just Weakness, cdRevelation = IsRevelation})
        [ ("_revelationPlacement", "threatArea")
        ,
          ( "_modifiers"
          , toJSON
              [ object
                  [ "kind" .= ("treachery" :: Text)
                  , "matcher" .= tagged "TreacheryWithId" ["$id"]
                  , "modifiers" .= [tagged "CannotLeavePlay" []]
                  ]
              ]
          )
        ]
    self `drawsCard` def
    treachery <- selectJust $ Matcher.TreacheryInThreatAreaOf (Matcher.InvestigatorWithId (toId self))
    run $ Discard Nothing (TestSource mempty) (TreacheryTarget treachery)
    selectAny (Matcher.TreacheryWithId treachery) `shouldReturn` True
    run $ Discard Nothing (TreacherySource treachery) (TreacheryTarget treachery)
    selectAny (Matcher.TreacheryWithId treachery) `shouldReturn` False

  it "ChaosTokenSealedOnTarget fires for a token sealed on a card you control" . gameTest $ \self -> do
    def <-
      customCard
        AssetType
        id
        [
          ( "_abilities"
          , toJSON
              [ object
                  [ "type"
                      .= object
                        [ "tag" .= ("ReactionAbility" :: Text)
                        , "window"
                            .= tagged
                              "ChaosTokenSealedOnTarget"
                              ["After", tagged "TargetControlledBy" [tagged "You" []], tagged "AnyChaosToken" []]
                        , "cost" .= tagged "Free" []
                        , "actions" .= ([] :: [Value])
                        ]
                  , "steps" .= [object ["push" .= tagged "TakeResources" ["$iid", toJSON (1 :: Int), "$source", toJSON False]]]
                  ]
              ]
          )
        ]
    asset <- self `putAssetIntoPlay` def
    tokenId <- getRandom
    let token = ChaosToken tokenId MinusOne Nothing False False
    run $ SealedChaosToken token Nothing (toTarget asset)
    useReaction
    self.resources `shouldReturn` 1

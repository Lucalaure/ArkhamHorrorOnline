module Arkham.Custom.RtNotZCardsSpec (spec) where

import Arkham.Action.Additional (AdditionalAction (..), AdditionalActionType (..))
import Arkham.Asset.Cards qualified as Assets
import Arkham.Asset.Types (Field (..))
import Arkham.Matcher qualified as Matcher
import Arkham.Name (toTitle)
import Arkham.Projection
import Arkham.Token qualified as Token
import Arkham.Treachery.Types (Field (..))
import Data.Map.Strict qualified as Map
import TestImport.New

newtype Export = Export {cards :: [CustomCard]}
  deriving stock Generic
  deriving anyclass FromJSON

{- | The scripted cards, registered, by title. Read from the docs copy so this
exercises exactly what is handed to the card builder.
-}
loadCards :: IO (Map Text CardDef)
loadCards = do
  Export cs <-
    either error pure
      =<< eitherDecodeFileStrict' "../../docs/custom-cards/rtnotz-investigator-expansion-01-10.arkhamcard.json"
  registerCustomCards $ Map.fromList [(cdCardCode (customCardDef c), c) | c <- cs]
  pure $ Map.fromList [(toTitle (customCardDef c), customCardDef c) | c <- cs]

card :: Map Text CardDef -> Text -> CardDef
card defs title = fromJustNote ("no card " <> unpack title) (Map.lookup title defs)

tokensOn :: Token.Token -> AssetId -> TestAppT Int
tokensOn t = fieldMap AssetTokens (Token.countTokens t)

spec :: Spec
spec = do
  defs <- runIO loadCards
  let def = card defs

  describe "Roland's .38 Special" $ do
    it "starts with 4 ammo and spends 1 to fight at +2 combat" . gameTest $ \self -> do
      withProp @"combat" 1 self
      location <- testLocation
      self `moveTo` location
      enemy <- testEnemy & prop @"health" 5 & prop @"fight" 3
      enemy `spawnAt` location
      gun <- self `putAssetIntoPlay` def "Roland's .38 Special"
      tokensOn Token.Ammo gun `shouldReturn` 4
      setChaosTokens [Zero]
      [fight] <- self `getActionsFrom` gun
      self `useAbility` fight
      chooseTarget enemy
      startSkillTest
      applyResults
      tokensOn Token.Ammo gun `shouldReturn` 3
      enemy.damage `shouldReturn` 1

  describe "Roland Banks" $ do
    it "places an ammo on a Firearm after a successful investigation" . gameTestWith (def "Roland Banks") $ \self -> do
      location <- testLocation & prop @"clues" 2 & prop @"shroud" 0
      self `moveTo` location
      gun <- self `putAssetIntoPlay` def "Roland's .38 Special"
      setChaosTokens [Zero]
      self `investigate` location
      startSkillTest
      applyResults
      useReaction
      chooseTarget gun
      tokensOn Token.Ammo gun `shouldReturn` 5

  describe "\"Skids\" O'Toole" $ do
    it "may take an additional action to play a card costing 3 or more" . gameTestWith (def "\"Skids\" O'Toole") $ \self -> do
      getModifiers self >>= (`shouldSatisfy` any isExtraPlayAction)

  describe "Cover Up" $ do
    it "stops clue discovery once an enemy has been defeated this round" . gameTest $ \self -> do
      location <- testLocation
      self `moveTo` location
      self `drawsCard` def "Cover Up"
      void $ selectJust $ Matcher.TreacheryInThreatAreaOf (Matcher.InvestigatorWithId (toId self))
      getModifiers self >>= (`shouldNotSatisfy` elem CannotDiscoverClues)
      enemy <- testEnemy
      enemy `spawnAt` location
      run $ DefeatEnemy (toId enemy) (toId self) (TestSource mempty)
      getModifiers self >>= (`shouldSatisfy` elem CannotDiscoverClues)

    it "is discarded by spending two actions and placing a clue" . gameTest $ \self -> do
      location <- testLocation & prop @"clues" 0
      self `moveTo` location
      run $ PlaceTokens (TestSource mempty) (toTarget self) Token.Clue 1
      self `drawsCard` def "Cover Up"
      coverUp <- selectJust $ Matcher.TreacheryInThreatAreaOf (Matcher.InvestigatorWithId (toId self))
      duringTurn self do
        [discardIt] <- self `getActionsFrom` coverUp
        self `useAbility` discardIt
      selectAny (Matcher.TreacheryWithId coverUp) `shouldReturn` False
      self.clues `shouldReturn` 0
      location.clues `shouldReturn` 1

  describe "Daisy's Tote Bag" $ do
    it "replenishes a book and readies" . gameTest $ \self -> do
      bag <- self `putAssetIntoPlay` def "Daisy's Tote Bag"
      tokensOn Token.Book bag `shouldReturn` 3
      run $ RemoveTokens (TestSource mempty) (toTarget bag) Token.Book 1
      exhaust bag
      duringTurn self do
        [replenish] <- self `getActionsFrom` bag
        self `useAbility` replenish
      tokensOn Token.Book bag `shouldReturn` 3
      field AssetExhausted bag `shouldReturn` False

  describe "The Necronomicon (John Dee Translation)" $ do
    it "enters your threat area with 3 horror and cannot be discarded while it has any" . gameTest $ \self -> do
      self `drawsCard` def "The Necronomicon"
      book <- selectJust $ Matcher.AssetWithTitle "The Necronomicon"
      tokensOn Token.Horror book `shouldReturn` 3
      run $ Discard Nothing (TestSource mempty) (AssetTarget book)
      selectAny (Matcher.AssetWithId book) `shouldReturn` True

  describe "On the Lam" $ do
    it "banks a resource for each action beyond 3 at the end of your turn" . gameTest $ \self -> do
      lam <- self `putAssetIntoPlay` def "On the Lam"
      duringTurn self do
        void $ updateThis self \attrs -> attrs {investigatorActionsTaken = replicate 5 [#resource]}
        run $ ChooseEndTurn (toId self)
        useForcedAbility
      tokensOn Token.Resource lam `shouldReturn` 2

    it "lets its resources pay for cards" . gameTest $ \self -> do
      lam <- self `putAssetIntoPlay` def "On the Lam"
      run $ PlaceTokens (TestSource mempty) (toTarget lam) Token.Resource 2
      getModifiers self >>= (`shouldSatisfy` any isSpendFromLam)

  describe "Hospital Debts" $ do
    it "adds 2 to each card's cost and removes a debt each time" . gameTest $ \self -> do
      self `drawsCard` def "Hospital Debts"
      debts <- selectJust $ Matcher.TreacheryInThreatAreaOf (Matcher.InvestigatorWithId (toId self))
      fieldMap TreacheryTokens (Token.countTokens Token.Resource) debts `shouldReturn` 3
      withProp @"resources" 5 self
      knife <- genMyCard self Assets.knife
      self `addToHand` knife
      duringTurn self do
        self `playCard` knife
        useForcedAbility
      self.resources `shouldReturn` 2
      fieldMap TreacheryTokens (Token.countTokens Token.Resource) debts `shouldReturn` 2

  describe "Agnes Baker" $ do
    it "deals 1 damage when a negative token is sealed on her card" . gameTestWith (def "Agnes Baker") $ \self -> do
      location <- testLocation
      self `moveTo` location
      enemy <- testEnemy & prop @"health" 3
      enemy `spawnAt` location
      tokenId <- getRandom
      run $ SealedChaosToken (ChaosToken tokenId MinusOne Nothing False False) (Just (toId self)) (toTarget self)
      useReaction
      chooseTarget enemy
      enemy.damage `shouldReturn` 1

    it "discovers a clue when a non-negative token is sealed on her card" . gameTestWith (def "Agnes Baker") $ \self -> do
      location <- testLocation & prop @"clues" 2
      self `moveTo` location
      tokenId <- getRandom
      run $ SealedChaosToken (ChaosToken tokenId PlusOne Nothing False False) (Just (toId self)) (toTarget self)
      useReaction
      self.clues `shouldReturn` 1
 where
  isExtraPlayAction = \case
    GiveAdditionalAction (AdditionalAction _ _ (PlayCardRestrictedAdditionalAction _)) -> True
    _ -> False
  isSpendFromLam = \case
    CanSpendUsesAsResourceOnCardFromInvestigator {} -> True
    _ -> False

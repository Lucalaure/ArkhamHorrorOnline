module Arkham.Debug.AttachSpec (spec) where

import Arkham.Asset.Cards qualified as Assets
import Arkham.Asset.Types (Field (..))
import Arkham.Matcher (AssetMatcher (..))
import Arkham.Projection (field)
import Arkham.Treachery.CardDefs.EdgeOfTheEarth qualified as Treacheries
import TestImport.New

spec :: Spec
spec = describe "Debug attaching" do
  it "attaches an asset in play to a location" . gameTest $ \self -> do
    location <- testLocation
    aid <- self `putAssetIntoPlay` Assets.flashlight
    run $ DebugAttachCard (toTarget aid) (toTarget location)
    field AssetPlacement aid `shouldReturn` AttachedToLocation (toId location)

  it "attaches an asset to another asset" . gameTest $ \self -> do
    host <- self `putAssetIntoPlay` Assets.knife
    aid <- self `putAssetIntoPlay` Assets.flashlight
    run $ DebugAttachCard (toTarget aid) (toTarget host)
    field AssetPlacement aid `shouldReturn` AttachedToAsset host Nothing

  it "discarding an attached asset takes it off its host" . gameTest $ \self -> do
    location <- testLocation
    aid <- self `putAssetIntoPlay` Assets.flashlight
    run $ DebugAttachCard (toTarget aid) (toTarget location)
    run $ Discard Nothing GameSource (toTarget aid)
    selectAny (AssetWithId aid) `shouldReturn` False

  it "an asset on a treachery leaves play with it" . gameTest $ \self -> do
    tid <- self `putTreacheryIntoPlay` Treacheries.legInjury
    aid <- self `putAssetIntoPlay` Assets.flashlight
    run $ DebugAttachCard (toTarget aid) (toTarget tid)
    run $ Discard Nothing GameSource (toTarget tid)
    selectAny (AssetWithId aid) `shouldReturn` False

  it "will not attach a card to itself" . gameTest $ \self -> do
    aid <- self `putAssetIntoPlay` Assets.flashlight
    run $ DebugAttachCard (toTarget aid) (toTarget aid)
    field AssetPlacement aid `shouldReturn` InPlayArea (toId self)

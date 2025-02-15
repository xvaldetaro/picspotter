module Nuts.Waiting.GameDetails where

import Prelude

import Control.Alt ((<|>))
import Core.Room.FormsPersistManager (getFormsPersist, saveFormsPersist)
import Core.Room.GameManager (setAllowNonAdmins, startGame)
import Data.Int (floor)
import Data.Tuple.Nested ((/\))
import Deku.Attribute (attr, (:=))
import Deku.Control (text, text_)
import Deku.Core (Domable)
import Deku.DOM as D
import Deku.Do (useState, useStates, useStates')
import Deku.Do as Doku
import Deku.Listeners (checkbox, click)
import Deku.Listeners as DL
import Effect (Effect)
import Effect.Aff (launchAff_)
import FRP.Event.VBus (V)
import Models.Models (FormsPersistRow, FormsPersist)
import Nuts.Dumb.Btn as Btn
import Nuts.Dumb.Input (inputCss, inputText')
import Nuts.Dumb.Modal (modal)
import Nuts.Room.RoomEnv (RoomEnv)
import Nuts.Waiting.BankModal as BankModal
import Paraglider.Operator.Combine (combineLatest3)
import Paraglider.Operator.FromAff (fromAff)
import Paraglider.Operator.Multiplex (multiplex)
import Paraglider.Operator.Take (take)
import Platform.Deku.Html (bangCss, bangPlaceholder, css)
import Platform.Deku.Misc (cleanFbAff, ife, useCleanFbEvent)
import Platform.Deku.VBusHelp (vbussedFrom)
import Platform.Firebase.Auth (uid)
import Type.Proxy (Proxy(..))

defaultDuration :: Number
defaultDuration = 100.0

type UIEvents =
  ( clearTopic :: String
  , allowNonAdminToStartGame :: Boolean
  , showBank :: Boolean
  )
type GameFormEvents = FormsPersistRow

nut :: ∀ l p. RoomEnv -> Domable l p
nut roomEnv@{ env: env@{ fb, self, errPush }, playersEv, roomId, gameEv } = Doku.do
  fopeEv <- useCleanFbEvent env $ fromAff $ getFormsPersist fb roomId
  pUi /\ uiE <- useStates (Proxy :: _ (V UIEvents)) { showBank: false }
  pForms /\ formsE <- vbussedFrom (Proxy :: _ (V FormsPersistRow)) fopeEv

  let
    topicSetValueEv = uiE.clearTopic <|> ((_.topic) <$> fopeEv)
    onBankPickCategory ctg = do
      pUi.showBank false
      pUi.clearTopic ctg
      pForms.topic ctg

    isAllowedEv = gameEv <#> (_.allowNonAdminToStartGame)
    doChangeAllow v = launchAff_ $ cleanFbAff env $ setAllowNonAdmins fb roomId v
    allowNonAdminField =
      if isAdmin then D.label (bangCss "ml-3 flex items-center text-sm font-medium mt-2")
        [ D.span (bangCss "mr-2") [ text_ "Allow Players to Start a Game?" ]
        , D.input
            ( (bangCss $ (css "mr-3") <> inputCss)
                <|> (pure $ D.Xtype := "checkbox")
                <|> (attr D.Checked <<< show <$> (take 1 isAllowedEv))
                <|> (checkbox $ pure doChangeAllow)
            )
            []
        ]
      else text_ ""

    topicField = D.label (bangCss "ml-3 flex items-center font-medium")
      [ D.span (bangCss "mr-2") [ text_ "Category" ]
      , D.div (bangCss "flex-grow mr-3")
          [ inputText'
              ( (bangCss $ (css "w-full") <> inputCss)
                  <|> (bangPlaceholder "Countries In Europe")
                  <|> (attr D.Value <$> topicSetValueEv)
                  <|> (DL.textInput $ pure pForms.topic)
              )
          , D.i (bangCss "ion-close-circled -ml-5" <|> (click $ pure $ pUi.clearTopic "")) []
          ]
      , D.button (click $ pure $ pUi.showBank true)
          [ D.i (bangCss "ml-2 mr-3 ion-folder text-xl") [] ]
      ]

    durationField = D.label (bangCss "ml-3 flex items-center font-medium mt-2")
      [ D.span (bangCss "mr-2") [ text_ "Duration (seconds)" ]
      , D.input
          ( (bangCss $ (css "mr-3") <> inputCss)
              <|> (pure $ D.Xtype := "number")
              <|> (attr D.Value <$> (show <<< floor <$> formsE.duration))
              <|> (DL.numeric $ pure pForms.duration)
          )
          []
      ]

    addRandomLetterField = D.label (bangCss "ml-3 flex items-center font-medium mt-2")
      [ D.span (bangCss "mr-2") [ text_ "Add a random letter" ]
      , D.input
          ( (bangCss $ (css "mr-3") <> inputCss)
              <|> (pure $ D.Xtype := "checkbox")
              <|> (attr D.Checked <<< show <<< (_.addRandomLetter) <$> fopeEv)
              <|> (checkbox $ pure pForms.addRandomLetter)
          )
          []
      ]

    allowStopField = D.label (bangCss "ml-3 flex items-center font-medium mt-2")
      [ D.span (bangCss "mr-2") [ text_ "Allow STOP!" ]
      , D.input
          ( (bangCss $ (css "mr-3") <> inputCss)
              <|> (pure $ D.Xtype := "checkbox")
              <|> (attr D.Checked <<< show <<< (_.allowStop) <$> fopeEv)
              <|> (checkbox $ pure pForms.allowStop)
          )
          []
      ]

    bankModal = modal uiE.showBank $ BankModal.nut roomEnv (pUi.showBank false) onBankPickCategory

  let
    doCreateGame :: FormsPersist -> Effect Unit
    doCreateGame formsPersist = launchAff_ do
      cleanFbAff env $ saveFormsPersist fb roomId formsPersist
      cleanFbAff env $ startGame fb roomId formsPersist

    doCreateGameEv = doCreateGame <$> multiplex formsE
      -- { topic: e.topic
      -- , durationn: e.duration
      -- , addRandomLetter: e.addRandomLetter
      -- , allowStop: e.allowStop
      -- }

    canCreateEv = if isAdmin then pure true else gameEv <#> (_.allowNonAdminToStartGame)
    btnTextEv = canCreateEv <#> ife "Start Game" "No Permission to Start Game"

  D.div (bangCss "flex flex-col w-full")
    [ allowNonAdminField
    , D.span (bangCss "text-lg text-center font-semibold mt-3 mb-2") [ text_ $ "Game Details" ]
    , topicField
    , durationField
    , addRandomLetterField
    , allowStopField
    , D.button
        ( (click $ doCreateGameEv)
            <|> (attr D.Disabled <<< show <<< not <$> canCreateEv)
            <|> bangCss (Btn.baseCss <> Btn.tealCss <> css "mx-3 mt-2")
        )
        [ text btnTextEv ]
    , bankModal
    ]

  where
  isAdmin = roomId == (uid self)

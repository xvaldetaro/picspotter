module App.Route where

import Prelude hiding ((/))

import Data.Generic.Rep (class Generic)
import Data.Show.Generic (genericShow)
import Routing.Duplex (RouteDuplex', root, segment)
import Routing.Duplex.Generic (noArgs, sum)
import Routing.Duplex.Generic.Syntax ((/))

data Route
  = Landing
  | Room String
  | Bank
  | Debug
  -- Debug Learning Routes
  | PlaygroundDummy
  | PlaygroundFrp
  | PlayerList
  | CreatePlayer

derive instance genericRoute :: Generic Route _
derive instance eqRoute :: Eq Route
derive instance ordRoute :: Ord Route
instance showRoute :: Show Route where
  show = genericShow

routeCodec :: RouteDuplex' Route
routeCodec = root $ sum
  { "Landing": noArgs
  , "Room": "roomId" / segment
  , "Bank": "bank" / noArgs
  , "Debug": "debug" / noArgs
  -- Debug Learning Routes
  , "PlaygroundDummy": "playgrounddummy" / noArgs
  , "PlaygroundFrp": "playgroundfrp" / noArgs
  , "PlayerList": "playerlist" / noArgs
  , "CreatePlayer": "createplayer" / noArgs
  }

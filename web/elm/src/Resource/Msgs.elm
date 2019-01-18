module Resource.Msgs exposing
    ( Hoverable(..)
    , Msg(..)
    , VersionToggleAction(..)
    )

import Concourse
import Concourse.Pagination exposing (Page, Paginated)
import Http
import Time exposing (Time)


type VersionToggleAction
    = Enable
    | Disable


type Hoverable
    = PreviousPage
    | NextPage
    | None


type Msg
    = Noop
    | AutoupdateTimerTicked Time
    | LoadPage Page
    | ClockTick Time.Time
    | ExpandVersionedResource Int
    | NavTo String
    | TogglePinBarTooltip
    | ToggleVersionTooltip
    | PinVersion Int
    | UnpinVersion
    | ToggleVersion VersionToggleAction Int
    | PinIconHover Bool
    | Hover Hoverable

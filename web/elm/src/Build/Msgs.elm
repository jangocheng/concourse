module Build.Msgs exposing (HoveredButton(..), Msg(..))

import Concourse
import Concourse.BuildEvents
import Http
import Keyboard
import Scroll
import StrictEvents
import Time


type Msg
    = Noop
    | SwitchToBuild Concourse.Build
    | Hover HoveredButton
    | TriggerBuild (Maybe Concourse.JobIdentifier)
    | AbortBuild Int
    | ScrollBuilds StrictEvents.MouseWheelEvent
    | ClockTick Time.Time
    | RevealCurrentBuildInHistory
    | WindowScrolled Scroll.FromBottom
    | NavTo String
    | NewCSRFToken String
    | KeyPressed Keyboard.KeyCode
    | KeyUped Keyboard.KeyCode
    | BuildEventsMsg Concourse.BuildEvents.Msg
    | ToggleStep String
    | SwitchTab String Int
    | SetHighlight String Int
    | ExtendHighlight String Int


type HoveredButton
    = Neither
    | Abort
    | Trigger

port module Effects exposing
    ( Callback(..)
    , Effect(..)
    , renderPipeline
    , resetPipelineFocus
    , runEffect
    , setTitle
    )

import Concourse
import Concourse.Build
import Concourse.BuildResources
import Concourse.Info
import Concourse.Job
import Concourse.Pagination exposing (Page, Paginated)
import Concourse.Pipeline
import Concourse.PipelineStatus
import Concourse.Resource
import Concourse.User
import Dashboard.APIData
import Dashboard.Group
import Dashboard.Models
import Dom
import Http
import Json.Encode
import LoginRedirect
import Navigation
import QueryString
import RemoteData
import Resource.Msgs exposing (VersionToggleAction(..))
import Task
import Time exposing (Time)
import Window


port setTitle : String -> Cmd msg


port resetPipelineFocus : () -> Cmd msg


port renderPipeline : ( Json.Encode.Value, Json.Encode.Value ) -> Cmd msg


port pinTeamNames : Dashboard.Group.StickyHeaderConfig -> Cmd msg


port tooltip : ( String, String ) -> Cmd msg


port tooltipHd : ( String, String ) -> Cmd msg


type Effect
    = FetchJob Concourse.JobIdentifier
    | FetchJobs Concourse.PipelineIdentifier
    | FetchJobBuilds Concourse.JobIdentifier (Maybe Page)
    | FetchResource Concourse.ResourceIdentifier
    | FetchVersionedResources Concourse.ResourceIdentifier (Maybe Page)
    | FetchResources Concourse.PipelineIdentifier
    | FetchBuildResources Concourse.BuildId
    | FetchPipeline Concourse.PipelineIdentifier
    | FetchVersion
    | FetchInputTo Concourse.VersionedResourceIdentifier
    | FetchOutputOf Concourse.VersionedResourceIdentifier
    | FetchData
    | FocusSearchInput
    | GetCurrentTime
    | DoTriggerBuild Concourse.JobIdentifier String
    | PauseJob Concourse.JobIdentifier String
    | UnpauseJob Concourse.JobIdentifier String
    | ResetPipelineFocus
    | RenderPipeline Json.Encode.Value Json.Encode.Value
    | RedirectToLogin
    | NavigateTo String
    | SetTitle String
    | NewUrl String
    | ModifyUrl String
    | DoPinVersion Concourse.VersionedResourceIdentifier Concourse.CSRFToken
    | DoUnpinVersion Concourse.ResourceIdentifier Concourse.CSRFToken
    | DoEnableDisableVersionedResource VersionToggleAction Concourse.VersionedResourceIdentifier Concourse.CSRFToken
    | SendTokenToFly String Int
    | SendTogglePipelineRequest { pipeline : Dashboard.Models.Pipeline, csrfToken : Concourse.CSRFToken }
    | ShowTooltip ( String, String )
    | ShowTooltipHd ( String, String )
    | SendOrderPipelinesRequest String (List Dashboard.Models.Pipeline) Concourse.CSRFToken
    | SendLogOutRequest
    | GetScreenSize
    | PinTeamNames Dashboard.Group.StickyHeaderConfig


type Callback
    = EmptyCallback
    | GotCurrentTime Time
    | BuildTriggered (Result Http.Error Concourse.Build)
    | JobBuildsFetched (Result Http.Error (Paginated Concourse.Build))
    | JobFetched (Result Http.Error Concourse.Job)
    | JobsFetched (Result Http.Error Json.Encode.Value)
    | PipelineFetched (Result Http.Error Concourse.Pipeline)
    | ResourcesFetched (Result Http.Error Json.Encode.Value)
    | BuildResourcesFetched Int (Result Http.Error Concourse.BuildResources)
    | ResourceFetched (Result Http.Error Concourse.Resource)
    | VersionedResourcesFetched (Maybe Page) (Result Http.Error (Paginated Concourse.VersionedResource))
    | VersionFetched (Result Http.Error String)
    | PausedToggled (Result Http.Error ())
    | InputToFetched Int (Result Http.Error (List Concourse.Build))
    | OutputOfFetched Int (Result Http.Error (List Concourse.Build))
    | VersionPinned (Result Http.Error ())
    | VersionUnpinned (Result Http.Error ())
    | VersionToggled VersionToggleAction Int (Result Http.Error ())
    | TokenSentToFly Bool
    | APIDataFetched (RemoteData.WebData ( Time.Time, Dashboard.APIData.APIData ))
    | LoggedOut (Result Http.Error ())
    | ScreenResized Window.Size


runEffect : Effect -> Cmd Callback
runEffect effect =
    case effect of
        FetchJob id ->
            fetchJob id

        FetchJobs id ->
            fetchJobs id

        FetchJobBuilds id page ->
            fetchJobBuilds id page

        FetchResource id ->
            fetchResource id

        FetchVersionedResources id paging ->
            fetchVersionedResources id paging

        FetchResources id ->
            fetchResources id

        FetchBuildResources id ->
            fetchBuildResources id

        FetchPipeline id ->
            fetchPipeline id

        FetchVersion ->
            fetchVersion

        FetchInputTo id ->
            fetchInputTo id

        FetchOutputOf id ->
            fetchOutputOf id

        FetchData ->
            fetchData

        GetCurrentTime ->
            getCurrentTime

        DoTriggerBuild id csrf ->
            triggerBuild id csrf

        PauseJob id csrf ->
            pauseJob id csrf

        UnpauseJob id csrf ->
            unpauseJob id csrf

        RedirectToLogin ->
            LoginRedirect.requestLoginRedirect ""

        NavigateTo newUrl ->
            Navigation.newUrl newUrl

        ResetPipelineFocus ->
            resetPipelineFocus ()

        RenderPipeline jobs resources ->
            renderPipeline ( jobs, resources )

        NewUrl newUrl ->
            Navigation.newUrl newUrl

        SetTitle newTitle ->
            setTitle newTitle

        DoPinVersion version csrfToken ->
            Task.attempt VersionPinned <|
                Concourse.Resource.pinVersion version csrfToken

        DoUnpinVersion id csrfToken ->
            Task.attempt VersionUnpinned <|
                Concourse.Resource.unpinVersion id csrfToken

        DoEnableDisableVersionedResource action id csrfToken ->
            Task.attempt (VersionToggled action id.versionID) <|
                Concourse.Resource.enableDisableVersionedResource
                    (action == Enable)
                    id
                    csrfToken

        SendTokenToFly authToken flyPort ->
            sendTokenToFly authToken flyPort

        FocusSearchInput ->
            Task.attempt (always EmptyCallback) (Dom.focus "search-input-field")

        ModifyUrl url ->
            Navigation.modifyUrl url

        SendTogglePipelineRequest { pipeline, csrfToken } ->
            togglePipelinePaused { pipeline = pipeline, csrfToken = csrfToken }

        ShowTooltip ( teamName, pipelineName ) ->
            tooltip ( teamName, pipelineName )

        ShowTooltipHd ( teamName, pipelineName ) ->
            tooltipHd ( teamName, pipelineName )

        SendOrderPipelinesRequest teamName pipelines csrfToken ->
            orderPipelines teamName pipelines csrfToken

        SendLogOutRequest ->
            logOut

        GetScreenSize ->
            Task.perform ScreenResized Window.size

        PinTeamNames stickyHeaderConfig ->
            pinTeamNames stickyHeaderConfig


fetchJobBuilds :
    Concourse.JobIdentifier
    -> Maybe Concourse.Pagination.Page
    -> Cmd Callback
fetchJobBuilds jobIdentifier page =
    Task.attempt JobBuildsFetched <|
        Concourse.Build.fetchJobBuilds jobIdentifier page


fetchJob : Concourse.JobIdentifier -> Cmd Callback
fetchJob jobIdentifier =
    Task.attempt JobFetched <|
        Concourse.Job.fetchJob jobIdentifier


fetchResource : Concourse.ResourceIdentifier -> Cmd Callback
fetchResource resourceIdentifier =
    Task.attempt ResourceFetched <|
        Concourse.Resource.fetchResource resourceIdentifier


fetchVersionedResources : Concourse.ResourceIdentifier -> Maybe Page -> Cmd Callback
fetchVersionedResources resourceIdentifier page =
    Task.attempt (VersionedResourcesFetched page) <|
        Concourse.Resource.fetchVersionedResources resourceIdentifier page


fetchBuildResources : Concourse.BuildId -> Cmd Callback
fetchBuildResources buildIdentifier =
    Task.attempt (BuildResourcesFetched buildIdentifier) <|
        Concourse.BuildResources.fetch buildIdentifier


fetchResources : Concourse.PipelineIdentifier -> Cmd Callback
fetchResources pid =
    Task.attempt ResourcesFetched <| Concourse.Resource.fetchResourcesRaw pid


fetchJobs : Concourse.PipelineIdentifier -> Cmd Callback
fetchJobs pid =
    Task.attempt JobsFetched <| Concourse.Job.fetchJobsRaw pid


fetchVersion : Cmd Callback
fetchVersion =
    Concourse.Info.fetch
        |> Task.map .version
        |> Task.attempt VersionFetched


fetchPipeline : Concourse.PipelineIdentifier -> Cmd Callback
fetchPipeline pipelineIdentifier =
    Task.attempt PipelineFetched <|
        Concourse.Pipeline.fetchPipeline pipelineIdentifier


fetchInputTo : Concourse.VersionedResourceIdentifier -> Cmd Callback
fetchInputTo versionedResourceIdentifier =
    Task.attempt (InputToFetched versionedResourceIdentifier.versionID) <|
        Concourse.Resource.fetchInputTo versionedResourceIdentifier


fetchOutputOf : Concourse.VersionedResourceIdentifier -> Cmd Callback
fetchOutputOf versionedResourceIdentifier =
    Task.attempt (OutputOfFetched versionedResourceIdentifier.versionID) <|
        Concourse.Resource.fetchOutputOf versionedResourceIdentifier


getCurrentTime : Cmd Callback
getCurrentTime =
    Task.perform GotCurrentTime Time.now


triggerBuild : Concourse.JobIdentifier -> Concourse.CSRFToken -> Cmd Callback
triggerBuild job csrfToken =
    Task.attempt BuildTriggered <|
        Concourse.Job.triggerBuild job csrfToken


pauseJob : Concourse.JobIdentifier -> Concourse.CSRFToken -> Cmd Callback
pauseJob jobIdentifier csrfToken =
    Task.attempt PausedToggled <|
        Concourse.Job.pause jobIdentifier csrfToken


unpauseJob : Concourse.JobIdentifier -> Concourse.CSRFToken -> Cmd Callback
unpauseJob jobIdentifier csrfToken =
    Task.attempt PausedToggled <|
        Concourse.Job.unpause jobIdentifier csrfToken


sendTokenToFly : String -> Int -> Cmd Callback
sendTokenToFly authToken flyPort =
    let
        queryString =
            QueryString.empty
                |> QueryString.add "token" authToken
                |> QueryString.render
    in
    Http.request
        { method = "GET"
        , headers = []
        , url = "http://127.0.0.1:" ++ toString flyPort ++ queryString
        , body = Http.emptyBody
        , expect = Http.expectStringResponse (\_ -> Ok ())
        , timeout = Nothing
        , withCredentials = False
        }
        |> Http.send (\r -> TokenSentToFly (r == Ok ()))


fetchData : Cmd Callback
fetchData =
    Dashboard.APIData.remoteData
        |> Task.map2 (,) Time.now
        |> RemoteData.asCmd
        |> Cmd.map APIDataFetched


togglePipelinePaused : { pipeline : Dashboard.Models.Pipeline, csrfToken : Concourse.CSRFToken } -> Cmd Callback
togglePipelinePaused { pipeline, csrfToken } =
    Task.attempt (always EmptyCallback) <|
        if pipeline.status == Concourse.PipelineStatus.PipelineStatusPaused then
            Concourse.Pipeline.unpause pipeline.teamName pipeline.name csrfToken

        else
            Concourse.Pipeline.pause pipeline.teamName pipeline.name csrfToken


orderPipelines : String -> List Dashboard.Models.Pipeline -> Concourse.CSRFToken -> Cmd Callback
orderPipelines teamName pipelines csrfToken =
    Task.attempt (always EmptyCallback) <|
        Concourse.Pipeline.order
            teamName
            (List.map .name pipelines)
            csrfToken


logOut : Cmd Callback
logOut =
    Task.attempt LoggedOut Concourse.User.logOut

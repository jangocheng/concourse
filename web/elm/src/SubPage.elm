module SubPage exposing
    ( Model(..)
    , init
    , subscriptions
    , update
    , urlUpdate
    , view
    )

import Autoscroll
import Build
import Build.Msgs
import Concourse
import Dashboard
import Effects
import FlySuccess
import Html exposing (Html)
import Html.Styled as HS
import Job
import NotFound
import Pipeline
import QueryString
import Resource
import Routes
import String
import SubPage.Msgs exposing (Msg(..))
import UpdateMsg exposing (UpdateMsg)


type Model
    = WaitingModel Routes.ConcourseRoute
    | BuildModel (Autoscroll.Model Build.Model)
    | JobModel Job.Model
    | ResourceModel Resource.Model
    | PipelineModel Pipeline.Model
    | NotFoundModel NotFound.Model
    | DashboardModel Dashboard.Model
    | FlySuccessModel FlySuccess.Model


type alias Flags =
    { csrfToken : String
    , authToken : String
    , turbulencePath : String
    , pipelineRunningKeyframes : String
    }


superDupleWrap : ( a -> b, c -> d ) -> ( a, Cmd c ) -> ( b, Cmd d )
superDupleWrap ( modelFunc, msgFunc ) ( model, msg ) =
    ( modelFunc model, Cmd.map msgFunc msg )


queryGroupsForRoute : Routes.ConcourseRoute -> List String
queryGroupsForRoute route =
    QueryString.all "groups" route.queries


querySearchForRoute : Routes.ConcourseRoute -> String
querySearchForRoute route =
    QueryString.one QueryString.string "search" route.queries
        |> Maybe.withDefault ""


init : Flags -> Routes.ConcourseRoute -> ( Model, Cmd Msg )
init flags route =
    case route.logical of
        Routes.Build teamName pipelineName jobName buildName ->
            superDupleWrap ( BuildModel, CallbackAutoScroll ) <|
                Autoscroll.init
                    Build.getScrollBehavior
                    << Tuple.mapSecond (Cmd.batch << List.map Effects.runEffect)
                    << Build.init
                        { csrfToken = flags.csrfToken, hash = route.hash }
                <|
                    Build.JobBuildPage
                        { teamName = teamName
                        , pipelineName = pipelineName
                        , jobName = jobName
                        , buildName = buildName
                        }

        Routes.OneOffBuild buildId ->
            superDupleWrap ( BuildModel, CallbackAutoScroll ) <|
                Autoscroll.init
                    Build.getScrollBehavior
                    << Tuple.mapSecond (Cmd.batch << List.map Effects.runEffect)
                    << Build.init
                        { csrfToken = flags.csrfToken, hash = route.hash }
                <|
                    Build.BuildPage <|
                        Result.withDefault 0 (String.toInt buildId)

        Routes.Resource teamName pipelineName resourceName ->
            superDupleWrap ( ResourceModel, Callback )
                (Resource.init
                    { resourceName = resourceName
                    , teamName = teamName
                    , pipelineName = pipelineName
                    , paging = route.page
                    , csrfToken = flags.csrfToken
                    }
                    |> Tuple.mapSecond
                        (List.map Effects.runEffect >> Cmd.batch)
                )

        Routes.Job teamName pipelineName jobName ->
            superDupleWrap ( JobModel, Callback )
                (Job.init
                    { jobName = jobName
                    , teamName = teamName
                    , pipelineName = pipelineName
                    , paging = route.page
                    , csrfToken = flags.csrfToken
                    }
                    |> Tuple.mapSecond
                        (List.map Effects.runEffect >> Cmd.batch)
                )

        Routes.Pipeline teamName pipelineName ->
            superDupleWrap ( PipelineModel, Callback )
                (Pipeline.init
                    { teamName = teamName
                    , pipelineName = pipelineName
                    , turbulenceImgSrc = flags.turbulencePath
                    , route = route
                    }
                    |> Tuple.mapSecond
                        (List.map Effects.runEffect >> Cmd.batch)
                )

        Routes.Dashboard ->
            superDupleWrap ( DashboardModel, Callback )
                (Dashboard.init
                    { turbulencePath = flags.turbulencePath
                    , csrfToken = flags.csrfToken
                    , search = querySearchForRoute route
                    , highDensity = False
                    , pipelineRunningKeyframes = flags.pipelineRunningKeyframes
                    }
                    |> Tuple.mapSecond
                        (List.map Effects.runEffect >> Cmd.batch)
                )

        Routes.DashboardHd ->
            superDupleWrap ( DashboardModel, Callback )
                (Dashboard.init
                    { turbulencePath = flags.turbulencePath
                    , csrfToken = flags.csrfToken
                    , search = querySearchForRoute route
                    , highDensity = True
                    , pipelineRunningKeyframes = flags.pipelineRunningKeyframes
                    }
                    |> Tuple.mapSecond
                        (List.map Effects.runEffect >> Cmd.batch)
                )

        Routes.FlySuccess ->
            superDupleWrap ( FlySuccessModel, Callback )
                (FlySuccess.init
                    { authToken = flags.authToken
                    , flyPort = QueryString.one QueryString.int "fly_port" route.queries
                    }
                    |> Tuple.mapSecond
                        (List.map Effects.runEffect >> Cmd.batch)
                )


handleNotFound : String -> ( a -> Model, c -> Msg ) -> ( a, Cmd c, Maybe UpdateMsg ) -> ( Model, Cmd Msg )
handleNotFound notFound ( mdlFunc, msgFunc ) ( mdl, msg, outMessage ) =
    case outMessage of
        Just UpdateMsg.NotFound ->
            ( NotFoundModel { notFoundImgSrc = notFound }, Effects.setTitle "Not Found " )

        Nothing ->
            superDupleWrap ( mdlFunc, msgFunc ) <| ( mdl, msg )


update : String -> String -> Concourse.CSRFToken -> Msg -> Model -> ( Model, Cmd Msg )
update turbulence notFound csrfToken msg mdl =
    case ( msg, mdl ) of
        ( NewCSRFToken c, BuildModel scrollModel ) ->
            let
                buildModel =
                    scrollModel.subModel

                ( newBuildModel, buildEffects ) =
                    Build.update (Build.Msgs.NewCSRFToken c) buildModel
            in
            ( BuildModel { scrollModel | subModel = newBuildModel }
            , buildEffects
                |> List.map Effects.runEffect
                |> Cmd.batch
                |> Cmd.map (\buildMsg -> CallbackAutoScroll (Autoscroll.SubMsg buildMsg))
            )

        ( BuildMsg message, BuildModel scrollModel ) ->
            let
                subModel =
                    scrollModel.subModel

                model =
                    { scrollModel | subModel = { subModel | csrfToken = csrfToken } }
            in
            handleNotFound notFound ( BuildModel, CallbackAutoScroll ) (Autoscroll.update Build.updateWithMessage message model)

        ( CallbackAutoScroll callback, BuildModel scrollModel ) ->
            let
                subModel =
                    scrollModel.subModel

                model =
                    { scrollModel | subModel = { subModel | csrfToken = csrfToken } }
            in
            handleNotFound notFound ( BuildModel, CallbackAutoScroll ) (Autoscroll.update Build.handleCallbackWithMessage callback model)

        ( NewCSRFToken c, JobModel model ) ->
            ( JobModel { model | csrfToken = c }, Cmd.none )

        ( JobMsg message, JobModel model ) ->
            handleNotFound notFound ( JobModel, Callback ) (Job.updateWithMessage message { model | csrfToken = csrfToken })

        ( Callback callback, JobModel model ) ->
            handleNotFound notFound ( JobModel, Callback ) (Job.handleCallbackWithMessage callback { model | csrfToken = csrfToken })

        ( PipelineMsg message, PipelineModel model ) ->
            handleNotFound notFound ( PipelineModel, Callback ) (Pipeline.updateWithMessage message model)

        ( Callback callback, PipelineModel model ) ->
            handleNotFound notFound ( PipelineModel, Callback ) (Pipeline.handleCallbackWithMessage callback model)

        ( NewCSRFToken c, ResourceModel model ) ->
            ( ResourceModel { model | csrfToken = c }, Cmd.none )

        ( ResourceMsg message, ResourceModel model ) ->
            handleNotFound notFound ( ResourceModel, Callback ) (Resource.updateWithMessage message { model | csrfToken = csrfToken })

        ( Callback callback, ResourceModel model ) ->
            handleNotFound notFound ( ResourceModel, Callback ) (Resource.handleCallbackWithMessage callback { model | csrfToken = csrfToken })

        ( NewCSRFToken c, DashboardModel model ) ->
            ( DashboardModel { model | csrfToken = c }, Cmd.none )

        ( DashboardMsg message, DashboardModel model ) ->
            Dashboard.update message model
                |> Tuple.mapSecond
                    (List.map Effects.runEffect >> Cmd.batch)
                |> superDupleWrap ( DashboardModel, Callback )

        ( Callback callback, DashboardModel model ) ->
            Dashboard.handleCallback callback model
                |> Tuple.mapSecond
                    (List.map Effects.runEffect >> Cmd.batch)
                |> superDupleWrap ( DashboardModel, Callback )

        ( FlySuccessMsg message, FlySuccessModel model ) ->
            superDupleWrap ( FlySuccessModel, Callback )
                (FlySuccess.update message model
                    |> Tuple.mapSecond
                        (List.map Effects.runEffect >> Cmd.batch)
                )

        ( Callback callback, FlySuccessModel model ) ->
            superDupleWrap ( FlySuccessModel, Callback )
                (FlySuccess.handleCallback callback model
                    |> Tuple.mapSecond
                        (List.map Effects.runEffect >> Cmd.batch)
                )

        ( NewCSRFToken _, _ ) ->
            ( mdl, Cmd.none )

        unknown ->
            flip always (Debug.log "impossible combination" unknown) <|
                ( mdl, Cmd.none )


urlUpdate : Routes.ConcourseRoute -> Model -> ( Model, Cmd Msg )
urlUpdate route model =
    case ( route.logical, model ) of
        ( Routes.Pipeline team pipeline, PipelineModel mdl ) ->
            superDupleWrap ( PipelineModel, Callback ) <|
                Pipeline.changeToPipelineAndGroups
                    { teamName = team
                    , pipelineName = pipeline
                    , turbulenceImgSrc = mdl.turbulenceImgSrc
                    , route = route
                    }
                    mdl

        ( Routes.Resource teamName pipelineName resourceName, ResourceModel mdl ) ->
            superDupleWrap ( ResourceModel, Callback ) <|
                (Resource.changeToResource
                    { teamName = teamName
                    , pipelineName = pipelineName
                    , resourceName = resourceName
                    , paging = route.page
                    , csrfToken = mdl.csrfToken
                    }
                    mdl
                    |> Tuple.mapSecond
                        (List.map Effects.runEffect >> Cmd.batch)
                )

        ( Routes.Job teamName pipelineName jobName, JobModel mdl ) ->
            superDupleWrap ( JobModel, Callback )
                (Job.changeToJob
                    { teamName = teamName
                    , pipelineName = pipelineName
                    , jobName = jobName
                    , paging = route.page
                    , csrfToken = mdl.csrfToken
                    }
                    mdl
                    |> Tuple.mapSecond
                        (List.map Effects.runEffect >> Cmd.batch)
                )

        ( Routes.Build teamName pipelineName jobName buildName, BuildModel scrollModel ) ->
            let
                ( submodel, subcmd ) =
                    Build.changeToBuild
                        (Build.JobBuildPage
                            { teamName = teamName
                            , pipelineName = pipelineName
                            , jobName = jobName
                            , buildName = buildName
                            }
                        )
                        scrollModel.subModel
                        |> Tuple.mapSecond (List.map Effects.runEffect)
                        |> Tuple.mapSecond Cmd.batch
            in
            ( BuildModel { scrollModel | subModel = submodel }
            , Cmd.map CallbackAutoScroll (Cmd.map Autoscroll.SubMsg subcmd)
            )

        _ ->
            ( model, Cmd.none )


view : Model -> Html Msg
view mdl =
    case mdl of
        BuildModel model ->
            Html.map BuildMsg <| Autoscroll.view Build.view model

        JobModel model ->
            Html.map JobMsg <| Job.view model

        PipelineModel model ->
            Html.map PipelineMsg <| Pipeline.view model

        ResourceModel model ->
            Html.map ResourceMsg <| (HS.toUnstyled << Resource.view) model

        DashboardModel model ->
            (Html.map DashboardMsg << HS.toUnstyled) <| Dashboard.view model

        WaitingModel _ ->
            Html.div [] []

        NotFoundModel model ->
            NotFound.view model

        FlySuccessModel model ->
            Html.map FlySuccessMsg <| FlySuccess.view model


subscriptions : Model -> Sub Msg
subscriptions mdl =
    case mdl of
        BuildModel model ->
            Sub.map BuildMsg <| Autoscroll.subscriptions Build.subscriptions model

        JobModel model ->
            Sub.map JobMsg <| Job.subscriptions model

        PipelineModel model ->
            Sub.map PipelineMsg <| Pipeline.subscriptions model

        ResourceModel model ->
            Sub.map ResourceMsg <| Resource.subscriptions model

        DashboardModel model ->
            Sub.map DashboardMsg <| Dashboard.subscriptions model

        WaitingModel _ ->
            Sub.none

        NotFoundModel _ ->
            Sub.none

        FlySuccessModel _ ->
            Sub.none

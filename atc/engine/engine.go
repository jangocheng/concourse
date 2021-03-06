package engine

import (
	"io"

	"code.cloudfoundry.org/lager"
	"github.com/concourse/concourse/atc"
	"github.com/concourse/concourse/atc/db"
)

//go:generate counterfeiter . Engine

type Engine interface {
	Name() string

	CreateBuild(lager.Logger, db.Build, atc.Plan) (Build, error)
	LookupBuild(lager.Logger, db.Build) (Build, error)
	ReleaseAll(lager.Logger)
}

//go:generate counterfeiter . Build

type Build interface {
	Metadata() string

	Abort(lager.Logger) error
	Resume(lager.Logger)

	ReceiveInput(lager.Logger, atc.PlanID, io.ReadCloser)
	SendOutput(lager.Logger, atc.PlanID, io.Writer)
}

type Engines []Engine

func (engines Engines) Lookup(name string) (Engine, bool) {
	for _, e := range engines {
		if e.Name() == name {
			return e, true
		}
	}

	return nil, false
}

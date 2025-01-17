package container

type Container struct {
	Name            string
	Home            string // path to home on user machine
	Exports         []string
	Imports         []string
	PreScriptsBase  string // path to scripts/pre dir
	PeriScriptsBase string // path to scripts/pre dir
	PostScriptsBase string // path to scripts/pre dir
}

var instance *Container

func GetInstance() *Container {
	if instance == nil {
		instance = new(Container)
	}

	return instance
}

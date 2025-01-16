package container

type Container struct {
	Name            string
	Home            string // path to home on user machine
	exports         []string
	imports         []string
	preScriptsBase  string // path to scripts/pre dir
	periScriptsBase string // path to scripts/pre dir
	postScriptsBase string // path to scripts/pre dir
}

var instance *Container

func GetInstance() *Container {
	if instance == nil {
		instance = new(Container)
	}

	return instance
}

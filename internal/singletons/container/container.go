package container

type Container struct {
	Name            string
	Home            string // path to home on user machine
	Exports         []string
	Imports         []string
	ScriptsBasePath string
}

var instance *Container

func GetInstance() *Container {
	if instance == nil {
		instance = new(Container)
	}

	return instance
}

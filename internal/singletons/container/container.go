package container

type Container struct {
	Name        string
	Home        string // path to home on user machine
	exports     []string
	imports     []string
	preScripts  []string // list of paths
	periScripts []string // list of paths
	postScripts []string // list of paths
}

var instance *Container

func GetInstance() *Container {
	if instance == nil {
		instance = new(Container)
	}

	return instance
}

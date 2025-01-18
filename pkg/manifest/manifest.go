package manifest

// Manifest - the root of a manifest file
type Manifest struct {
	Container Container `yaml:"container"`
	Image     Image     `yaml:"image"`
}

// Container - the container tag of a manifest file, holds information about a container like name, home, imports, exports, and Scripts
type Container struct {
	Name    string   `yaml:"name"`
	Home    string   `yaml:"home"`
	Exports []string `yaml:"exports"`
	Imports []string `yaml:"imports"`
	Scripts Scripts  `yaml:"scripts"`
}

// Scripts - the scripts tag of a container tag, holds the scripts contents (index value of a script is its filename)
type Scripts struct {
	Pre  []string `yaml:"pre"`
	Peri []string `yaml:"peri"`
	Post []string `yaml:"post"`
}

// Image - the image tag of a manifest file, holds information to build an OCI compliant image.
// The containerfile and all files given will all live under the same /tmp dir.
// files can have dirs defined in their filename such as "dirName/fileName" which will resolve into "/tmp/$containerNamebuildXXXXX/dirName/fileName"
type Image struct {
	ContainerFile string            `yaml:"Containerfile"`
	Files         map[string]string `yaml:"files"`
}

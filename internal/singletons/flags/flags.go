package flags

import "sync"

type Flags struct {
	LogLevel         int8
	LogFile          string
	ScriptsTmpDir    string
	ImageBuildTmpDir string
	ManifestFile     string
}

var instance *Flags

func GetInstance() *Flags {
	sync.OnceFunc(func() {
		if instance == nil {
			instance = new(Flags)
		}
	})

	return instance
}

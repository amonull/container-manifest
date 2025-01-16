package flags

type Flags struct {
	LogLevel         int8
	LogFile          string
	ScriptsTmpDir    string
	ImageBuildTmpDir string
}

var instance *Flags

func GetInstance() *Flags {
	if instance == nil {
		instance = new(Flags)
	}

	return instance
}

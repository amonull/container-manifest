package image

type Image struct {
	BuildBaseDir string
	Files        []string // list of file names
}

var instance *Image

func GetInstance() *Image {
	if instance == nil {
		instance = new(Image)
	}

	return instance
}

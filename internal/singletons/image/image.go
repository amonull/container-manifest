package image

type Image struct {
	Containerfile string
	files         map[string]string // key = file name, value = file contents
}

var instance *Image

func GetInstance() *Image {
	if instance == nil {
		instance = new(Image)
	}

	return instance
}

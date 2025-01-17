package image

import "sync"

type Image struct {
	Containerfile string
	files         []map[string]string // key = file name, value = file contents
}

var instance *Image

func GetInstance() *Image {
	sync.OnceFunc(func() {
		if instance == nil {
			instance = new(Image)
		}
	})

	return instance
}

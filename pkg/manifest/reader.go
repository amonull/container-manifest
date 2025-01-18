package manifest

import (
	"github.com/goccy/go-yaml"
)

// ReadAll - reads the full manifest file (given as bytes) and places all values into
// a Manifest structure
func ReadAll(stream []byte) (*Manifest, error) {
	manifest := &Manifest{}

	if err := yaml.Unmarshal(stream, manifest); err != nil {
		return nil, err
	}

	return manifest, nil
}

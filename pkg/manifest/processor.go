package manifest

import (
	"os"
	"path/filepath"
	"strconv"

	"github.com/amonull/container-manifest/pkg/singletons/container"
	"github.com/amonull/container-manifest/pkg/singletons/image"
)

// ApplyManifest - reads a manifest file from given string path and returns any errors it had.
// Sets the values of the container singleton and creates files under scripts for container and files and containerfile
// for image.
// All the created files are created and kept inside /tmp dirs image and script files are kept in separate dirs
func ApplyManifest(manifestPath string) error {
	manifest, err := prepareManifest(manifestPath)
	if err != nil {
		return err
	}

	container.GetInstance().Name = manifest.Container.Name
	container.GetInstance().Home = manifest.Container.Home
	container.GetInstance().Exports = manifest.Container.Exports
	container.GetInstance().Imports = manifest.Container.Imports

	container.GetInstance().ScriptsBasePath, err = prepareScripts(manifest.Container.Scripts)
	if err != nil {
		return err
	}

	image.GetInstance().BuildBaseDir, err = prepareImage(manifest.Image)
	if err != nil {
		return err
	}

	image.GetInstance().Files = make([]string, len(manifest.Image.Files))
	counter := 0
	for fileName, _ := range manifest.Image.Files {
		image.GetInstance().Files[counter] = fileName
	}

	return nil
}

func prepareManifest(manifestPath string) (*Manifest, error) {
	manifestContents, err := os.ReadFile(manifestPath)
	if err != nil {
		return nil, err
	}

	manifest, err := ReadAll(manifestContents)
	if err != nil {
		return nil, err
	}

	return manifest, nil
}

func prepareScripts(scripts Scripts) (string, error) {
	scriptsTmpDir, err := os.MkdirTemp("", container.GetInstance().Name+"_scripts-*")
	if err != nil {
		return "", err
	}

	err = handleGenericScript(filepath.Join(scriptsTmpDir, "pre"), scripts.Pre)
	if err != nil {
		return "", err
	}

	err = handleGenericScript(filepath.Join(scriptsTmpDir, "peri"), scripts.Peri)
	if err != nil {
		return "", err
	}

	err = handleGenericScript(filepath.Join(scriptsTmpDir, "post"), scripts.Post)
	if err != nil {
		return "", err
	}

	return scriptsTmpDir, nil
}

func handleGenericScript(dirPath string, scripts []string) error {
	err := os.MkdirAll(dirPath, 0755)
	if err != nil {
		return err
	}

	err = processListFiles(scripts, dirPath)
	if err != nil {
		return err
	}

	return nil
}

func processListFiles(scripts []string, dirPath string) error {
	for index, element := range scripts {
		filePath := filepath.Join(dirPath, strconv.Itoa(index))
		if err := os.WriteFile(filePath, []byte(element), 0755); err != nil {
			return err
		}
	}

	return nil
}

func prepareImage(image Image) (string, error) {
	tmpImageBuildDir, err := os.MkdirTemp("", container.GetInstance().Name+"_build-*")
	if err != nil {
		return "", err
	}

	err = os.WriteFile(filepath.Join(tmpImageBuildDir, "Containerfile"), []byte(image.ContainerFile), 0644)
	if err != nil {
		return "", err
	}

	for fileName, fileContents := range image.Files {
		fullFilePath := filepath.Join(tmpImageBuildDir, fileName)
		parentDir := filepath.Dir(fullFilePath)

		if _, err := os.Stat(parentDir); os.IsNotExist(err) {
			if err := os.MkdirAll(parentDir, 0755); err != nil {
				return "", err
			}
		}

		if err := os.WriteFile(fullFilePath, []byte(fileContents), 0755); err != nil {
			return "", err
		}
	}

	return tmpImageBuildDir, nil
}

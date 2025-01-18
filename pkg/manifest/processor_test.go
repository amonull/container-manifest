package manifest_test

import (
	"os"
	"path/filepath"
	"testing"

	manifest2 "github.com/amonull/container-manifest/pkg/manifest"
	"github.com/stretchr/testify/assert"
)

var testOutPath = "testOut"

func setup() {
	err := os.RemoveAll(testOutPath)
	if err != nil {
		panic(err)
	}

	err = os.MkdirAll(testOutPath, 0755)
	if err != nil {
		panic(err)
	}
}

func TestProcessListFiles(t *testing.T) {
	setup()
	testDataScripts := []string{
		"script contents 1",
		"script contents 2",
	}
	expectedScriptFilePaths := []string{
		filepath.Join(testOutPath, "0"),
		filepath.Join(testOutPath, "1"),
	}

	err := manifest2.ProcessListFiles(testDataScripts, testOutPath)
	if err != nil {
		t.Error(err)
	}

	assert.FileExistsf(t, expectedScriptFilePaths[0], "expected script file: %s did not get created", expectedScriptFilePaths[0])
	assert.FileExistsf(t, expectedScriptFilePaths[1], "expected script file: %s did not get created", expectedScriptFilePaths[1])

	actualContentsScript0, err := os.ReadFile(expectedScriptFilePaths[0])
	if err != nil {
		t.Error(err)
	}

	assert.Equal(t, string(actualContentsScript0), testDataScripts[0])

	actualContentsScript1, err := os.ReadFile(expectedScriptFilePaths[1])
	if err != nil {
		t.Error(err)
	}
	assert.Equal(t, string(actualContentsScript1), testDataScripts[1])
}

func TestPrepareImage(t *testing.T) {
	setup()

	testData := manifest2.Image{
		ContainerFile: "containerFile values",
		Files: map[string]string{
			"foobar":  "foobar value",
			"foo/bar": "foo/bar value",
		},
	}

	tmpDirPath, err := manifest2.PrepareImage(testData)
	if err != nil {
		t.Error(err)
	}

	assert.FileExistsf(t, filepath.Join(tmpDirPath, "Containerfile"), "expected file: %s", filepath.Join(tmpDirPath, "Containerfile"))

	for fileName, expectedFileValue := range testData.Files {
		fullPath := filepath.Join(tmpDirPath, fileName)

		assert.FileExistsf(t, fullPath, "expected file: %s did not get created", fullPath)

		fileContents, err := os.ReadFile(fullPath)
		if err != nil {
			t.Error(err)
		}

		assert.Equal(t, expectedFileValue, string(fileContents))
	}
}

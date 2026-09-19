package main

import (
	"fmt"
	"runtime"
)

func main() {
	fmt.Println("forgejo-ios pure Go probe")
	fmt.Printf("GO_VERSION=%s\n", runtime.Version())
	fmt.Printf("GOOS=%s\n", runtime.GOOS)
	fmt.Printf("GOARCH=%s\n", runtime.GOARCH)
	fmt.Println("GO_RUNTIME=ok")
}

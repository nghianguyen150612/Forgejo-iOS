package main

/*
#include <stdint.h>

static int forgejo_ios_cgo_value(void) {
	return 42;
}
*/
import "C"

import (
	"fmt"
	"runtime"
)

func main() {
	fmt.Println("forgejo-ios cgo probe")
	fmt.Printf("GOOS=%s\n", runtime.GOOS)
	fmt.Printf("GOARCH=%s\n", runtime.GOARCH)
	fmt.Println("CGO=ok")
	fmt.Printf("C_VALUE=%d\n", int(C.forgejo_ios_cgo_value()))
}

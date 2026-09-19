package main

import (
	"fmt"
	"runtime"
	"runtime/debug"
	"sync"
	"sync/atomic"
	"time"
)

func main() {
	gomaxprocs := runtime.GOMAXPROCS(0)
	fmt.Printf("RUNTIME=%s\n", runtime.Version())
	fmt.Printf("NUM_CPU=%d\n", runtime.NumCPU())
	fmt.Printf("GOMAXPROCS=%d\n", gomaxprocs)

	workers := gomaxprocs * 8
	if workers < 8 {
		workers = 8
	}
	const iterations = 15000
	debug.SetGCPercent(10)

	var started atomic.Int32
	var completed atomic.Int32
	var sink atomic.Uint64
	var mutex sync.Mutex
	start := make(chan struct{})
	var wg sync.WaitGroup
	wg.Add(workers)
	for worker := 0; worker < workers; worker++ {
		worker := worker
		go func() {
			defer wg.Done()
			started.Add(1)
			<-start
			local := uint64(worker + 1)
			for i := 0; i < iterations; i++ {
				buf := make([]byte, 256+(i&255))
				buf[0] = byte(local)
				local += uint64(buf[len(buf)-1]) + uint64(i)
				if i&15 == 0 {
					mutex.Lock()
					sink.Add(local)
					mutex.Unlock()
				}
				if i&63 == 0 {
					runtime.Gosched()
				}
			}
			completed.Add(1)
		}()
	}

	for started.Load() != int32(workers) {
		runtime.Gosched()
	}
	begin := time.Now()
	close(start)
	for completed.Load() != int32(workers) {
		runtime.GC()
		runtime.Gosched()
	}
	wg.Wait()
	fmt.Printf("WORKERS=%d\n", workers)
	fmt.Printf("ITERATIONS_PER_WORKER=%d\n", iterations)
	fmt.Printf("COMPLETED=%d\n", completed.Load())
	fmt.Printf("SINK=%d\n", sink.Load())
	fmt.Printf("ELAPSED_MS=%d\n", time.Since(begin).Milliseconds())
	fmt.Println("RESULT=PASS")
}

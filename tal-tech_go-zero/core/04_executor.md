# 执行器

包 `core/executors` 实现了各种类型的执行器。

| 执行器类型         | 执行器使用场景         |
| ------------------ | ---------------------- |
| PeriodicalExecutor | 每隔一段时间执行一次   |
| BulkExecutor       | 凑够多个执行一次       |
| ChunkExecutor      | 凑够多个字节执行一次   |
| DelayExecutor      | 延迟一段时间后执行     |
| LessExecutor       | 一段时间内最多执行一次 |



### 满足条件周期触发

PeriodicalExecutor 是任务在时间上的聚集，BulkExecutor 是时间+任务数， ChunkExecutor 是 时间+字节数。它们都是任务在一定条件下的触发。

类库在实现时，提出了一个任务容器的接口，来描述触发条件和任务的执行方式：

```go
	type TaskContainer interface {
    // 添加任务，返回是否需要执行任务了
    // 对于 BulkExecutor，就是任务数量到了
		AddTask(task interface{}) bool
    
		// 执行任务
		Execute(tasks interface{})
    
		// 移除所有任务，并返回它们
		RemoveAll() interface{}
	}
```



作为BulkExecutor和ChunkExecutor的基础，PeriodicalExecutor的接口如下：

```go
// 添加一个任务
func (pe *PeriodicalExecutor) Add(task interface{})

// 将所有的任务取出并执行
func (pe *PeriodicalExecutor) Flush() bool

// Wait 会阻塞直到所有的任务都执行完成
func (pe *PeriodicalExecutor) Wait()

// 同步执行（就Executor定位而言，这是个多余的API？）
func (pe *PeriodicalExecutor) Sync(fn func())
```



BulkExecutor和ChunkExecutor 组合了 PeriodicalExecutor，通过复用上面的接口对外提供功能，并且实现了各自的TaskContainer。



### 延迟触发和限流触发

DelayExecutor 的实现为协程执行：定时器后触发

```go
func (de *DelayExecutor) Trigger() {
	de.lock.Lock()
	defer de.lock.Unlock()

  // 只触发一次
	if de.triggered {
		return
	}

	de.triggered = true
	threading.GoSafe(func() { // 开协程
		timer := time.NewTimer(de.delay)
		defer timer.Stop()
    // 等待
		<-timer.C

		de.lock.Lock()
		de.triggered = false
		de.lock.Unlock()
    // 执行
		de.fn()
	})
}
```



LessExecutor 的实现为：判断上次触发时间距离现在是否超过预先设定的时间间隔，如果是就触发

```go
func (le *LessExecutor) DoOrDiscard(execute func()) bool {
	now := timex.Now()
	lastTime := le.lastTime.Load()
	if lastTime == 0 || lastTime+le.threshold < now {
		le.lastTime.Set(now)
		execute()
		return true
	}

	return false
}
```


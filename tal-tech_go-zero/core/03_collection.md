# 集合

包 `github.com/tal-tech/go-zero/core/collection` 实现了各种典型集合类型



### RollingWindow

限流的方案在 [熔断器](./02_break.md) 里面讲过，Rolling Window 就是一个经典的算法。

为了解决计算一段时间Interval的请求次数，滑动窗口算法的做法为：将计算周期切成N个Bucket，每个请求过来后，将请求放入对应的Bucket中，当要计算window有多少个请求时，把相关所有的bucket的数据累计起来即可。

我们先看看数据结构定义：

```
type RollingWindow struct {
	lock          sync.RWMutex
	// 有多少个计数器
	size          int
	// 每个计算器的计数周期
	interval      time.Duration
	
	// 窗口，由多个Bucket组成
	win           *window
	
	// 窗口的偏移，范围为 [0, size)
	offset        int
	// 最后一次更新的时间
	lastTime      time.Duration
	
	ignoreCurrent bool
}
	
type window struct {
	buckets []*Bucket // 一个window有多个Bucket
	size    int
}

type Bucket struct {
	Sum   float64
	Count int64
}
```



我们再看看行为定义：

```
// 添加个数
func (rw *RollingWindow) Add(v float64) 

// 通过这个函数拿到当前的状态
// 会找到多个Bucket，需要总数的话直接累加即可
func (rw *RollingWindow) Reduce(fn func(b *Bucket))
```



其实算法也不是那么的高深，一个滑动窗口由多个bucket组成：

- 每次往窗口里面添加时：清理过期的bucket后找到目标bucket加入
- 每次要看窗口的个数是：找到目标的bucket列表，依次查看其Sum和Count即可



假设需求是一分钟限流60次，创建一个size为6，interval为10s的滑动窗口对象。 

| 时间，行为          | 总数<br/> Count/Sum | 第0个<br/>bucket<br/> Count/Sum | 第1个   | 2     | 3     | 4     | 5       |
| ------------------- | ------------------- | ------------------------------- | ------- | ----- | ----- | ----- | ------- |
| 第8s，新增20个请求  | 20 / 20             | 20 / 20                         | 0 / 0   | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0   |
| 第18s，新增10个请求 | 30 / 30             | 20 / 20                         | 10 / 10 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0   |
| 第58s，新增15个请求 | 45 / 45             | 20 / 20                         | 10 / 10 | 0 / 0 | 0 / 0 | 0 / 0 | 15 / 15 |
| 第78s，新增25个请求 |                     | 0 / 0                           | 25 / 25 | 0 / 0 | 0 / 0 | 0 / 0 | 15 / 15 |



### TimingWheel 

对于延迟执行任务，TimingWheel是一个常用的数据结构。一般而言，时间轮会有一个时间间隔，每多久执行一次。然后往里面加任务，一般任务会有一个delay的属性，表示延时多久执行



![TimingWheel](/Users/liuqing18/Documents/Artist/golang/src/github.com/liuximu/SCA/tal-tech_go-zero/imgs/TimingWheel.png)



每个时间轮会有多个槽点，每个槽点对应的是一个任务列表。每过一个时间间隔，就去执行下一个槽点对应的任务。

我们先看看每个任务的数据结构：

```go
	type timingEntry struct {
		baseEntry
		value   interface{}
    
		circle  int
		diff    int
		removed bool
	}

	type baseEntry struct {
		// 延迟多长时间执行
		delay time.Duration
		// 任务的key
		key   interface{}
	}
```



每个任务包括：

- circle(层)，如果circle==0，那就是当前执行，不然circle--，继续等待机会。
- 在实现细节上，任务还包含diff属性，是移动任务是的偏移量，在被执行时如果diff>0，就需要移动到后面的槽点（这个设计是为了简化移动任务的实现复杂度）



我们看看类库的实现。

时间轮的基本数据结构：

```go
	type TimingWheel struct {
    // 多长时间触发一次
		interval      time.Duration
    // 内置的定时器
		ticker        timex.Ticker
    
    // 槽点的个数
		numSlots      int
    // 个数为numSolts的槽点列表
		slots         []*list.List
    
    // 一个冗余数据，任务的key为key，为了确认同名的任务是否已经存在
		timers        *SafeMap
    
    // 当前的位置
		tickedPos     int
		execute       Execute
		setChannel    chan timingEntry
		moveChannel   chan baseEntry
    
    // 标识任务被删除的chan
		removeChannel chan interface{}
    // 标识任务被放弃执行
		drainChannel  chan func(key, value interface{})
    
    // 标识停止的chan
		stopChannel   chan lang.PlaceholderType
	}
```



时间轮的行为包括：

- 新增一个任务
- 往后移动一个任务
- 删除一个任务
- 清空时间轮
- 停止时间轮

```go
// 添加/更新任务， 同步操作是写入setChannel
// 异步操作是：
//  如果任务存在（timer这个冗余的数据结构），进行更新存在
//  任务不存在，将其加入对应的槽点的任务列表中即可
func (tw *TimingWheel) SetTimer(key, value interface{}, delay time.Duration) 

// 移动任务，往后延迟被执行的时间，同步操作是写入 moveChannel
// 如果delay（后移的时间）小于interval，直接执行
// 不然，将任务移动到适当的position和circle
func (tw *TimingWheel) MoveTimer(key interface{}, delay time.Duration)

// 移除任务，同步操作是写入 removeChannel
// 异步实现是将 timers 中对应的任务直接设置为 removed
func (tw *TimingWheel) RemoveTimer(key interface{}) 

// 放弃执行，同步操作是写入drainChannel
// 异步实现是将solts的每个元素拿出来（是一个列表），依次将每个结点的key和value交个fn执行，然后删除节点
// 执行完成后，slots的每个元素都是空数组
func (tw *TimingWheel) Drain(fn func(key, value interface{})) 

// 停止，同步操作是关闭 stopChannel
// 异步操作是停止 ticker
func (tw *TimingWheel) Stop()
```



最重要的操作 其实是每次 ticker 被触发时的任务处理逻辑：
先得到当前的槽点： (tickedPos + 1) % numSlots，得到一个链表
对链表的每个元素依次处理：

-  如果任务已经被设置为removed，直接移除即可
- 如果circle>0，circle--，退出处理（说明它不再本周期）
- 如果diff大于0，找到合适的位置，加入，把本节点删除（其实是move的后续操作）
- 这时候就是是时候开始执行任务了



时间轮被创建后，异步就开始监听各个chan来执行上面的逻辑了：

```go
func (tw *TimingWheel) run() {
	for {
		select {
    // 任务执行定时器
		case <-tw.ticker.Chan(): 
			tw.onTick()
    // 任务添加/更新
		case task := <-tw.setChannel: 
			tw.setTask(&task)
    // 任务删除
		case key := <-tw.removeChannel:
			tw.removeTask(key)
    // 任务往后移动
		case task := <-tw.moveChannel: 
			tw.moveTask(task)
    // 任务全部清空
		case fn := <-tw.drainChannel: 
			tw.drainAll(fn)
    // 停止
		case <-tw.stopChannel: 
			tw.ticker.Stop()
			return
		}
	}
}
```





### SafeMap

golang 里面的map是非并发安全的，并发读写map会panic。官方库提供了 sync.Map 可以直接使用。

类库提供的 safemap 除了通过加锁解决并发的问题，还解决了一个官方库某些版本才有的[bug](https://github.com/golang/go/issues/20135)。

本身应该能用到的地方不多，但还是简单分析一下思路。



safe map 定义和接口：

```go
type SafeMap struct {
	lock        sync.RWMutex
	deletionOld int
	deletionNew int
	dirtyOld    map[interface{}]interface{}
	dirtyNew    map[interface{}]interface{}
}

func (m *SafeMap) Del(key interface{})
func (m *SafeMap) Get(key interface{}) (interface{}, bool)
func (m *SafeMap) Set(key, value interface{}) 
func (m *SafeMap) Size() int
```



我们简单的看一下Del的实现即可：

```go
func (m *SafeMap) Del(key interface{}) {
	m.lock.Lock()
  
  // 从两个map里面删除元素
	if _, ok := m.dirtyOld[key]; ok {
		delete(m.dirtyOld, key)
		m.deletionOld++
	} else if _, ok := m.dirtyNew[key]; ok {
		delete(m.dirtyNew, key)
		m.deletionNew++
	}
  
  // 其实，如果上面两个ok都是false，可以直接退出了
  
  // 处理 old map，如果 old 的被删除的次数到阈值并且长度小于某个值
	if m.deletionOld >= maxDeletion && len(m.dirtyOld) < copyThreshold {
    // 1 就将old的所有元素放入new
		for k, v := range m.dirtyOld {
			m.dirtyNew[k] = v
		}
    // 2 new 赋值给 old（old整体被释放）
		m.dirtyOld = m.dirtyNew
		m.deletionOld = m.deletionNew
    
    // 3 将new直接初始化
		m.dirtyNew = make(map[interface{}]interface{})
		m.deletionNew = 0
	}
  
  // 对 new 也来一遍同样的操作
	if m.deletionNew >= maxDeletion && len(m.dirtyNew) < copyThreshold {
		for k, v := range m.dirtyNew {
			m.dirtyOld[k] = v
		}
		m.dirtyNew = make(map[interface{}]interface{})
		m.deletionNew = 0
	}
  
	m.lock.Unlock()
}
```



### Set

这个也是很简单。

接口定义：

```
type Set struct {
	data map[interface{}]lang.PlaceholderType // 就是 struct{}
	tp   int
}

func (s *Set) Add{Type}(ss ...string) 
func (s *Set) Contains(i interface{}) bool 
func (s *Set) Keys() []interface{} 
func (s *Set) Remove(i interface{}) 
func (s *Set) Count() int
```



set 支持各种类型，外加类型检查，要是有泛型，事情就会简单很多。

另外，因为是没有锁的map，是并发不安全的。

实现大家通过看数据结构就能猜到了，就不多讲了。



### Ring

类库实现了一个定长环。

接口定义如下：

```go
type Ring struct {
	elements []interface{}
	index    int
}

func (r *Ring) Add(v interface{}) 
func (r *Ring) Take() []interface{} 
```

实现本身没有太多的内容，简单描述：

- 每次添加元素，index都前进一格（可能覆盖旧元素）
- 获取则是从index所在的地方开始，取被设置了的元素。



### Queue

Queue 是典型的 FIFO 数据类型。

接口定义如下：

```go
type Queue struct {
	lock     sync.Mutex
	elements []interface{}
	size     int
	head     int
	tail     int
	count    int
}

func (q *Queue) Empty() bool 
func (q *Queue) Put(element interface{}) 
func (q *Queue) Take() (interface{}, bool) 
```

这个其实也是很常规的一种数据结构，简单描述：

- 进队列：如果满了，就扩容size个元素，然后在 elements上追加元素
- 出队列：如果size为0，直接返回nil；不然就更新head和count，返回元素
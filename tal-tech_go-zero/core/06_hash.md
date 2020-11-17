#  一致性hash

状态：编辑中



包 `github.com/tal-tech/go-zero/core/hash` 实现了一个一致性hash。



### hash 和 一致性hash

hash函数将一个字符串（字节数组）转换为一个数值，比如md5。

在业务开发中，经常会使用hash函数将数据打散到多个存储实例上，比如：

- 数据库水平分表：hash(用户的名字) 后和总表数取模确定存储在哪张表中
- 缓存集群挑选：hask(key) 后和 缓存集群格式取模确定数据缓存在哪个缓存集群中



`realAddr =  hash(key) % node_count` 这种方式，在instance_count 不变的情况下是工作良好的，但是真实的生产环境却是动态的，就会有如下问题：

- 容错性：实例宕机了，某个实例下线后，最坏情况（第一个实例下线）会导致所有的数据都失效，最好情况（最后一个实例下线）是 1/n 的数据失效
- 扩展性：添加新实例同上



一致性hash就是用来解决这个问题的。



普通的算法是将N个物理节点组成一个环，通过和N取模确定到底使用哪个具体的节点，每个节点对应一个物理节点

一致性hash先得到一个有N个虚拟节点的环，我们先认为N = 2^32 - 1。

- 将每个机器节点hash后与N取模能够得到机器在虚拟环的位置P
- 通过Key和N取模确定是哪个虚拟节点n
- 顺着虚拟环顺时针查找到的第一个P就是需要使用的物理节点

我们来分析一下一致性hash的表现：

- 容错性：实例宕机了，某个实例下线后，总是 1/n 的数据失效
- 扩展性：添加新实例，总是少于 1/n的数据受影响



有一个地方需要特别注意一下： **将每个机器节点hash后与N取模能够得到机器在虚拟环的位置P** 这步，如果做得不够均匀，就会导致 数据倾斜，也就是每个物理节点的负载不一样。

比如有N物理节点，它们的P 相减为 2^32 / N 才比较对，极端情况P相差1，那么就有一台物理节点几乎承担所有的负载。

解决这个问题的一种方法为对每个物理节点进行多个hash，每次计算的结果为一个虚拟节点。同一个物理节点的多个虚拟节点都是该物理节点服务的范围。通过多个hash，降低数据倾斜的概率。



### 一致性hash的API

```go
type (
	HashFunc func(data []byte) uint64

	ConsistentHash struct {
    // 将key转换为int的函数
		hashFunc HashFunc
    // 副本的数量，也就是上面虚拟节点的数量
		replicas int
    // 
		keys     []uint64
    // 
		ring     map[uint64][]interface{}
    // 用来确认某个节点是否存在的冗余数据
		nodes    map[string]lang.PlaceholderType
		lock     sync.RWMutex
	}
)


Add(node interface{}) 
AddWithReplicas(node interface{}, replicas int) 
AddWithWeight(node interface{}, weight int)

Get(v interface{}) (interface{}, bool)

Remove(node interface{}) 
```


# 布隆过滤器

包 `github.com/tal-tech/go-zero/core/bloom` 提供了一个布隆过滤器的实现。



### 什么是 布隆过滤器？

布隆过滤器是 burton Bloom 在 1970年提出来的一个 用来处理 元素是否在集合中的 方法。对于海量数据，使用布隆过滤器在判定某个元素是否在其中时具有极高的空间效率和查询效率。它不会漏判，但是可能误判（不在里面的被认为在里面）。



#### 布隆过滤器基本原理

布隆过滤器由一个超大的位数组A和M个hash函数组成，它支持两种操作：

- 添加元素K：
  - 将K依次交给M个函数运算，得到M个下标，将A中下标的值都设置为1
- 查询元素K：
  - 将K依次交给M个函数运算，得到M个下标，如果A中这些下标的值都是1，则代表元素（可能）存在，不然就是（一定）不存在

不支持删除。



#### 布隆过滤器的误差率

有专门的[分析](http://pages.cs.wisc.edu/~cao/papers/summary-cache/node8.html)。



#### 布隆过滤器的应用

- 判断某个邮箱地址在不在上亿个邮箱地址中
- 判断某个URL爬虫是否扒取过
- 判断某个数据在数据库是否存在
- ...



### go-zero布隆过滤器的实现

go-zero 中使用redis来存储位数组，自定义了hash函数。



#### hash 函数

```go
// 根据 key 得到 M 个下标
func (f *BloomFilter) getLocations(data []byte) []uint {
	locations := make([]uint, maps)
  // maps = 14
	for i := uint(0); i < maps; i++ {
    // 每次将 i 追加到数据本身中，使用同一个hash函数得到不同的下标
		hashValue := hash.Hash(append(data, byte(i)))
		locations[i] = uint(hashValue % uint64(f.bits))
	}
	// 会得到一个长度为14的数组，存储者14个下标
	return locations
}
```



#### 位数组

直接使用了redis的 bits相关的功能，执行lua脚本，将 locations 里面的数据存储到redis中。

```lua
// 添加元素的的脚本
	setScript = `
for _, offset in ipairs(ARGV) do
	redis.call("setbit", KEYS[1], offset, 1)
end
`
// 查询元素的脚本
	testScript = `
for _, offset in ipairs(ARGV) do
	if tonumber(redis.call("getbit", KEYS[1], offset)) == 0 then
		return false
	end
end
return true
`
```


# 路由内部实现：基树

##  路由的内部实现

前面我们把route接口层面的调用都过了一遍，gin的代码调用还是很简单直接的。

> 程序 = 数据结构 + 算法

gin的核心结构体叫 `Engine` ，那引擎到底在哪呢？我想就是它的路由实现。接下来我们去一窥究竟。

### 基树
[基树维基百科](https://en.wikipedia.org/wiki/Radix_tree) 详细介绍了基树这种数据结构。它是gin的router的底层数据结构。

![example from wikipedia](https://upload.wikimedia.org/wikipedia/commons/a/ae/Patricia_trie.svg)


### 具体实现

```
node的数据结构：

// tree.go:88
type node struct {
    // 相对路径
    path      string
    // 索引
    indices   string
    // 子节点
    children  []*node
    // 处理者列表
    handlers  HandlersChain
    priority  uint32
    // 结点类型：static, root, param, catchAll
    nType     nodeType
    // 最多的参数个数
    maxParams uint8
    // 是否是通配符(:param_name | *param_name)
    wildChild bool
}
```

#### 基树的构建
构建的过程其实是不断寻找最长前缀的过程。

#### 基树的查找
基数的查找不抠细节的话其实就是从根节点一直 匹配当前节点和匹配孩子节点，直到找到匹配的节点，返回handlers。

代码在： tree.go:365

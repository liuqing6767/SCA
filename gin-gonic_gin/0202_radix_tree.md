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

我们抛开具体的代码，从数据结构变化来看具体实现：

最初的数据时：engine.roots = nil

step1: engine.Use(f1)

step2：添加{method: POST, path: /p1, handler:f2}
```
/p1

node_/p1 = {
    path:"/p1"
    indices:""
    handlers:[f1, f2]
    priority:1
    nType:root
    maxParams:0
    wildChild:false
}
engine.roots = [{
    method: POST,
    root: node_/p1
}]
```

step3：添加{method: POST, path: /p, handler:f3}
```
/p
/p1

node_/p = {
    path:"/p"
    indices:"1"
    handlers:[f1, f3]
    priority:2
    nType:root
    maxParams:0
    wildChild:false
    children: [
        {
            path:"1"
            indices:""
            children:[]
            handlers: [f1, f2]
            priority:1
            nType:static
            maxParams:0
            wildChild:false
        }
    ]
}

engine.roots = [{
    method: POST,
    root: node_/p
}]
```

step4：添加{method: POST, path: /, handler:f4}
```
/
/p
/p1

node_/ = {
    path:"/"
    indices:"p"
    handlers:[f1, f4]
    priority:3
    nType:root
    maxParams:0
    wildChild:false
    children:[
        {
            path:"p"
            indices:"1"
            handlers:[f1, f3]
            priority:2
            nType:static
            maxParams:0
            wildChild:false
            children:[
                {
                    path:"1"
                    indices:""
                    children:[]
                    handlers:[f1, f2]
                    priority:1
                    nType:static
                    maxParams:0
                    wildChild:false
                }
            ]
        }
    ]
}

engine.roots = [{
    method: POST,
    root: node_/
}]
```

step5：添加{method: POST, path: /p1/p34, handler:f5}

```
/
/p
/p1
/p1/p34

node_/ = {
    path:"/"
    indices:"p"
    handlers:[f1, f4]
    priority:4
    nType:root
    maxParams:0
    wildChild:false
    children:[
        {
            path:"p"
            indices:"1"
            handlers:[f1, f3]
            priority:3
            nType:static
            maxParams:0
            wildChild:false
            children:[
                {
                    path:"1"
                    indices:""
                    handlers:[f1, f2]
                    priority:2
                    nType:static
                    maxParams:0
                    wildChild:false
                    children:[
                        {
                            path:"/p34"
                            indices:""
                            handlers:[f1, f5]
                            priority:1
                            nType:static
                            maxParams:0
                            wildChild:false
                            children:[]
                        }
                    ]
                }
            ]
        }
    ]
}

engine.roots = [{
    method: POST,
    root: node_/
}]

```

step6：添加{method: POST, path: /p12, handler:f6}
```
/
/p
/p1
/p1/p34
/p12

node_/ = {
    path:"/"
    indices:"p"
    handlers:[f1, f4]
    priority:5
    nType:root
    maxParams:0
    wildChild:false
    children:[
        {
            path:"p"
            indices:"1"
            handlers:[f1, f3]
            priority:4
            nType:static
            maxParams:0
            wildChild:false
            children:[
                {
                    path:"1"
                    indices:"/2"
                    handlers:[f1, f2]
                    priority:3
                    nType:static
                    maxParams:0
                    wildChild:false
                    children:[
                        {
                            path:"/p34"
                            indices:""
                            handlers:[f1, f5]
                            priority:1
                            nType:static
                            maxParams:0
                            wildChild:false
                            children:[]
                        }
                        {
                            path:"2"
                            indices:""
                            handlers:[f1, f6]
                            priority:1
                            nType:static
                            maxParams:0
                            wildChild:false
                            children:[]
                        }
                    ]
                }
            ]
        }
    ]
}
```

step7：添加{method: POST, path: /p12/p56, handler:f7}
```
/
/p
/p1
/p1/p34
/p12
/p12/p56

node_/ = {
    path:"/"
    indices:"p"
    handlers:[f1, f4]
    priority:5 + 1
    nType:root
    maxParams:0
    wildChild:false
    children:[
        {
            path:"p"
            indices:"1"
            handlers:[f1, f3]
            priority:4 + 1
            nType:static
            maxParams:0
            wildChild:false
            children:[
                {
                    path:"1"
                    indices:"2/"
                    handlers:[f1, f2]
                    priority:3 + 1
                    nType:static
                    maxParams:0
                    wildChild:false
                    children:[
                        {
                            path:"2"
                            indices:""
                            handlers:[f1, f6]
                            priority:2
                            nType:static
                            maxParams:0
                            wildChild:false
                            children:[
                                {
                                    path:"/p56"
                                    indices:""
                                    handlers:[f1, f7]
                                    priority:1
                                    nType:static
                                    maxParams:0
                                    wildChild:false
                                    children:[]
                                }
                            ]
                        }
                        {
                            path:"/p34"
                            indices:""
                            handlers:[f1, f5]
                            priority:1
                            nType:static
                            maxParams:0
                            wildChild:false
                            children:[]
                        }
                    ]
                }
            ]
        }
    ]
}
```

step8：添加{method: POST, path: /p12/p56/:id, handler:f8}
```
/
/p
/p1
/p1/p34
/p12
/p12/p56
/p12/p56/:id

node_/ = {
    path:"/"
    indices:"p"
    handlers:[f1, f4]
    priority:6 + 1
    nType:root
    maxParams:0 + 1
    wildChild:false
    children:[
        {
            path:"p"
            indices:"1"
            handlers:[f1, f3]
            priority:5 + 1
            nType:static
            maxParams:1
            wildChild:false
            children:[
                {
                    path:"1"
                    indices:"2/"
                    handlers:[f1, f2]
                    priority:4 + 1
                    nType:static
                    maxParams:1
                    wildChild:false
                    children:[
                        {
                            path:"2"
                            indices:""
                            handlers:[f1, f6]
                            priority:2 + 1
                            nType:static
                            maxParams:1
                            wildChild:false
                            children:[
                                {
                                    path:"/p56"
                                    indices:""
                                    handlers:[f1, f7]
                                    priority:1 + 1
                                    nType:static
                                    maxParams:1
                                    wildChild:false
                                    children:[
                                        {
                                            path:"/"
                                            indices:""
                                            handlers:[]
                                            priority:1
                                            nType:static
                                            maxParams:1
                                            wildChild:false
                                            children:[
                                                {
                                                    path:":id"
                                                    indices:""
                                                    handlers:[f1, f8]
                                                    priority:1
                                                    nType:param
                                                    maxParams:1
                                                    wildChild:false
                                                    children:[]
                                                }
                                            ]
                                        }
                                    ]
                                }
                            ]
                        }
                        {
                            path:"/p34"
                            indices:""
                            handlers:[f1, f5]
                            priority:1
                            nType:static
                            maxParams:0
                            wildChild:false
                            children:[]
                        }
                    ]
                }
            ]
        }
    ]
}
```

step9：添加{method: POST, path: /p12/p56/:id/p78, handler:f9}
```
/
/p
/p1
/p1/p34
/p12
/p12/p56
/p12/p56/:id

node_/ = {
    path:"/"
    indices:"p"
    handlers:[f1, f4]
    priority:7 + 1
    nType:root
    maxParams:0 + 1
    wildChild:false
    children:[
        {
            path:"p"
            indices:"1"
            handlers:[f1, f3]
            priority:6 + 1
            nType:static
            maxParams:1
            wildChild:false
            children:[
                {
                    path:"1"
                    indices:"2/"
                    handlers:[f1, f2]
                    priority:5 + 1
                    nType:static
                    maxParams:1
                    wildChild:false
                    children:[
                        {
                            path:"2"
                            indices:"/"
                            handlers:[f1, f6]
                            priority:3 + 1
                            nType:static
                            maxParams:1
                            wildChild:false
                            children:[
                                {
                                    path:"/p56"
                                    indices:""
                                    handlers:[f1, f7]
                                    priority:2 + 1
                                    nType:static
                                    maxParams:1
                                    wildChild:false
                                    children:[
                                        {
                                            path:"/"
                                            indices:""
                                            handlers:[]
                                            priority:1 + 1
                                            nType:static
                                            maxParams:1
                                            wildChild:true
                                            children:[
                                                {
                                                    path:":id"
                                                    indices:""
                                                    handlers:[f1, f8]
                                                    priority:1 + 1
                                                    nType:param
                                                    maxParams:1
                                                    wildChild:false
                                                    children:[
                                                        {
                                                            path:"/p78"
                                                            indices:""
                                                            handlers:[f1, f9]
                                                            priority:1
                                                            nType:static
                                                            maxParams:0
                                                            wildChild:false
                                                            children:[]
                                                        }
                                                    ]
                                                }
                                            ]
                                        }
                                    ]
                                }
                            ]
                        }
                        {
                            path:"/p34"
                            indices:""
                            handlers:[f1, f5]
                            priority:1
                            nType:static
                            maxParams:0
                            wildChild:false
                            children:[]
                        }
                    ]
                }
            ]
        }
    ]
}
```

#### 基树的查找
基数的查找不抠细节的话其实就是从根节点一直 匹配当前节点和匹配孩子节点，直到找到匹配的节点，返回handlers。

代码在： tree.go:365

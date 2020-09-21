 路由调用逻辑

gin 对外宣传的高效，很大一部分是说其路由效率。本文内容包括：
- 路由API介绍
- 路由调用实现逻辑
- 路由的内部实现

## 路由API
### 设置路由
```
// routergroup.go:20
type IRoutes interface {
    Use(handlers ...HandlerFunc) IRoutes

    Handle(httpMethod, relativePath string, handlers ...HandlerFunc) IRoutes
    Any(relativePath string, handlers ...HandlerFunc) IRoutes
    GET(relativePath string, handlers ...HandlerFunc) IRoutes
    POST(relativePath string, handlers ...HandlerFunc) IRoutes
    DELETE(relativePath string, handlers ...HandlerFunc) IRoutes
    PATCH(relativePath string, handlers ...HandlerFunc) IRoutes
    PUT(relativePath string, handlers ...HandlerFunc) IRoutes
    OPTIONS(relativePath string, handlers ...HandlerFunc) IRoutes
    HEAD(relativePath string, handlers ...HandlerFunc) IRoutes

    StaticFile(relativePath, filepath string) IRoutes
    Static(relativePath, root string) IRoutes
    StaticFS(relativePath string, fs http.FileSystem) IRoutes
}

// routergroup.go:15
type IRouter interface {
    IRoutes
    Group(string, ...HandlerFunc) *RouterGroup
}
```
 
### RouteGroup的获取
- Engine嵌入了RouteGroup，它本身就实现了IRoutes接口，gin.New() 和 gin.Default() 可以得到Engine对象
- Engine.Group(relativePath string, handlers ...HandlerFunc)可以得到一个新的RouteGroup

### 路由的命中
初始化时将 `gin.go:handleHTTPRequest` 设置为http请求的处理者，它会将请求进行预处理后去处查找命中的处理者（列表），然后去执行。 
这个是调用逻辑，我们讲具体实现。


## 路由的调用逻辑

### 背景知识

我们先看 `Engine` 结构体和路由有关的字段

```
gin.go:50

type Engine struct {
    RouterGroup

    // 如果true，当前路由匹配失败但将路径最后的 / 去掉时匹配成功时自动匹配后者
    // 比如：请求是 /foo/ 但没有命中，而存在 /foo，
    // 对get method请求，客户端会被301重定向到 /foo
    // 对于其他method请求，客户端会被307重定向到 /foo
    RedirectTrailingSlash bool

    // 如果true，在没有处理者被注册来处理当前请求时router将尝试修复当前请求路径
    // 逻辑为：
    // - 移除前面的 ../ 或者 //
    // - 对新的路径进行大小写不敏感的查询
    // 如果找到了处理者，请求会被301或307重定向
    // 比如： /FOO 和 /..//FOO 会被重定向到 /foo
    // RedirectTrailingSlash 参数和这个参数独立
    RedirectFixedPath bool

    // 如果true，当路由没有被命中时，去检查是否有其他method命中
    //  如果命中，响应405 （Method Not Allowed）
    //  如果没有命中，请求将由 NotFound handler 来处理
    HandleMethodNotAllowed bool

    // 如果true， url.RawPath 会被用来查找参数
    UseRawPath bool

    // 如果true， path value 会被保留
    // 如果 UseRawPath是false(默认)，UnescapePathValues为true
    // url.Path会被保留并使用
    UnescapePathValues bool

    allNoRoute       HandlersChain
    allNoMethod      HandlersChain
    noRoute          HandlersChain
    noMethod         HandlersChain

    //每个http method对应一棵树
    trees            methodTrees
}

// gin.go:30
type HandlerFunc func(*Context)
type HandlersChain []HandlerFunc

// routergroup.go:40
type RouterGroup struct {
    // 这个路由会参与处理的函数列表
    Handlers HandlersChain
    basePath string
    // 单例存在
    engine   *Engine
    // 是否是根
    root     bool
}

```

### 添加路由

```
// routergroup.go:70
func (group *RouterGroup) handle(httpMethod, relativePath string, handlers HandlersChain) IRoutes {
    // 将basePath和relativePath加起来得到最终的路径
    absolutePath := group.calculateAbsolutePath(relativePath)
    // 将现有的 Handlers 和 handlers合并起来
    handlers = group.combineHandlers(handlers)
    // 将这个route加入到engine.tree
    group.engine.addRoute(httpMethod, absolutePath, handlers)
    // 返回
    return group.returnObj()
}
```

上面的 `addRoute()` 的实现：

```
func (engine *Engine) addRoute(method, path string, handlers HandlersChain) {
    // 常规检查
    assert1(path[0] == '/', "path must begin with '/'")
    assert1(method != "", "HTTP method can not be empty")
    assert1(len(handlers) > 0, "there must be at least one handler")
    
    debugPrintRoute(method, path, handlers)
    // 维护engine.trees
    root := engine.trees.get(method)
    if root == nil {
    root = new(node)
    engine.trees = append(engine.trees, methodTree{method: method, root: root})
    }

    // 核心，后面一起来讲
    root.addRoute(path, handlers)
}
```

### 查找路由 
我们看看路由查找逻辑：

```
gin.go:340

func (engine *Engine) handleHTTPRequest(c *Context) {
    httpMethod := c.Request.Method
    path := c.Request.URL.Path
    unescape := false
    // 看是否使用 RawPath
    if engine.UseRawPath && len(c.Request.URL.RawPath) > 0 {
        path = c.Request.URL.RawPath
        unescape = engine.UnescapePathValues
    }

    t := engine.trees
    // 根据 http method 得到目标树
    for i, tl := 0, len(t); i < tl; i++ {
        if t[i].method == httpMethod {
            // 目标树找到了，为本次请求路由树的根节点
            root := t[i].root
            // 根据path查找节点
            // 核心，后面来讲
            handlers, params, tsr := root.getValue(path, c.Params, unescape)
            if handlers != nil {
                c.handlers = handlers
                c.Params = params
                c.Next()
                c.writermem.WriteHeaderNow()
                return
            }


            if httpMethod != "CONNECT" && path != "/" {
                // 如果 trailing slash redirect，就重定向出去
                if tsr && engine.RedirectTrailingSlash {
                    redirectTrailingSlash(c)
                    return
                }

                // fix path
                if engine.RedirectFixedPath && redirectFixedPath(c, root, engine.RedirectFixedPath) {
                    return
                }
            }
            // 没找到
            break
        }
    }

    // 如果是因为HTTP method有误，回复这个
    if engine.HandleMethodNotAllowed {
        for _, tree := range engine.trees {
            if tree.method != httpMethod {
                if handlers, _, _ := tree.root.getValue(path, nil, unescape); handlers != nil {
                    c.handlers = engine.allNoMethod
                    serveError(c, 405, default405Body)
                    return
                }
            }
        }
    }

    // 交给 NotRoute （404）
    c.handlers = engine.allNoRoute
    serveError(c, 404, default404Body)
}
```

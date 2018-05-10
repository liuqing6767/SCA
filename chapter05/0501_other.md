# 其他主题

基本上介绍完 `gin` 框架了，一个非常克制的框架，提供了路由、使用 `Context` 来封装数据。 golang的原生库对web开发是较为完善的，所有的框架只能是工具集。

### 中间件
中间件实际上上特殊的 `HandleFuc` 注册在 `Engine.RouterGroup` 上，最终会附加到每个节点的handlerList前，每次处理时依次调用。

`gin` 提供了几个中间件:
- auth: auth.go，完成基本的鉴权
- log: logger.go，完成请求日志输出
- recover: recover.go， 完成崩溃处理

### 错误管理
错误管理是指在业务处理中可以将错误不断的设置到context中，然后可以一次性处理，比如记日志。

```
// context.go:40
type Context struct {
    // 一系列的错误
    Errors errorMsgs
}

Error(err error) *Error // 给本次请求添加个错误。将错误收集然后用中间件统一处理（打日志|入库）是一个比较好的方案
```

### 元数据管理

```
// context.go:40
type Context struct {
    // 在context可以设置的值
    Keys map[string]interface{}
}

Set(key string, value interface{})  //本次请求用户设置各种数据 (Keys 字段)
Get(key string)(value interface{}, existed bool)
MustGet(key string)(value interface{})
GetString(key string) string
GetBool(key string) bool
GetInt(key string) int
GetInt64(key string) int64
GetFloat64(key string) float64
GetTime(key string) time.Time
GetDuration(key string) time.Duration
GetStringSlice(key string) []string
GetStringMap(key string) map[string]interface{}
GetStringMapString(key string) map[string]string
GetStringMapStringSlice(key string) map[string][]string
```

### 路由组
```
import (
    "net/http"

    "github.com/gin-gonic/gin"
)

func main() {
    r := gin.New()

    // 使用日志插件
    r.Use(gin.Logger())

    r.GET("/", func(c *gin.Context) {
        c.String(http.StatusOK, "Hello world")
    })


    // 使用路由组
    authGroup := r.Group("/auth", func(c *gin.Context) {
        token := c.Query("token")
        if token != "123456" {
            c.AbortWithStatusJSON(200, map[string]string{
                "code": "401",
                "msg":  "auth fail",
            })
        }

        c.Next()
    })

    // 注册 /auth/info 处理者
    authGroup.GET("/info", func(c *gin.Context) {
        c.JSON(200, map[string]string{
            "id":   "1234",
            "name": "name",
        })
    })

    r.Run("0.0.0:8910")
}
```

路由组可以将路由分组管理
```
// routergroup.go:15
type IRouter interface {
    IRoutes
    Group(string, ...HandlerFunc) *RouterGroup
}

// routergroup.go:40
type RouterGroup struct {
    Handlers HandlersChain
    basePath string
    engine   *Engine
    root     bool
}

var _ IRouter = &RouterGroup{}

// routergroup.go:55
func (group *RouterGroup) Group(relativePath string, handlers ...HandlerFunc) *RouterGroup {
    return &RouterGroup{
        Handlers: group.combineHandlers(handlers),
        basePath: group.calculateAbsolutePath(relativePath),
        engine:   group.engine,
    }
}
```

其实 `Engine` 就实现了 `IRouter` 接口 就是个 路由组；而路由组是基于路由组产生的。

### 其他
我一直没有搞明白 `content negotiation` (context.go:750)是干嘛用的。

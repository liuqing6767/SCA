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

### 其他
我一直没有搞明白 `content negotiation` (context.go:750)是干嘛用的。

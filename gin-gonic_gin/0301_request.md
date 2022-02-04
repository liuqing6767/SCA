# 请求

其实在[流程](../chaptero1/0101_flow.md) 中就有讲到。

在请求来到服务器后，Context对象会生成用来串流程：
和请求有关的字段包括:

```
// context.go:40
type Context struct {
    // ServeHTTP的第二个参数: request
    Request   *http.Request

    // URL里面的参数，比如：/xx/:id  
    Params   Params
}
```

### 获取restful接口的参数
在路由解析时会初始化 `Params`
提供Get函数：
```
Param(key string) string    
```

### 获取请求数据：
```
// Header
GetHeader(key string) string

// c.Request.Body
GetRawData() ([]byte, error)

// Cookie
Cookie(name string) (string, error)

//从GET参数中拿值，比如 /path?id=john
// 实现原理：调用系统库：*http.Request.URL.Query()
GetQueryArray(key string) ([]string, bool)  
GetQuery(key string)(string, bool)
Query(key string) string
DefaultQuery(key, defaultValue string) string
GetQueryArray(key string) ([]string, bool)
QueryArray(key string) []string

//从POST中拿数据
// 实现原理：调用系统库：*http.Request.PostForm() 和 *http.Request.MultipartForm.Value
GetPostFormArray(key string) ([]string, bool)
PostFormArray(key string) []string 
GetPostForm(key string) (string, bool)
PostForm(key string) string
DefaultPostForm(key, defaultValue string) string

// 文件
// 实现原理：调用系统库：*http.Request.FormFile()
FormFile(name string) (*multipart.FileHeader, error)
MultipartForm() (*multipart.Form, error)
SaveUploadedFile(file *multipart.FileHeader, dst string) error
```

###  数据对象化
```
Bind(obj interface{}) error //根据Content-Type绑定数据
BindJSON(obj interface{}) error
BindQuery(obj interface{}) error

//--- Should ok, else return error
ShouldBindJSON(obj interface{}) error 
ShouldBind(obj interface{}) error
ShouldBindJSON(obj interface{}) error
ShouldBindQuery(obj interface{}) error

//--- Must ok, else SetError
MustBindJSON(obj interface{}) error 
```

我们仔细看看实现逻辑
```
// 首先有一个Binding接口，
//binding/binding.go:27
type Binding interface {
    // 绑定器的名称
    Name() string
    // 进行数据绑定
    Bind(*http.Request, interface{}) error
}

// 然后有一个矩阵得到binding对象
//binding/binding.go:70
method      content-type                binding
-----------------------------------------------
GET         *                           Form
*           application/json            JSON
*           application/xml             XML
*           text/xml                    XML
*           application/x-protobuf      ProtoBuf
*           application/x-msgpack       MsgPack
*           application/msgpack         MsgPack
*           其他                        Form

// 最后还有数据校验，使用的是 `go-playground/validator.v8`
```

### 其他工具方法
```
ClientIP() string
ContentType() string
IsWebsocket() bool
```

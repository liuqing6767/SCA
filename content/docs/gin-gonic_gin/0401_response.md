# 响应

其实在[流程](../chaptero1/0101_flow.md) 中就有讲到。

在请求来到服务器后，Context对象会生成用来串流程：
和请求有关的字段包括:

```
// context.go:40
type Context struct {
    // 用来响应 
    Writer    ResponseWriter
    writermem responseWriter
}

// response_writer.go:20
type ResponseWriter interface {
    http.ResponseWriter //嵌入接口
    http.Hijacker       //嵌入接口
    http.Flusher        //嵌入接口
    http.CloseNotifier  //嵌入接口
    
    // 返回当前请求的 response status code
    Status() int
    
    // 返回写入 http body的字节数
    Size() int
    
    // 写string
    WriteString(string) (int, error)
    
    //是否写出
    Written() bool
    
    // 强制写htp header (状态码 + headers)
    WriteHeaderNow()
}

// response_writer.go:40
// 实现 ResponseWriter 接口
type responseWriter struct {
    http.ResponseWriter
    size   int
    status int
}
```

### 初始化过程

在请求来到服务器时，会从对象池中拿到一个Context对象；
```
// 1 初始化writermem
// gin.go:322
c.writermem.reset(w)

func (w *responseWriter) reset(writer http.ResponseWriter) {
    w.ResponseWriter = writer
    w.size = noWritten
    w.status = defaultStatus
}

// 2 初始化context
// gin.go:324
c.reset()

func (c *Context) reset() {
    c.Writer = &c.writermem
    c.Params = c.Params[0:0]
    c.handlers = nil
    c.index = -1
    c.Keys = nil
    c.Errors = c.Errors[0:0]
    c.Accepted = nil
}
```

### 设置响应码、cookie、header等
```
// 实现原理：设置c.writermen.status
Status(code int)            // 设置response code
// 实现原理： 调用系统函数
Header(key, value string)   // 设置header

// 实现原理： 调用系统函数
SetCookie(name, value string, maxAge int, path, domain string, secure, httpOnly bool)
```

### 设置返回的数据
```
Render(code int, r render.Render)      // 数据渲染
HTML(code int, name string, obj interface{})    //HTML
JSON(code int, obj interface{})                 //JSON
IndentedJSON(code int, obj interface{})
SecureJSON(code int, obj interface{})
JSONP(code int, obj interface{})                //jsonp
XML(code int, obj interface{})                  //XML
YAML(code int, obj interface{})                 //YAML
String(code int, format string, values ...interface{})  //string
Redirect(code int, location string)             // 重定向
Data(code int, contentType string, data []byte) // []byte
File(filepath string)                           // file
SSEvent(name string, message interface{})       // Server-Sent Event
Stream(step func(w io.Writer) bool)             // stream
```

我们仔细看看实现逻辑：
```
// 实现有一个 Render接口
// render/render.go:9
type Render interface {
    Render(http.ResponseWriter) error
    WriteContentType(w http.ResponseWriter)
}

// 自己选择具体的实现，有
- JSON
- IndentedJSON
- SecureJSON
- JsonpJSON
- XML
- String
- Redirect
- Data
- HTML
- HTMLDebug
- HTMLProduction
- YAML
- MsgPack

// 对应实现进行具体操作，完成数据输出
```

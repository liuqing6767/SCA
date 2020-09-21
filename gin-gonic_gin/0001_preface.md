# 源码解析之:gin

[gin](https://github.com/gin-gonic/gin) 是一个用golang实现的HTTPweb框架。

# 特性
[官网上](https://gin-gonic.github.io/gin/)描述，gin的特性包括：
- 快：路由使用`基数树`，低内存，不使用反射；
- 中间件注册：一个请求可以被一系列的中间件和最后的action处理
- 奔溃处理：gin可以捕获panic使应用程序可用
- JSON校验：将请求的数据转换为JSON并校验
- 路由组：更好的组织路由的方式，无限制嵌套而不影响性能
- 错误管理：可以收集所有的错误
- 内建渲染方式：JSON，XML和HTML渲染方式
- 可继承：简单的去创建中间件

# 代码结构

~~~
|-- binding                     将请求的数据对象化并校验
|-- examples                    各种列子
|-- json                        提供了另外一种json实现
|-- render                      响应

|-- gin.go                      gin引擎所在
|-- gin_test.go
|-- routes_test.go
|-- context.go                  上下文，将各种功能聚焦到上下文（装饰器模式）
|-- context_test.go
|-- response_writer.go          响应的数据输出
|-- response_writer_test.go
|-- errors.go                   错误处理
|-- errors_test.go
|-- tree.go                     路由的具体实现
|-- tree_test.go
|-- routergroup.go
|-- routergroup_test.go
|-- auth.go                     一个基本的HTTP鉴权的中间件
|-- auth_test.go
|-- logger.go                   一个日志中间件
|-- logger_test.go
|-- recovery.go                 一个崩溃处理插件
|-- recovery_test.go

|-- mode.go                     应用模式
|-- mode_test.go
|-- utils.go                    杂碎
|-- utils_test.go
~~~

接下来的章节将按照各个模块进行合-分讲解，让优秀不再神秘。分析版本为v1.2。

# 方法检索表

用途：看到一道题，"我应该想起什么"的**最快路径**。按"式子里有什么"检索，比按章节检索快。

## 按"式子的长相"查

| 题干里出现 | 先想 | 详见 |
|---|---|---|
| 分母是 `x^k`，分子是超越函数相减 | **泰勒展开到 k 阶** | `problem-map-limits.md` |
| 0/0，分子分母都是乘积结构 | 等价无穷小替换（只对因子） | `problem-map-limits.md` |
| 0/0 但合理式，含 ln/e^ | 洛必达（但先想泰勒是否更快） | `problem-map-limits.md` |
| `Σ` 且项数随 n 变 | 夹逼，或**定积分定义** | `problem-map-limits.md` |
| 递推数列 `a_{n+1}=f(a_n)` | 单调有界（**先猜后证**） | `problem-map-limits.md` |
| 方程 `F(x,y)=0` 求 y′ | 隐函数求导（y 项乘 y′） | `problem-map-derivatives.md` |
| `x=x(t), y=y(t)` 求二阶导 | 参数方程求导（二阶要除以 x′(t)） | `problem-map-derivatives.md` |
| "存在 ξ 使…" | 中值定理 + **构造辅助函数** | `problem-map-derivatives.md` |
| 证明 `f(x) ≥ g(x)` | 移项求导定单调 | `problem-map-derivatives.md` |
| 乘积 `x·e^x`、`x·ln x`、`x·arctan x` | 分部积分（**反对幂指三**） | `problem-map-integrals.md` |
| 根号 `√(a²−x²)` 型 | 三角代换 | `problem-map-integrals.md` |
| 多项式之比 | 假分式先除法 → 部分分式 | `problem-map-integrals.md` |
| 有瑕点/无穷限 | 反常积分，**先找瑕点** | `problem-map-integrals.md` |
| `∫_{a(x)}^{b(x)} f(t)dt` | 变限积分求导 | `problem-map-integrals.md` |
| `y' + P(x)y = Q(x)` | 一阶线性公式 | `problem-map-ode.md` |
| `y' = φ(y/x)` | 齐次代换 `u=y/x` | `problem-map-ode.md` |
| 二阶常系数 | 特征方程（注意重根乘 x） | `problem-map-ode.md` |
| 非齐次右端 `P_m(x)e^{λx}` | 特解带 `x^k`，k = 重数 | `problem-map-ode.md` |
| `F(x,y,z)=0` 求 ∂z/∂x | `−F_x/F_z`（**别丢负号**） | `problem-map-multivariable.md` |
| 求极值 + 约束条件 | 拉格朗日乘数 | `problem-map-multivariable.md` |
| `∫ e^{x²}dx`、`∫ sin(x²)dx` 积不出 | **二重积分换序** | `problem-map-multivariable.md` |
| 区域是圆/圆环，含 `x²+y²` | 极坐标（**别忘乘 r**） | `problem-map-multivariable.md` |
| 沿闭曲线 `∫P dx+Q dy` | 格林公式（**看方向、查奇点**） | `problem-map-multivariable.md` |
| 问级数收敛 | 先查 `u_n → 0`，再选判别法 | `problem-map-series.md` |
| 含 `n!` 或 `a^n` | 比值判别法 | `problem-map-series.md` |
| 正负交替 | 莱布尼茨（单调 + 趋于 0） | `problem-map-series.md` |
| 幂级数求收敛域 | **端点要单独验** | `problem-map-series.md` |
| 幂级数求和 | 系数含 n → 求导；含 1/n → 积分 | `problem-map-series.md` |
| 周期函数展开 | 傅里叶（**奇偶性省一半计算**） | `problem-map-series.md` |
| 封闭曲面积分 | 高斯（外侧；有奇点不能用） | `problem-map-space.md` |
| 空间闭曲线积分 | 斯托克斯 | `problem-map-space.md` |

## 按"我卡在哪"查

| 症状 | 大概率原因 | 处方 |
|---|---|---|
| 完全不知道从哪下手 | 认不出题型 | 对着上表找触发特征；练交错题 |
| 知道用什么但算不出来 | 计算失误 或 展开阶数不够 | 专练计算 + 限时 |
| 方法能做出来但太慢 | 方法选错（次级） | 对比更优方法，记"更快的路" |
| 每次都在同样的地方错 | 前置概念缺口 | 回概念，别刷题 |
| 会做但考场做不完 | 速度问题 | 限时训练 + 取舍策略（先做会的） |

## 三条最高频的"选错方法"

1. **该用泰勒却用洛必达**（分母有 x^k 时）——三次洛必达换一次展开。
2. **该换序却没换序**（见到积不出的函数还在硬积）。
3. **该用极坐标却用直角坐标**（圆域 + `x²+y²`）。

这三条如果反复出现，单独建一个题型家族记录，集中练。

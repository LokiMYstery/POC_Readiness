# Unrush Readiness POC Spec (Swift, iOS-only)

> 目标读者：iOS 开发、后端（可选）、测试、Code Agent  
> 范围：POC 级别，只做**当下展示**，无历史、无个性化基线、无在线校正、无 App 内行为因子  
> 核心产出：一个可移植到正式 App 的“Readiness”模块，包含数据采集、分数计算、文案拼接、UI 与 Debug 工具

---

## 1. 项目介绍

### 1.1 背景与目标
在“别急”个人页增加一个 Readiness（就绪度）可视化模块，用于展示用户**此刻**的就绪情况或精神状态，并提供可解释的证据拆解。POC 只做展示与可解释性，强调工程可移植性与数据缺失鲁棒性。

### 1.2 POC 定义
- 页面结构固定为
  - 总览卡：圆环分段 + 分数 + 一句解释
  - 三张证据卡：节律与日照、活动与代谢、睡眠与恢复（可下钻详情页）
  - Debug 模式：可手动调节所有输入参数并立即刷新输出
- 不做
  - 历史趋势与周报
  - 个性化基线与偏移学习
  - 在线校正与 App 内行为贡献
  - 音乐动作建议文案（不出现“下沉”“开窗启动”等产品动作词）

---

## 2. 关键概念与模式

### 2.1 两种模式
Readiness 在一天内会切换语义，POC 使用硬规则即可。

- Day Mode：清醒就绪度（默认）
- Night Mode：睡眠就绪度（22:00 之后）

#### 2.1.1 最小可行切换规则
- 22:00–05:59 → Night Mode
- 06:00–21:59 → Day Mode
- 可选增强（不影响 POC 基线）
  - 若 HealthKit 能明确判断“正在睡眠”或“刚醒”，可覆盖硬时间窗

### 2.2 三个证据维度
- 节律与日照（Circadian）
- 活动与代谢（Activity）
- 睡眠与恢复（Recovery）

---

## 3. 数据来源与输入字段

> 设计原则：输入可分级，字段全部 Optional，缺失时 UI 与算法降级但不崩。

### 3.1 全局输入（任何情况下都可得）
来自本地系统与后端可选字段

- `now: Date`
- `timezone: TimeZone`
- `weekday: Int`（1–7）
- `isWeekend: Bool`（Calendar 计算）
- `isHoliday: Bool?`（POC 先留空，后端可填充）
- `holidayName: String?`（可选）
- `mode: ReadinessMode`（Day / Night）

### 3.2 节律与日照（WeatherKit + 本地时间）
#### L0（无定位、无 WeatherKit 也能跑）
- `now`
- `weekday / isWeekend`
- `isHoliday`

#### L1（WeatherKit）
- `location: CLLocationCoordinate2D?`（可为 nil）
- `sunrise: Date?`
- `sunset: Date?`
- `daylightDuration: TimeInterval?`（可由 sunrise/sunset 计算）
- 可选增强
  - `cloudCover: Double?`（0–1）
  - `uvIndex: Double?`
  - `condition: String?`
  - `moonPhase: Double?`（0–1 或枚举，视 API）

缺失策略
- 若定位不可用或 WeatherKit 失败 → 整体降级到 L0

### 3.3 活动与代谢（HealthKit）
#### L0
- 可用性标记
  - `activityAuthStatus: AuthorizationStatus`
  - `activityDataAvailable: Bool`
- 无数据时 UI 显示“未接入活动数据，该项未计入”

#### L1
- `stepsToday: Double?`
- `stepsLast2h: Double?`

#### L2
- `activeEnergyTodayKcal: Double?`
- `activeEnergyLast2hKcal: Double?`
- `exerciseMinutesToday: Double?`
- `standHoursToday: Double?`（可选）

窗口建议
- 今日累计：今日 00:00 到 now
- 过去 2 小时：now-2h 到 now

### 3.4 睡眠与恢复（HealthKit）
#### L0（当前实现状态）
当前代码中，恢复分 `S` 不提供独立 L0 时间因子打分；当 `RecoveryInputs.availability == .unavailable` 时，该因子会被移除权重。
说明：
- Night 模式下“已根据夜间时段估计入睡准备程度”仅用于文案降级，不参与恢复分计算。

#### L1（常见睡眠汇总）
- `sleepDurationLastNightHours: Double?`
- `sleepStart: Date?`
- `sleepEnd: Date?`
- `wakeUpTime: Date?`（可由 sleepEnd 推）

“昨夜”窗口建议
- 查询范围：昨天 18:00 到今天 12:00
- 在该范围内取主要睡眠段的汇总

#### L2（更强恢复信号）
- `sleepStages: SleepStageSummary?`
  - `awakeMinutes`
  - `remMinutes`
  - `coreMinutes`
  - `deepMinutes`
- `restingHeartRate: Double?`
- `hrvSDNN: Double?`
- `respiratoryRate: Double?`（可选）

缺失策略
- 有时长无阶段 → 按 L1 算
- 无 HealthKit 睡眠数据 → Day/Night 都标记为 unavailable（总分由其余可用因子归一化计算）

---

## 4. POC 项目结构（可移植到正式 App）

建议 POC 以“模块化”组织，方便后续直接复制进正式工程。以下为建议目录结构。

```
ReadinessPOC/
  ReadinessPOCApp.swift
  AppShell/
    RootView.swift
    Environment/
      AppConfig.swift
      DebugFlags.swift
  Readiness/
    Domain/
      Models/
        ReadinessMode.swift
        ReadinessScore.swift
        ReadinessFactors.swift
        Availability.swift
      Text/
        ReadinessText.swift
        TextTokens.swift
    Data/
      Sources/
        HealthKit/
          HKAuthorization.swift
          HKQueries.swift
          ActivityProvider.swift
          SleepProvider.swift
        WeatherKit/
          WeatherProvider.swift
        System/
          TimeProvider.swift
          CalendarProvider.swift
      Repository/
        ReadinessRepository.swift
    Engine/
      Scoring/
        WeightScheme.swift
        CircadianScorer.swift
        ActivityScorer.swift
        RecoveryScorer.swift
        ReadinessAggregator.swift
      Smoothing/
        CircadianCurve.swift
        SunlightAdjuster.swift
    UI/
      Overview/
        ReadinessOverviewView.swift
        RingChartView.swift
        FactorCardView.swift
      Details/
        CircadianDetailView.swift
        ActivityDetailView.swift
        RecoveryDetailView.swift
      Debug/
        DebugPanelView.swift
        DebugState.swift
    ViewModel/
      ReadinessViewModel.swift
```

### 4.1 关键分层说明
- Domain
  - 纯数据结构与枚举，无 iOS 依赖
- Data
  - HealthKit、WeatherKit、系统时间、日历等输入来源
  - Repository 聚合为统一的 `ReadinessInputs`
- Engine
  - 评分规则、权重、平滑与日照校准
  - 输出 `ReadinessResult`（内含 `subScores`、`sleepDebtBonus`、`ReadinessTextOutput`）
- UI
  - SwiftUI 页面与组件
- ViewModel
  - Combine/async 绑定 Repository 与 Engine
- Debug
  - DebugState 覆盖真实输入，支持手动调参

---

## 5. 依赖与语言库

### 5.1 系统 Framework
- SwiftUI
- Combine（或 Swift Concurrency）
- HealthKit
- WeatherKit
- CoreLocation

### 5.2 依赖策略
POC 推荐不引入第三方依赖。圆环可以用 SwiftUI Path 绘制，或简化为三个比例条。Debug 控件使用系统组件即可。

---

## 6. 统一输入模型

### 6.1 `ReadinessInputs`（Repository 输出）
建议集中所有输入，便于评分与 Debug 覆盖。

- `global: GlobalContext`
- `circadian: CircadianInputs`
- `activity: ActivityInputs`
- `recovery: RecoveryInputs`

所有字段 Optional，并附带可用性信息。

### 6.2 可用性等级与缺失标记
每一维有一个 `availability: Availability`
- `.unavailable(reason: MissingReason)`
- `.estimated`（当前实现仅用于节律 L0）
- `.measured`（L1 或 L2）

### 6.3 评分输出数据结构（实现同步）
- `ReadinessResult`
  - `mode: ReadinessMode`
  - `overallScore: Double`（0–100，已含 Sleep Debt Bonus）
  - `sleepDebtBonus: Double`（0–8，仅 Night 可能非 0）
  - `sleepDebtBonusReasons: [SleepDebtBonusReason]`
  - `subScores: [SubScore]`（仅包含可用因子，长度 1~3）
  - `text: ReadinessTextOutput`
  - `timestamp: Date`
- `SubScore`
  - `id: FactorKind`（`circadian` / `activity` / `recovery`）
  - `value: Double`（子分 0–100）
  - `normalizedWeight: Double`（缺失归一化后的权重）
  - `contributionPercent: Double`（用于圆环分段）
  - `availability: Availability`

---

## 7. 分数模型与规则

### 7.1 总分结构
总分是三个子分加权平均。缺失时移除并归一化。

- Day Mode
  - `R_base = wS * S + wC * C + wA * A_day`
  - `R = R_base`
- Night Mode
  - `R_base = wA * A_sleep + wC * C_night + wS * S`
  - 附加 Sleep Debt Bonus: `R = clamp(R_base + bonus, 0, 100)` (见 8.4)

缺失处理
- 节律因子在当前实现中始终纳入（至少为 `.estimated`）
- 若活动或恢复为 `.unavailable`，则移除其权重
- 对剩余权重做归一化
- 若只剩一个子分可用，总分等于该子分，同时文案提示“基于 X 估计”

### 7.2 权重建议（POC 默认）
- Day Mode
  - 睡眠恢复 S: 0.55
  - 节律日照 C: 0.30
  - 活动代谢 A: 0.15
- Night Mode
  - 活动负荷 A_sleep: 0.50
  - 夜间节律 C_night: 0.35
  - 睡眠恢复 S: 0.15

权重可以写死在客户端，也可由 AppConfig 下发。

### 7.3 实现级计算流程（伪代码）
```text
input: ReadinessInputs
mode <- inputs.global.mode
scheme <- WeightScheme.scheme(for: mode)

// 1) 子分
C <- CircadianScorer.score(inputs.circadian, inputs.global)
A <- ActivityScorer.score(inputs.activity, mode)
S <- RecoveryScorer.score(inputs.recovery, mode)

// 2) 因子入池
factors <- [(circadian, C, scheme.circadian, availabilityC)]
if activity.isAvailable: add(activity, A, scheme.activity, availabilityA)
if recovery.isAvailable: add(recovery, S, scheme.recovery, availabilityS)

// 3) 权重归一化 + 基础总分
totalW <- sum(f.weight)
nw_i <- f.weight / totalW
R_base <- sum(nw_i * f.score)

// 4) 贡献度
contrib_i <- nw_i * f.score
contributionPercent_i <- contrib_i / sum(contrib_j) * 100

// 5) Night bonus
bonus <- SleepDebtBonus(mode, sleepDuration, stepsToday, activeEnergyToday)
R_final <- clamp(R_base + bonus, 0, 100)
```

---

## 8. 子分计算

### 8.1 睡眠恢复分 S
POC 建议用分档映射，解释友好。

输入优先级
- L1：昨夜总睡眠时长（小时）
- L2：当前实现仅采集展示，不参与恢复分计算

分档示例（可配置）
- `< 6.0h` → 35
- `6.0–7.0h` → 55
- `7.0–8.5h` → 75
- `> 8.5h` → 70（轻微回落，用于避免“过长睡眠必然更好”的误解）

若睡眠数据缺失
- Day Mode：S unavailable
- Night Mode：S 可保留为 unavailable，让 Night 主要由 A 与 C 决定

### 8.2 活动分 A（Day 与 Night 视角不同）

#### 8.2.1 Day Mode 活动分 `A_day`（倒 U 型）
目标
- 适度活动有利于清醒就绪
- 活动过高引入疲惫风险，分数回落

以步数为唯一评分输入（当前实现）
分档示例
- `< 1500` → 45
- `1500–7000` → 70
- `7000–12000` → 65
- `> 12000` → 55

微调（可选）
- 若 `stepsLast2h` 极低 → `A_day - 5`
- 若 `stepsLast2h` 极高 → `A_day - 5`

#### 8.2.2 Night Mode 活动分 `A_sleep`（饱和上限）
目标
- 白天消耗到位更利于入睡 readiness
- 超量活动不继续加分，避免离谱

分档示例
- `< 1500` → 40
- `1500–7000` → 65
- `7000–12000` → 80
- `> 12000` → 80（封顶）

可选增强
- 若 21:00 后仍有高强度活动，可 `A_sleep - 5`（POC 可先不做）

活动数据缺失
- A unavailable，移除权重

### 8.3 节律分 C：采用“时间因子 + 日照校准”（方案 3）

目标
- 不出现整点跳变
- 只用当下数据，不用历史
- 同一时间在不同季节与纬度下可有轻微差异

#### 8.3.1 Step 1：基线节律曲线 `baseCircadian(now, mode)`
使用锚点曲线加平滑插值生成连续值。

建议做法
- 预设锚点表（时间点与基线分数）
- 在相邻锚点之间插值
- 插值使用 smoothstep（S 曲线）让过渡更自然

smoothstep
- `p2 = p*p*(3 - 2*p)`，其中 `p` 为 0–1 的时间比例

##### Day Mode 基线锚点示例
| 时间 | 分数 |
|---|---|
| 06:00 | 55 |
| 09:00 | 75 |
| 11:30 | 70 |
| 14:00 | 60 |
| 17:30 | 70 |
| 20:30 | 60 |
| 22:00 | 50 |
| 24:00 | 45 |

##### Night Mode 基线锚点示例
| 时间 | 分数 |
|---|---|
| 22:00 | 60 |
| 23:30 | 75 |
| 01:30 | 85 |
| 03:00 | 80 |
| 06:00 | 65 |

跨午夜处理
- 将时间映射到分钟
- Night Mode 可将 00:00–06:00 视作 24:00–30:00 以保持单调时间轴

#### 8.3.2 Step 2：日照校准 `sunlightAdjust(base, sunrise, sunset, now)`
如果有 sunrise 或 sunset 任一字段，则进行轻微校准，幅度建议小于 10 分。

建议校准规则（可配置）
- `afterSunriseBoost`
  - 日出后 0–120 分钟：从 0 线性提升到 +5
- `afterSunsetDecay`
  - 日落后 0–180 分钟：从 0 线性下降到 -8
- 日落后更晚时间：保持 -8 封顶

若 sunrise/sunset 都缺失
- 不做校准，仅返回 base
- availability 标记为 estimated

#### 8.3.3 Step 3：节假日轻微修正
- Day Mode 且 `isHoliday == true` 或 `isWeekend == true`
  - `C += 3..6`（建议 +4，封顶 80）
- `isHoliday == nil` 时不修正

### 8.4 Sleep Debt Bonus（仅 Night Mode）
目标：体现“昨夜睡少 → 今晚更容易困”的倾向，贴近直觉与生理机制。
规则：
1. **仅在 Night Mode 生效**：Day Mode 下 bonus = 0。
2. **基础 bonus (由昨夜睡眠时长 T 决定)**：
   - T缺失或 T >= 6.0h → 0
   - 5.0h <= T < 6.0h → +5
   - T < 5.0h → +8
3. **活动打折**：若今日活动极低（步数 < 1500，或步数缺失且估算能量 < 120），bonus 打五折（*0.5），变为保守处理。
4. **注入方式**：仅作为总分的叠加修正（`R_final = clamp(R_base + bonus, 0, 100)`），不改变各因子权重和圆环贡献度的显示。

---

## 9. 贡献度与圆环分段

### 9.1 贡献度定义
用于圆环分段与主因选择。

- `contrib_i = weight_i * subscore_i`
- 对可用项求和后归一化为百分比

### 9.2 主因选择规则
文案主因候选只来自 measured 的因子。
- measured 优先级：L1/L2
- estimated 不作为第一主因，除非只有它可用

---

## 10. 文案生成与语言拼接策略（无 LLM）

### 10.1 总览解释输出为单句
固定结构，避免组合爆炸。

结构
- `【模式 + 分数】，【总体判断】，【主因1】，【主因2或缺失提示】。`
- Night 且有 Sleep Debt Bonus 时追加第二句解释（区分 <5h、5~6h、是否活动打折）。

示例
- Day
  - `清醒就绪度 71，处于可用水平，主要来自睡眠恢复较好，其次是节律窗口偏有利。`
- Night
  - `睡眠就绪度 62，处于可入睡水平，主要来自活动消耗到位，其次是夜间下行窗口已形成。`
  - **有 Sleep Debt Bonus 时** 追加一句（如 T < 5h）：`睡眠就绪度 70，处于可入睡水平，主要来自活动消耗到位。昨夜睡眠明显偏少，困倦概率更高。`
- 缺失
  - `清醒就绪度 58，处于一般水平，主要来自节律窗口一般，睡眠数据未接入。`

连接词策略（与实现一致）
- 两个主因时只使用 `主要...其次...`
- 只有一个主因时使用 `主要...，其余数据未接入`
- 缺失提示短语使用 `TextTokens.missingPhrase`，优先提示第一个缺失因子（活动优先于恢复）

### 10.2 总体判断词表（按分档）
- 0–39：`当前偏低`
- 40–59：`处于一般水平`
- 60–79：Day=`处于可用水平`，Night=`处于可入睡水平`
- 80–100：`处于良好水平`

mode 可定制词表
- Day 可替换为 `处于可启动水平`
- Night 可替换为 `处于可入睡水平`

### 10.3 子卡小解释（类似 Apple 健康）
每张卡输出一行，结构固定
- `【结论标签】，【证据短语】。`

#### 节律与日照卡
- 结论标签（按 C 分档）
  - 高：`节律窗口偏有利`
  - 中：`节律窗口一般`
  - 低：`节律窗口偏不利`
- 证据短语优先级
  - 有 sunrise/sunset：`当前位于日出后与日落前的主要清醒区间。`
  - 无日照数据：`已基于本地时间估计节律位置。`
- 节假日补充（可选）
  - `今天为节假日，压力因子较低。`

#### 活动与代谢卡
- Day 结论标签
  - `活动水平适中` / `活动偏低` / `活动偏高或不足`
- Night 结论标签
  - `活动消耗到位` / `活动消耗偏少` / `活动消耗不足`
- 证据短语
  - `今日已累计 {stepsToday} 步。`
  - 或 `今日活动能量 {kcal} 千卡。`
- 缺失
  - `未接入活动数据，因此该项未计入。`

#### 睡眠与恢复卡
- 结论标签
  - `睡眠恢复较好` / `睡眠恢复一般` / `睡眠恢复不足`
- 证据短语
  - `昨夜睡眠 {hours} 小时。`
  - 有阶段可补充 `深睡占比处于 {高/中/低}。`
- Night 且无数据
  - `已根据夜间时段估计入睡准备程度。`
- Day 且无数据
  - `未接入睡眠数据，因此恢复项未计入。`

---

## 11. UI 结构（POC 级）

### 11.1 总览页（ReadinessOverviewView）
- 顶部标题
  - `就绪度` + mode badge（清醒/睡眠）
  - 更新时间（可选）
  - Debug 入口（仅 Debug 模式显示）
- 总览圆环
  - 三段分色，缺失段为灰
  - 中心分数
  - 总览解释单句
  - 可选图例：各段贡献百分比
- 三张证据卡列表
  - 标题 + 子分
  - 小解释一行
  - 关键字段 tags 2–3 个
- 缺失提示条（可选）
  - `部分健康数据未接入，总分基于可用数据估计`

### 11.2 详情页（每张卡一个）
- 页头标题
- 子分与小解释
- 数据等级标签（L0/L1/L2 或 estimated/measured）
- 证据展示（POC 用字段列表即可）
  - 节律可选极简时间轴
  - 活动可选累计条
  - 睡眠可选汇总块

---

## 12. Debug 模式

### 12.1 开启方式
建议 `#if DEBUG` 或设置页开关。POC 允许直接编译条件。

### 12.2 Debug 能力
Debug 允许手动覆盖所有输入参数，用于验证分数平滑、缺失降级、文案拼接与模式切换。

控件建议
- Global
  - Mode: Auto / Day / Night
  - now: DatePicker
  - isHoliday: nil / true / false
- Circadian
  - WeatherKit: On / Off
  - sunrise / sunset 手动输入
- Activity (HealthKit)
  - stepsToday / stepsLast2h
  - activeEnergyToday
  - exerciseMinutesToday
- Recovery (HealthKit)
  - sleepDuration / sleepStart / sleepEnd
  - restingHR / hrv

输出预览区域
- 总分
- 三子分
- 权重与归一化结果
- 总览解释文案
- 三张卡小解释
- 缺失提示文案
- Sleep Debt Bonus 与原因

---

## 13. 开发工作拆分建议

### 13.1 iOS（POC 必做）
- Readiness 模块与 UI（SwiftUI）
- HealthKit 授权与查询（Activity + Sleep）
- WeatherKit 拉取日出日落（定位权限与降级）
- Repository 聚合输入
- Engine 评分与文案生成
- Debug 工具页

### 13.2 后端（POC 可不做）
- `isHoliday` 与 `holidayName` 下发
- 若无后端，POC 先留空 `isHoliday = nil`

---

## 14. 测试要点（POC）
- 模式切换边界
  - 21:59 → 22:00
  - 05:59 → 06:00
- 缺失组合
  - 仅节律可用
  - 节律 + 活动
  - 节律 + 睡眠
  - 三项都可用
- 平滑验证
  - 任意时间点分数连续，无整点跳变
- 文案一致性
  - 主因排序与圆环贡献一致
  - 缺失提示正确
- 权重归一化
  - 缺失项被移除，剩余权重和为 1

---

## 15. 交付物清单
- 本文档（md）
- POC 工程目录（按第 4 节结构）
- 可运行 App
  - 总览页
  - 三详情页
  - Debug 页
- 关键截图与录屏（可选，用于评审）

---

## 16. 附录：示例输出（无 LLM）
- Day
  - `清醒就绪度 71，处于可用水平，主要来自睡眠恢复较好，其次是节律窗口偏有利。`
- Day 缺睡眠
  - `清醒就绪度 58，处于一般水平，主要来自节律窗口一般，睡眠数据未接入。`
- Night
  - `睡眠就绪度 62，处于可入睡水平，主要来自活动消耗到位，其次是夜间下行窗口已形成。`
- 节律卡
  - `节律窗口偏有利，当前位于日出后与日落前的主要清醒区间。`
- 活动卡
  - `活动水平适中，今日已累计 6124 步。`
- 睡眠卡
  - `睡眠恢复较好，昨夜睡眠 7.8 小时。`

---

## 17. 同步说明（2026-03-06）
本次同步基于当前代码实现，重点结论如下：
- 文档中的分数计算、权重、贡献度、Night Bonus 规则已与 `Engine/Scoring/*` 对齐。
- 文档中的输入结构已与 `Domain/Models/ReadinessFactors.swift`、`Availability.swift` 对齐。
- 文档中的目录结构已与仓库实际文件对齐（移除不存在的 `DebugControls.swift` 与 `ReadinessDetailViewModel.swift`）。
- 睡眠 L0 时间因子已明确为“文案降级”而非“恢复分算法”。

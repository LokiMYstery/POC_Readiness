# Unrush Readiness POC Spec (Swift, iOS-only)

> 目标读者：iOS 开发、测试、产品、Code Agent  
> 范围：POC 级别，只做当下展示，无历史、无个性化基线、无在线校正  
> 核心产出：一个可移植到正式 App 的 Readiness 模块，包含数据采集、分数计算、文案生成、UI 与 Debug 工具

---

## 1. 项目介绍

### 1.1 背景与目标
在“别急”个人页增加一个 Readiness（就绪度）模块，用于展示用户此刻的状态，并给出可解释的归因。POC 重点是当前时刻的状态判断、缺失数据鲁棒性、Debug 可调试性，以及一套可以迁移到正式 App 的工程结构。

### 1.2 POC 定义
- 页面结构固定为
  - 总览主卡：5 档圆点轨道 + 大标题（状态与建议） + 副文案（仅主因解释） + 数字分数
  - 缺失提示：在主卡下以轻提示方式呈现
  - Debug 模式：可手动调节输入参数、立即重算，并展示生效时间、生效模式与子分
- 不做
  - 历史趋势与周报
  - 个性化基线与用户长期偏移学习
  - 在线校正与 App 内行为因子
  - 三张因子详情卡与详情页入口

---

## 2. 关键概念与模式

### 2.1 两种模式
Readiness 在一天内切换两套语义：
- Day Mode：清醒状态与可用能量，分数越高越适合推进
- Night Mode：睡眠需求与入睡准备度，分数越高越该休息

### 2.2 模式切换规则
当前实现使用硬规则：
- `22:00–05:59 -> Night Mode`
- `06:00–21:59 -> Day Mode`

在 Debug 模式下，`nowOverride` 会重新参与 mode 判定；如果显式设置了 `modeOverride`，则以显式模式为准。

### 2.3 三个证据维度
- 节律与日照（Circadian）
- 活动与代谢（Activity）
- 睡眠与恢复（Recovery）

---

## 3. 数据来源与输入字段

### 3.1 全局输入
- `now: Date`
- `timezone: TimeZone`
- `weekday: Int`
- `isWeekend: Bool`
- `isHoliday: Bool?`
- `holidayName: String?`
- `mode: ReadinessMode`

### 3.2 节律与日照
L0 即可运行：
- `now`
- `weekday / isWeekend`
- `isHoliday`

L1 使用 WeatherKit：
- `location: CLLocationCoordinate2D?`
- `sunrise: Date?`
- `sunset: Date?`
- `daylightDuration: TimeInterval?`
- 可选增强：`cloudCover / uvIndex / condition / moonPhase`

缺失策略：
- 若定位不可用或 WeatherKit 失败，则退回 `.estimated`
- 只要 `sunrise` 或 `sunset` 有值，节律就能使用日照校准

### 3.3 活动与代谢
L1：
- `stepsToday: Double?`
- `stepsLast2h: Double?`

L2：
- `activeEnergyTodayKcal: Double?`
- `activeEnergyLast2hKcal: Double?`
- `exerciseMinutesToday: Double?`
- `standHoursToday: Double?`

缺失策略：
- 当前实现中，活动查询按字段逐项容错
- 只要步数、近 2 小时步数、活动能量、运动分钟任一成功返回，就视为活动数据已接入
- 若整体 unavailable，则活动因子从总分中移除并归一化其余权重

### 3.4 睡眠与恢复
L1：
- `sleepDurationLastNightHours: Double?`
- `sleepStart: Date?`
- `sleepEnd: Date?`
- `wakeUpTime: Date?`

L2：
- `sleepStages: SleepStageSummary?`
- `restingHeartRate: Double?`
- `hrvSDNN: Double?`
- `respiratoryRate: Double?`

缺失策略：
- 有睡眠时长时按 L1 计算
- `restingHeartRate` 与 `HRV` 作为轻微微调项
- 若恢复 unavailable，则 recovery 因子从总分中移除并归一化其余权重

---

## 4. 工程结构

```text
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
ReadinessPOCTests/
  ReadinessScoringTests.swift
```

### 4.1 分层说明
- Domain：纯数据结构与枚举
- Data：HealthKit、WeatherKit、系统输入聚合
- Engine：评分、权重、平滑、文案聚合
- UI：SwiftUI 页面与组件
- ViewModel：连接 Repository、DebugState 与 Engine
- Tests：用户场景级 XCTest

---

## 5. 统一输入与输出模型

### 5.1 `ReadinessInputs`
- `global: GlobalContext`
- `circadian: CircadianInputs`
- `activity: ActivityInputs`
- `recovery: RecoveryInputs`

### 5.2 可用性等级
- `.unavailable(reason: MissingReason)`
- `.estimated`
- `.measured`

### 5.3 `ReadinessResult`
- `mode: ReadinessMode`
- `overallScore: Double`
- `band: ReadinessBand`
- `subScores: [SubScore]`
- `text: ReadinessTextOutput`
- `timestamp: Date`

### 5.4 `SubScore`
- `id: FactorKind`
- `value: Double`
- `normalizedWeight: Double`
- `contributionPercent: Double`
- `availability: Availability`

---

## 6. 总分模型与权重

### 6.1 总分结构
总分是三个子分加权平均。若某因子 unavailable，则从分数池中移除，对剩余因子重新归一化。

```text
R = wC * C + wA * A + wS * S
```

### 6.2 当前权重
- Day Mode
  - `circadian = 0.28`
  - `activity = 0.40`
  - `recovery = 0.32`
- Night Mode
  - `circadian = 0.45`
  - `activity = 0.15`
  - `recovery = 0.40`

设计意图：
- 白天让活动更有牵引力，分数在同一天内更容易流动
- 夜间让时间与节律成为主要驱动，恢复仍然重要，活动只保留辅助作用

### 6.3 5 档映射
- `0..<35`: veryLow
- `35..<50`: low
- `50..<65`: medium
- `65..<80`: good
- `80...100`: high

---

## 7. 子分计算

### 7.1 节律分 C
节律分由基线节律曲线和日照校准构成。

#### Day Mode 基线锚点
| 时间 | 分数 |
|---|---:|
| 06:00 | 50 |
| 09:00 | 78 |
| 11:30 | 72 |
| 14:00 | 58 |
| 17:30 | 66 |
| 20:30 | 56 |
| 22:00 | 46 |
| 24:00 | 40 |

#### Night Mode 基线锚点
| 时间 | 分数 |
|---|---:|
| 22:00 | 48 |
| 23:30 | 72 |
| 01:30 | 92 |
| 03:00 | 86 |
| 06:00 | 54 |

实现要点：
- 使用 smoothstep 在相邻锚点之间插值
- Night 模式跨午夜时，将 `00:00–05:59` 映射到 `24:00–29:59` 的连续时间轴
- 日照校准：
  - 日出后 150 分钟内线性提升到 `+6`
  - 日落后 240 分钟内线性下降到 `-10`
- 周末/节假日：Day 模式 `+2`

### 7.2 活动分 A

#### Day Mode
活动分采用“累计进度 + 近 2 小时激活”的连续模型，并按分钟插值目标区间。

动态目标锚点：
- `06:00`：lower `200` / upper `1000` / peak `74` / lowerFloor `58` / upperFloor `68`
- `10:00`：lower `1200` / upper `2800` / peak `80` / lowerFloor `50` / upperFloor `72`
- `14:00`：lower `3200` / upper `6000` / peak `84` / lowerFloor `40` / upperFloor `74`
- `18:00`：lower `5200` / upper `8500` / peak `82` / lowerFloor `38` / upperFloor `72`
- `22:00`：lower `6500` / upper `9500` / peak `76` / lowerFloor `44` / upperFloor `70`

规则：
- 低于 `lower`：平滑升分，低进度时更保守
- 落在区间内：中点附近最高，形成倒 U 型
- 高于 `upper`：软回落，不重惩罚
- `stepsLast2h` 在 `10:00` 后参与微调
- 下午和晚间对“近 2 小时几乎没动”的惩罚更重

#### Night Mode
活动分语义是“今日身体消耗是否到位”。
- 优先使用 `stepsToday`
- 若无步数则回退到 `activeEnergyTodayKcal`
- 使用连续锚点插值
- 接近目标后进入平台，不再因继续堆量而大幅抬分

### 7.3 恢复分 S
恢复分由昨夜睡眠时长主导，`restingHeartRate` 和 `HRV` 只做轻微微调。

#### Day Mode 锚点
- `4.5h -> 28`
- `5.5h -> 40`
- `6.5h -> 56`
- `7.5h -> 74`
- `8.5h -> 82`
- `9.5h -> 74`

#### Night Mode 锚点
- `4.5h -> 90`
- `5.5h -> 80`
- `6.5h -> 65`
- `7.5h -> 48`
- `8.5h -> 32`
- `9.5h -> 24`

微调策略：
- Day 模式总微调上限 `±6`
- Night 模式总微调上限 `±4`
- 没有用户个体化基线时，使用保守固定区间，只做轻微修正

---

## 8. 文案策略

### 8.1 输出结构
`ReadinessAggregator` 输出 `ReadinessTextOutput`：
- `heroTitle`
- `heroSubtitle`
- `summaryLine`
- `missingHint`

### 8.2 当前规则
- `heroTitle`：状态判断 + 建议动作
- `heroSubtitle`：只保留主因解释
- `summaryLine`：当前与 `heroSubtitle` 保持一致
- `missingHint`：仅在缺失活动或恢复时提示

### 8.3 主因选择
- measured 因子优先于 estimated 因子
- 取 `contributionPercent` 更高者作为主因
- 当前不再在主卡上拼接第二段建议文案

### 8.4 文案语气
当前文案库已调整为：
- 更建议性、关怀感更强
- 少讲机制，多讲用户能感受到的状态与动作
- 不再使用“趋势描述”式表达，例如“现在的睡意主要靠节律往下带”

---

## 9. UI 结构

### 9.1 总览页
- 顶部：标题、模式 badge、Debug 入口
- 主卡：
  - 5 档圆点轨道
  - 大标题
  - 副文案（主因解释）
  - 数字分数
- 缺失提示：作为轻提示显示

### 9.2 圆点轨道显示规则
- 左侧至中间大圆使用当前档位颜色
- 右侧保持灰色
- 中间主圆不能是灰色

---

## 10. Debug 模式

### 10.1 覆盖能力
- Global
  - `modeOverride`
  - `nowOverride`
  - `isHolidayOverride`
- Circadian
  - `weatherKitEnabled`
  - `sunriseOverride`
  - `sunsetOverride`
- Activity
  - `activityEnabled`
  - `stepsTodayOverride`
  - `stepsLast2hOverride`
  - `activeEnergyOverride`
  - `exerciseMinutesOverride`
- Recovery
  - `recoveryEnabled`
  - `sleepDurationOverride`
  - `sleepStartOverride`
  - `sleepEndOverride`
  - `restingHROverride`
  - `hrvOverride`

### 10.2 覆盖规则
- `nowOverride` 会更新 `global.now`，并在未显式指定模式时重新计算 `mode`
- 只要活动相关 override 任一存在，则 activity 设为 `.measured`
- 只要恢复相关 override 任一存在，则 recovery 设为 `.measured`
- `activityEnabled = false` 或 `recoveryEnabled = false` 时，对应因子设为 `.unavailable(.notAuthorized)`
- `recalculate()` 只基于当前原始输入 + Debug 覆盖重算，不重新拉数据
- `refresh()` 会重新拉取数据后再叠加 Debug 覆盖

### 10.3 Debug UI 形态
- 时间类：`DatePicker`
- 数值类：`TextField + Stepper`
- 每组支持局部 reset
- 所有输入在 setter 中直接触发 `recalculate()`
- 预览区显示：生效时间、生效模式、总分、档位、子分

---

## 11. 测试

### 11.1 当前已接入
工程已新增 `ReadinessPOCTests` target，并提供基础 XCTest。

### 11.2 已覆盖场景
- 夜间同一用户从 `22:00` 到 `01:30`，时间应明显推高夜间分数
- 早夜睡得好但活动低，分数不能虚高
- 深夜、睡得短且当天消耗足够，分数应明显更高
- 早晨温和起步，分数不应低得像异常
- 下午恢复差且活动低，分数应明显掉下去
- Debug 覆盖可以切换生效模式，并将 activity/recovery 正确切为 `.measured`

### 11.3 后续建议补充
- 高活动但睡很差
- 睡得很好但整天久坐
- 只缺 activity
- 只缺 recovery

---

## 12. 交付物
- POC 工程
- 当前规格文档
- README
- Debug 面板
- XCTest 场景测试

---

## 13. 当前同步说明
本次文档同步以当前代码实现为准：
- 总分已调整为更连续、更容易流动的模型
- 白天活动权重提升，夜间时间因子权重更高
- 活动、恢复、节律全部采用连续曲线或连续插值，不再依赖粗硬分档
- 主卡副文案只保留主因解释
- 文案库已改成更偏建议性、关怀感的表达
- Debug 覆盖支持输入即重算，并会正确影响 mode 和 availability
- 工程已包含 XCTest 场景测试

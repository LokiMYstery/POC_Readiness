# Readiness POC

一个运行在 iOS 上的 Readiness 概念验证项目。它读取本地 HealthKit 和 WeatherKit 数据，结合当前时间，实时计算用户此刻的清醒就绪度或夜间入睡准备度，并通过单主卡 UI 和 Debug 面板进行展示。

## 当前产品定义
- 白天：分数越高，越适合推进事情
- 夜间：分数越高，越该休息和收尾
- 只做当下展示，不做历史趋势、个体化基线和在线校正

## 核心能力

### 1. Day / Night 双模式
- `06:00-21:59` 为 Day Mode
- `22:00-05:59` 为 Night Mode
- Debug 模式下可直接覆盖时间或模式，验证切换行为

### 2. 三因子连续评分
- **节律与日照**
  - 基于时间锚点曲线 + 日出日落校准
  - 夜间时间影响更强，是主要驱动之一
- **活动与代谢**
  - 白天采用按分钟插值的动态目标曲线
  - 同时考虑累计活动与近 2 小时激活状态
  - 夜间以“今日消耗是否到位”为辅助因子，达到目标后接近平台
- **睡眠与恢复**
  - 基于昨夜睡眠时长的连续锚点插值
  - `restingHR` 和 `HRV` 只做轻微微调

### 3. 更容易流动的总分
- 白天权重：`节律 0.28 / 活动 0.40 / 恢复 0.32`
- 夜间权重：`节律 0.45 / 活动 0.15 / 恢复 0.40`
- 缺失因子会被移除，并对剩余权重重新归一化

### 4. 单主卡 UI
- 5 档圆点轨道
- 大标题显示【状态 + 建议动作】
- 副文案只显示【主因解释】
- 左侧到中间主圆统一使用当前档位颜色，右侧灰色

### 5. Debug 面板
- 支持覆盖时间、日出日落、步数、活动能量、运动分钟、睡眠时长、静息心率、HRV
- 所有输入修改后立即重算
- 可查看生效时间、生效模式、总分、档位和各因子子分

### 6. XCTest 场景验证
工程已接入测试 target，覆盖以下场景：
- 夜间时间推进是否明显抬高睡意分数
- 早夜低活动是否仍保持较低分
- 深夜短睡 + 合理消耗是否足够高
- 白天早晨温和起步是否合理
- 白天下午低恢复 + 低活动是否能明显掉分
- Debug 覆盖是否真的影响 mode 与 availability

## 目录
- 规格说明：[Readiness_POC_Spec.md](./Readiness_POC_Spec.md)
- 计划记录：[PLAN_Readiness.md](./PLAN_Readiness.md)

## 本地验证
构建：

```bash
xcodebuild -project ReadinessPOC.xcodeproj -scheme ReadinessPOC -sdk iphonesimulator -derivedDataPath /tmp/ReadinessPOC-DerivedData build
```

测试：

```bash
xcodebuild test -project ReadinessPOC.xcodeproj -scheme ReadinessPOC -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/ReadinessPOC-DerivedData
```

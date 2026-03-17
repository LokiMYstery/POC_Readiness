# Readiness 文案 JSON 接入说明

## 用途与运行时路径
- 仓库内默认资源：
  - `ReadinessPOC/Resources/ReadinessCopy.default.json`
  - `ReadinessPOC/Resources/ReadinessCopy.schema.json`
- 运行时实际读取路径：
  - `Application Support/Readiness/readiness-copy.json`
- 首次启动时，如果沙盒文件不存在，应用会将 bundle 内的 `ReadinessCopy.default.json` 复制到上述路径。

## 首启复制与覆盖规则
- `ReadinessPOCApp` 启动时会调用 `ReadinessTextResolver.shared.bootstrap()`。
- `ReadinessCopyStore.ensurePrepared()` 负责创建 `Application Support/Readiness` 目录，并在缺文件时复制默认 JSON。
- 只在沙盒文件不存在时复制默认文件；一旦沙盒文件存在，后续读取始终优先使用沙盒副本。
- 修改沙盒文件后，需要调用 `ReadinessTextResolver.reload()` 才会刷新内存缓存。

## Schema 顶层结构
```json
{
  "title": {
    "day": {
      "veryLow": { "status": "...", "action": "..." }
    }
  },
  "reasons": {
    "day": {
      "circadian": {
        "valueSource": "score",
        "ranges": [
          { "minInclusive": 0, "maxExclusive": 58, "text": "..." }
        ]
      }
    }
  },
  "missingLabels": {
    "day": {
      "circadian": "节律",
      "activity": "活动",
      "recovery": "恢复"
    }
  },
  "messages": {
    "insufficientData": {
      "heroSubtitle": "...",
      "summaryLine": "..."
    },
    "allHealthDataMissing": "...",
    "partialDataMissingTemplate": "部分数据未接入: {{labels}}，当前结果基于可用信息估计。"
  }
}
```

## Key 到 Swift 消费点映射
- `title.day|night.<band>.status/action`
  - 由 [TextTokens.swift](/Users/rickluo/Downloads/POC_Readiness/ReadinessPOC/Readiness/Domain/Text/TextTokens.swift) 中的 `ReadinessTextResolver.resolve(...)` 读取。
  - 输出到 `ReadinessTextOutput.heroTitle`，格式为 `"status, action"`。
- `reasons.day|night.<factor>.valueSource/ranges`
  - 由 `ReadinessTextResolver.metricValue(...)` 和 `resolveReasonText(...)` 消费。
  - `valueSource = score` 时使用主因子子分。
  - `valueSource = sleepDurationLastNightHours` 时使用 `inputs.recovery.sleepDurationLastNightHours`。
- `missingLabels.day|night.<factor>`
  - 由 `ReadinessTextResolver.missingHint(...)` 消费，用于拼接缺失因子标签。
- `messages.insufficientData.heroSubtitle/summaryLine`
  - 在没有主因子时输出到 `ReadinessTextOutput.heroSubtitle` 和 `summaryLine`。
- `messages.allHealthDataMissing`
  - 在 `ReadinessAggregator` 的全缺失分支中作为 `missingHint` 使用。
- `messages.partialDataMissingTemplate`
  - 用 `{{labels}}` 占位符替换缺失因子列表。

## 枚举取值约束
- `mode` 固定为 `day`、`night`
- `band` 固定为 `veryLow`、`low`、`medium`、`good`、`high`
- `factor` 固定为 `circadian`、`activity`、`recovery`
- `valueSource` 固定为：
  - `score`
  - `sleepDurationLastNightHours`

## Range 规则
- 每个 `ranges` 数组必须按 `minInclusive` 升序排列。
- 第一个区间必须从 `0` 或更小开始。
- 相邻区间必须连续，不能重叠、不能留空洞。
- 只有最后一个区间可以省略 `maxExclusive`。
- 当前实现中，`circadian` / `activity` 默认按 score 取值，`recovery` 允许按昨夜睡眠小时数取值。

## 严格失败条件
- bundle 中缺少默认 JSON
- 无法创建 `Application Support/Readiness`
- 默认 JSON 复制失败
- 沙盒 JSON 读取失败
- JSON 解码失败
- range 配置不连续、重叠、未覆盖、顺序错误
- 非 `recovery` 因子使用了非 `score` 的 `valueSource`
- 运行时找不到匹配当前值的 range

## 本地修改后如何验证
1. 修改 `ReadinessPOC/Resources/ReadinessCopy.default.json`。
2. 重新安装或删除沙盒中的 `Application Support/Readiness/readiness-copy.json`，让首启复制新默认文件。
3. 运行测试：
   ```bash
   xcodebuild test -project ReadinessPOC.xcodeproj -scheme ReadinessPOC -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/ReadinessPOC-DerivedData
   ```
4. 如只想验证沙盒覆盖逻辑，可直接编辑 `Application Support/Readiness/readiness-copy.json`，然后触发 `ReadinessTextResolver.reload()`。

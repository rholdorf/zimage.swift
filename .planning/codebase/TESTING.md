# Testing Patterns

**Analysis Date:** 2025-05-05

## Test Framework

**Runner:**
- XCTest framework (Swift standard)
- Run via xcodebuild with `-scheme zimage.swift` or specific test target
- Supports parallel testing (default) or sequential with `-parallel-testing-enabled NO`

**Assertion Library:**
- XCTest standard assertions: `XCTAssertEqual()`, `XCTAssertTrue()`, `XCTAssertGreaterThan()`, `XCTAssertLessThan()`, `XCTAssertThrowsError()`
- Accuracy parameter for float comparisons: `XCTAssertEqual(value, 0.0, accuracy: 1e-6)`
- Error message parameter: `XCTAssertEqual(result, expected, "Failed for input: \(input)")`

**Run Commands:**
```bash
# Run all tests
xcodebuild test -scheme zimage.swift -destination 'platform=macOS' -enableCodeCoverage NO

# Run specific test target (unit tests only)
xcodebuild test -scheme zimage.swift -destination 'platform=macOS' -enableCodeCoverage NO -only-testing:ZImageTests

# Run a single test class
xcodebuild test -scheme zimage.swift -destination 'platform=macOS' -enableCodeCoverage NO -only-testing:ZImageTests/FlowMatchSchedulerTests

# Run a single test method
xcodebuild test -scheme zimage.swift -destination 'platform=macOS' -enableCodeCoverage NO -only-testing:ZImageTests/FlowMatchSchedulerTests/testTimestepsDecreasing

# Integration tests (requires model weights, not parallel)
xcodebuild test -scheme zimage.swift -destination 'platform=macOS' -only-testing:ZImageIntegrationTests/PipelineIntegrationTests -parallel-testing-enabled NO

# Build release CLI
xcodebuild -scheme ZImageCLI -configuration Release -destination 'platform=macOS' -derivedDataPath .build/xcode
```

## Test File Organization

**Location:**
- Unit tests: `Tests/ZImageTests/` (co-located with functionality)
- Integration tests: `Tests/ZImageIntegrationTests/` (requires weights and GPU)
- E2E tests: `Tests/ZImageE2ETests/` (CLI testing)

**Structure by category:**
```
Tests/ZImageTests/
├── Config/
│   └── ModelConfigsTests.swift
├── Scheduler/
│   └── FlowMatchSchedulerTests.swift
├── Weights/
│   ├── SafeTensorsReaderTests.swift
│   └── LoRALoaderTests.swift
├── ImageIO/
│   └── ImageIOTests.swift
├── Quantization/
│   └── QuantizationTests.swift
└── LLMGeneration/
    └── PromptEnhancementTests.swift

Tests/ZImageIntegrationTests/
├── PipelineIntegrationTests.swift
├── ControlNetIntegrationTests.swift
├── LoRAIntegrationTests.swift
└── PerformanceTests.swift
```

**Naming:**
- Test file: `[Component]Tests.swift` (e.g., `FlowMatchSchedulerTests.swift`)
- Test class: `final class [Component]Tests: XCTestCase`
- Test method: `func test[Scenario]()` (e.g., `testTimestepsDecreasing()`)

## Test Structure

**Suite Organization:**
```swift
final class FlowMatchSchedulerTests: XCTestCase {

  // MARK: - Initialization Tests

  func testSchedulerInitializationWithDefaults() {
    let config = Self.makeConfig()
    let scheduler = FlowMatchEulerScheduler(numInferenceSteps: 9, config: config)
    
    XCTAssertEqual(scheduler.numInferenceSteps, 9)
    XCTAssertEqual(scheduler.timesteps.dim(0), 9)
  }

  // MARK: - Timestep Generation Tests

  func testTimestepGeneration() {
    let config = Self.makeConfig()
    let scheduler = FlowMatchEulerScheduler(numInferenceSteps: 9, config: config)
    let timesteps = scheduler.timesteps.asArray(Float.self)
    
    XCTAssertGreaterThan(timesteps[0], 900)
  }
}
```

**Patterns:**
- Tests organized by functionality with `// MARK:` section comments
- Test methods are independent (no shared state between tests)
- Helper methods extracted to extensions on test class: `extension FlowMatchSchedulerTests { static func makeConfig(...) }`
- Setup/teardown at class level:
  ```swift
  override class func setUp() {
    super.setUp()
    // Initialize shared resources
  }
  
  override class func tearDown() {
    // Clean up resources
    super.tearDown()
  }
  ```

## Mocking

**Framework:**
- No external mocking library detected
- Manual mocking via test doubles and stubs
- Factory methods for test data creation

**Patterns:**
```swift
// Factory method for creating test fixtures
extension FlowMatchSchedulerTests {
  static func makeConfig(
    numTrainTimesteps: Int = 1000,
    shift: Float = 1.0,
    useDynamicShifting: Bool = false
  ) -> ZImageSchedulerConfig {
    var json: [String: Any] = [
      "num_train_timesteps": numTrainTimesteps,
      "shift": shift,
      "use_dynamic_shifting": useDynamicShifting
    ]
    let data = try! JSONSerialization.data(withJSONObject: json)
    return try! JSONDecoder().decode(ZImageSchedulerConfig.self, from: data)
  }
}
```

**What to Mock:**
- Config objects created via factory methods
- Test data arrays created with explicit values for reproducibility
- File system operations stubbed with temp URLs

**What NOT to Mock:**
- Core algorithm implementations (test real behavior)
- MLX array operations (let MLX handle computation)
- Struct/enum implementations (too simple to mock)

## Fixtures and Factories

**Test Data:**
```swift
// Factory pattern for creating test MLXArrays
let sampleValues: [Float] = [1.0, 2.0, 3.0, 4.0]
let sample = MLXArray(sampleValues, [1, 1, 2, 2]).asType(.bfloat16)

// Config factories with defaults
static func makeConfig(...) -> ZImageSchedulerConfig { ... }

// CGImage creation helpers
func createTestCGImage(width: Int, height: Int) throws -> CGImage { ... }
```

**Location:**
- Inline in test files for small fixtures
- Extension blocks at end of test class for larger helpers
- Shared resources in integration test base classes

## Coverage

**Requirements:**
- No mandatory coverage target detected (no `enableCodeCoverage` requirement in tests)
- Tests run with `-enableCodeCoverage NO` to avoid creating `default.profraw` files

**View Coverage:**
```bash
# Coverage info can be viewed from xcodebuild reports but not required
# Tests designed to verify behavior, not maximize coverage metrics
```

## Test Types

**Unit Tests** (`Tests/ZImageTests/`):
- Scope: Individual components in isolation
- Config parsing, scheduler calculations, weight mapping, image I/O
- Fast execution (< 1 second each)
- Example: `testSchedulerInitializationWithDefaults()`, `testTimestepGeneration()`
- Dependencies: MLX arrays, JSON parsing, file I/O

**Integration Tests** (`Tests/ZImageIntegrationTests/`):
- Scope: Multi-component interactions with model weights
- Pipeline generation end-to-end, ControlNet conditioning, LoRA application
- Requires: Model weights (~7.5GB), GPU, network access for model download
- Slow execution (minutes per test)
- Skip in CI with: `if ProcessInfo.processInfo.environment["CI"] == nil { ... }`
- Shared pipeline instance to avoid reloading model: `static var sharedPipeline: ZImagePipeline?`
- Example: `testBasicGeneration()`, `testDeterministicSeed()`

**E2E Tests** (`Tests/ZImageE2ETests/`):
- Scope: CLI tool functionality
- Command-line argument parsing, output generation
- Not detailed in exploration but follows CLI integration testing pattern

## Common Patterns

**Async Testing:**
```swift
func testBasicGeneration() async throws {
  try skipIfNoGPU()
  let pipeline = try getPipeline()
  
  let request = ZImageGenerationRequest(
    prompt: "a red apple on a white background",
    width: 512,
    height: 512,
    steps: 9,
    outputPath: tempOutput
  )
  
  let outputURL = try await pipeline.generate(request)
  
  XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
}
```

**Error Testing:**
```swift
func testLoRAErrorFileNotFound() {
  let error = LoRAError.fileNotFound("/nonexistent/path")
  XCTAssertNotNil(error.errorDescription)
  XCTAssertTrue(error.errorDescription!.contains("/nonexistent/path"))
}

func testInvalidTransformerConfig() {
  let json = """
  {
    "invalid_field": 123
  }
  """
  let data = json.data(using: .utf8)!
  XCTAssertThrowsError(try JSONDecoder().decode(ZImageTransformerConfig.self, from: data))
}
```

**Float/Array Testing with MLX:**
```swift
// Explicit Float arrays to avoid float64
let sampleValues: [Float] = [1.0, 2.0, 3.0, 4.0]
let sample = MLXArray(sampleValues, [1, 1, 2, 2]).asType(.bfloat16)

// Evaluation before extracting values
let resultF32 = result.asType(.float32)
MLX.eval(resultF32)
let resultData = resultF32.asArray(Float.self)

// Comparison with tolerance
for i in 0..<resultData.count {
  if abs(resultData[i] - expected[i]) > 1e-6 {
    allSame = false
    break
  }
}
```

**Skip Tests in Certain Conditions:**
```swift
private func getPipeline() throws -> ZImagePipeline {
  guard let pipeline = Self.sharedPipeline else {
    throw XCTSkip("Pipeline not available (likely CI environment)")
  }
  return pipeline
}

func testBasicGeneration() async throws {
  try skipIfNoGPU()  // Custom helper to check device availability
  let pipeline = try getPipeline()
  ...
}
```

**Parametrized Testing:**
```swift
func testVAEConfigScaleFactorVariousBlockCounts() {
  struct TestCase {
    let blockOutChannels: [Int]
    let expectedScale: Int
  }
  
  let testCases = [
    TestCase(blockOutChannels: [128], expectedScale: 1),
    TestCase(blockOutChannels: [128, 256], expectedScale: 2),
    TestCase(blockOutChannels: [128, 256, 512], expectedScale: 4)
  ]
  
  for testCase in testCases {
    // Test logic
    XCTAssertEqual(config.vaeScaleFactor, testCase.expectedScale)
  }
}
```

## Test Coverage by Component

**Pipeline** (`ZImagePipeline.swift`):
- Unit: Config loading, state management
- Integration: Full generation pipeline, LoRA application, prompt enhancement

**Scheduler** (`FlowMatchScheduler.swift`):
- Tests: `FlowMatchSchedulerTests.swift`
- Coverage: Initialization, timestep generation, sigma calculation, dynamic shifting, scheduler steps, edge cases

**Config** (`ModelConfigs.swift`):
- Tests: `ModelConfigsTests.swift`
- Coverage: JSON decoding for all config types, precision handling, invalid config handling

**Weights** (`LoRALoader.swift`, `SafeTensorsReader.swift`):
- Tests: `LoRALoaderTests.swift`, `SafeTensorsReaderTests.swift`
- Coverage: Key mapping, prefix removal, validation

**Image I/O** (`ImageIO.swift`):
- Tests: `ImageIOTests.swift`
- Coverage: Array/image conversion, batch dimensions, data types, resizing with Lanczos

**Prompt Enhancement** (`PromptEnhancement.swift`):
- Tests: `PromptEnhancementTests.swift`
- Coverage: Config defaults, sampling functions, repetition penalty

---

*Testing analysis: 2025-05-05*

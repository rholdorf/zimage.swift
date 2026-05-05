# Coding Conventions

**Analysis Date:** 2025-05-05

## Naming Patterns

**Files:**
- PascalCase for class/struct definitions: `ZImagePipeline.swift`, `FlowMatchScheduler.swift`, `AutoencoderKL.swift`
- Descriptive names with component role: `ZImageTransformer2D.swift`, `ZImageTextEncoderConfig.swift`
- Utility/enum files: `ImageIO.swift`, `ModelConfigs.swift`, `PipelineUtilities.swift`
- Test files: Test subject name + "Tests": `FlowMatchSchedulerTests.swift`, `ModelConfigsTests.swift`, `LoRALoaderTests.swift`

**Functions:**
- camelCase for all function and method names
- Verb-first for actions: `generate()`, `loadModel()`, `encodePrompt()`, `step()`, `loadCapEmbedderWeights()`
- Property accessors with `get` prefix or no prefix for getters: `isLoaded`, `isModelLoaded`
- Utility functions as static or class methods: `QwenImageIO.resizedCGImage()`, `LoRAKeyMapper.mapToZImageKey()`

**Variables:**
- camelCase for all local variables and properties
- Descriptive names: `numInferenceSteps`, `guidanceScale`, `maxSequenceLength`, `timestepIndex`
- Short names for loop variables: `i`, `x`, `y`, `c` (channel)
- Trailing abbreviations for common patterns: `tEmbedder`, `xEmbedder`, `capEmbedNorm`, `vae`
- Suffixes for specific types: `...Path` for URLs/Paths, `...Error` for errors, `...Config` for configurations

**Types:**
- PascalCase for all struct, class, enum, and protocol names
- Domain prefixes for model components: `ZImage*` for transformer/scheduler/pipeline classes
- Qwen prefix for text encoder/tokenizer components: `QwenTextEncoder`, `QwenTokenizer`, `QwenImageIO`
- Error enums: `PipelineError`, `QwenImageIOError`, `SafeTensorsReaderError`, `LoRAError`, `ModelResolutionError`
- Config structs: `ZImageTransformerConfig`, `ZImageVAEConfig`, `ZImageSchedulerConfig`, `ZImageTextEncoderConfig`

## Code Style

**Formatting:**
- 2-space indentation (observed in all files)
- Braces on same line: `func test() {`
- One statement per line
- No trailing semicolons
- Line length appears flexible, code is readable

**Linting:**
- No `.swiftformat`, `.swiftlint`, or `biome.json` files detected
- No automated formatting tool configured

**Documentation:**
- No top-of-file module comments observed
- Sparse inline comments except in test files
- Test methods include doc comments describing test purpose: `/// Unit tests for prompt enhancement components`

## Import Organization

**Order:**
1. Foundation and system frameworks
2. Platform-specific frameworks (MLX, MLXNN, MLXRandom, Logging, Dispatch, Hub, Tokenizers)
3. Third-party library imports
4. Conditional imports for platform features

**Examples from codebase:**
```swift
import Foundation
import Logging
import MLX
import MLXNN
import MLXRandom
import Tokenizers
import Hub
import Dispatch

#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif

@testable import ZImage  // In test files
```

**Path Aliases:**
- No path aliases detected (no `@` prefix in imports)
- Full module paths used: `ZImage.PipelineError`, `ZImage.LoRAConfiguration`

## Error Handling

**Patterns:**
- Typed error enums with `Error` conformance: `enum PipelineError: Error, Sendable { ... }`
- Some errors conform to `LocalizedError` for human-readable messages: `ModelResolutionError`, `ZImageQuantizationError`, `LoRAError`
- Errors include associated values for context: `case weightsMissing(String)`, `case fileNotFound(String)`
- Custom `errorDescription` implementation for `LocalizedError` conformance
- `throws` keyword for functions that can fail
- `try` keyword required at call sites
- `do-catch` blocks for multiple error cases or error transformation:
  ```swift
  private func encodePrompt(...) throws -> (MLXArray, MLXArray) {
    do {
      let result = try PipelineUtilities.encodePrompt(...)
      return (result.embeddings, result.mask)
    } catch {
      throw PipelineError.textEncoderNotLoaded
    }
  }
  ```

**Preconditions:**
- `precondition()` for argument validation: `precondition(numInferenceSteps > 0, "numInferenceSteps must be positive")`
- Used to enforce invariants in initializers and public methods
- Not used for runtime error handling (reserved for programmer errors)

**Guards:**
- `guard let` for optional unwrapping and early returns: `guard let tokenizer = tokenizer else { ... }`
- `guard` used extensively to validate data before processing

## Logging

**Framework:** `Logging` (apple/swift-log)

**Patterns:**
- Logger instance created at module level or class level:
  ```swift
  private var logger: Logger
  self.logger = Logger(label: "z-image.pipeline")
  ```
- Info level for pipeline operations: `logger.info("Metal device: \(dev.name)")`
- Warning level for degradations: `logger.warning("No Metal device detected")`
- Debug level available but not observed in source
- Closures passed to logging: `logger.info("Processing step", metadata: ["step": "\(i)"])`

## Comments

**When to Comment:**
- Test methods have doc comments describing test scenarios
- Complex algorithms have inline explanations (observed in `ImageIO.swift` Lanczos resize implementation)
- Magic numbers are explained: `let support = 3.0  // Lanczos support radius`
- No comments for self-documenting code (function names are descriptive)

**Style:**
- Single-line comments with `//`
- Block comments with `///` for doc comments in tests only
- MARK comments for test organization: `// MARK: - Basic Generation Tests`
- No module-level documentation headers

## Function Design

**Size:**
- Functions range from 1 line (passthrough methods) to ~50+ lines (complex pipeline steps)
- Smaller functions preferred for composability
- Long functions broken into helper methods in same file or separate utility files

**Parameters:**
- Explicit parameter names required at call sites (Swift default behavior)
- Default values used for optional behavior: `func init(..., seed: UInt64? = nil, ...)`
- Builder pattern for complex configurations:
  ```swift
  public init(
    prompt: String,
    negativePrompt: String? = nil,
    width: Int = ZImageModelMetadata.recommendedWidth,
    ...
  )
  ```

**Return Values:**
- Tuples used for multiple returns: `(embeddings: MLXArray, mask: MLXArray)`
- Throws for error cases instead of optional returns
- Async functions for long-running operations: `func generate(_ request: ZImageGenerationRequest) async throws -> URL`

## Module Design

**Exports:**
- All public types and functions marked with `public` keyword
- Internal implementation details marked `private` or `internal`
- Module info decorators used for MLX neural network components: `@ModuleInfo(key: "layers")`

**Barrel Files:**
- No barrel file pattern observed
- Each file exports its own public types

## Concurrency

**Patterns:**
- `Sendable` protocol used for thread-safe types: `public struct ZImageGenerationRequest: Sendable`
- `@unchecked Sendable` for types with internal synchronization: `public struct LoRAWeights: @unchecked Sendable`
- `async`/`await` for asynchronous operations: `func generate(...) async throws -> URL`
- `Dispatch` framework used for concurrency coordination in CLI

**Thread Safety:**
- Property access guarded by preconditions and state checks
- MLX operations are GPU-scheduled internally

---

*Convention analysis: 2025-05-05*

# Technology Stack

**Analysis Date:** 2025-05-05

## Languages

**Primary:**
- Swift 5.9+ - All source code in `Sources/ZImage/`, `Sources/ZImageCLI/`, and tests

## Runtime

**Environment:**
- macOS 14.0+ / iOS 16+
- Apple Silicon (native ARM64 execution)
- Swift Package Manager (SPM) - Package management via `Package.swift`

**Package Manager:**
- Swift Package Manager (built-in)
- Lockfile: `Package.resolved` - tracks pinned dependency versions

## Frameworks

**Core ML/ML Inference:**
- MLX Swift 0.29.1 - Metal-accelerated ML array library for Apple Silicon
  - Products: MLX, MLXFast, MLXNN, MLXOptimizers, MLXRandom
  - Location: `https://github.com/ml-explore/mlx-swift`
  - Used for: Tensor operations, neural network layers, GPU acceleration

**Text Processing & Transformers:**
- swift-transformers 0.1.24 - HuggingFace Hub integration and model loading
  - Location: `https://github.com/huggingface/swift-transformers`
  - Used for: Qwen tokenizer, text encoding, model downloading from Hub

**Model Hub Integration:**
- Hub (part of swift-transformers) - HuggingFace Hub API client
  - Used for: Model resolution, weight downloading, caching
  - Classes: `HubApi`, `Hub.Repo`

**Logging:**
- swift-log 1.6.4 - Structured logging framework
  - Location: `https://github.com/apple/swift-log.git`
  - Used for: Application logging via `Logger` in pipeline and CLI

**CLI & Argument Parsing:**
- Swift Argument Parser 1.4.0 (indirect dependency via swift-transformers)
  - Location: `https://github.com/apple/swift-argument-parser.git`
  - Used for: Command-line argument parsing in CLI subcommands

**Utilities:**
- Swift Collections 1.2.1 (indirect dependency)
  - Location: `https://github.com/apple/swift-collections.git`
- Swift Numerics 1.1.1 (indirect dependency)
  - Location: `https://github.com/apple/swift-numerics`
- Jinja 1.3.0 (indirect dependency via swift-transformers)
  - Location: `https://github.com/johnmai-dev/Jinja`

## Platform Frameworks (Built-in)

**Image Processing:**
- `CoreGraphics` - Image rendering, pixel manipulation
- `ImageIO` - PNG encoding/decoding
- `UniformTypeIdentifiers` - File type identification

**System:**
- `Foundation` - Core utilities, FileManager, ProcessInfo, URLSession
- `Dispatch` - Concurrency primitives (DispatchSemaphore)
- `Metal` - GPU device detection via `MTLCreateSystemDefaultDevice()`
- `Logging` (apple/swift-log) - Structured logging

## Key Dependencies

**Critical:**
- mlx-swift 0.29.1 - Core tensor computation and neural network inference
  - Why it matters: Entire ML pipeline depends on this for diffusion steps and model inference
  - Enables Metal GPU acceleration on Apple Silicon

- swift-transformers 0.1.24 - Text encoding and HuggingFace Hub integration
  - Why it matters: Loads Qwen tokenizer and text encoder; enables downloading models from Hub
  - File affected: `Sources/ZImage/Model/TextEncoder/TextEncoder.swift`, `Sources/ZImage/Weights/HubSnapshot.swift`

- swift-log 1.6.4 - Logging throughout application
  - Why it matters: Provides structured logging for debugging pipeline execution
  - Usage: Logger initialized in `Sources/ZImageCLI/main.swift` and pipelines

**Infrastructure:**
- Hub (from swift-transformers) - Model repository client
  - Provides: `HubApi`, `Hub.Repo`, model downloading with caching
  - Used in: `ModelResolution.swift`, `HubSnapshot.swift`, pipeline initialization

## Configuration

**Environment Variables:**
Runtime behavior controlled via environment variables read in `Sources/ZImage/Weights/ModelResolution.swift`:
- `HF_HUB_CACHE` - Override HuggingFace Hub cache directory (highest priority)
- `HF_HOME` - HuggingFace home directory (appends `/hub` for cache)
- Falls back to `~/.cache/huggingface/hub` if neither set
- `HF_TOKEN` - Optional HuggingFace API token for private models (passed to `HubApi`)

**Build Configuration:**
- Platform targets: macOS, iOS
- Minimum OS: macOS 14.0, iOS 16
- Build tool: xcodebuild with Xcode schemes (`zimage.swift`, `ZImageCLI`)

## Platform Requirements

**Development:**
- macOS 14.0+
- Apple Silicon (M1 or later)
- Swift 5.9+
- Xcode with Swift toolchain

**Production:**
- Apple Silicon Mac (M1/M2/M3+ series)
- Typical deployment: Command-line binary built with `xcodebuild -scheme ZImageCLI -configuration Release`
- Output binary location: `.build/xcode/Build/Products/Release/ZImageCLI`

**GPU Requirements:**
- Metal GPU acceleration automatic on Apple Silicon
- Falls back to CPU if Metal device unavailable
- GPU memory configurable via CLI `--cache-limit` flag (default unlimited)

---

*Stack analysis: 2025-05-05*

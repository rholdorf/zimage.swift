# External Integrations

**Analysis Date:** 2025-05-05

## APIs & External Services

**HuggingFace Hub:**
- Service: Model hosting and downloading
  - What it's used for: Downloading Z-Image-Turbo weights, ControlNet models, LoRA weights, text encoders
  - SDK/Client: `HubApi` from swift-transformers library
  - Auth: HF_TOKEN environment variable (optional, for private models)
  - Implementation: `Sources/ZImage/Weights/HubSnapshot.swift`, `Sources/ZImage/Weights/ModelResolution.swift`
  - Features:
    - Repository snapshots with file pattern matching
    - Progress callbacks for download tracking
    - Cache management with smart detection of cached models
    - Offline mode support (`useOfflineMode` in `HubApi`)
    - Background session support for long-running downloads

**Default Model Repository:**
- Location: Tongyi-MAI/Z-Image-Turbo on HuggingFace Hub
  - Default model ID: `Tongyi-MAI/Z-Image-Turbo`
  - Default revision: `main`
  - Defined in: `Sources/ZImage/Support/ModelMetadata.swift` (ZImageRepository struct)

**ControlNet Models:**
- alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union (v2.0 and v2.1)
  - Used for: Conditional image generation with pose, depth, edge, and inpainting control
  - Integration: `Sources/ZImage/Pipeline/ZImageControlPipeline.swift`
  - Loading: Downloads from HuggingFace or loads from local path

## Data Storage

**Model Weights:**
- Format: safetensors files (.safetensors)
  - Loaded by: `SafeTensorsReader.swift` - Custom binary safetensors parser
  - Applied by: `WeightsMapping.swift` - Maps loaded weights to MLX model layers
  - Quantization support: 4-bit and 8-bit quantization via `ZImageQuantization.swift`
  - Locations: Transformer, TextEncoder, VAE, ControlNet components

**Cache Directory:**
- Default location: `~/.cache/huggingface/hub/`
- Environment control: `HF_HUB_CACHE`, `HF_HOME`
- Cache structure: `models--{org}--{repo}/snapshots/{revision}/`
- Smart cache detection: Scans for `model_index.json`, `config.json`, and `.safetensors` files
- Implementation: `Sources/ZImage/Weights/ModelResolution.swift`

**Local File Storage:**
- Input: PNG images for generation/inpainting/control
  - Loaded via: `CoreGraphics`, `ImageIO` frameworks
  - Conversion: CGImage → MLXArray (float32 normalized to [-1, 1])
  - Location: `Sources/ZImage/Util/ImageIO.swift`

- Output: Generated PNG images
  - Saved via: `CGImageDestination` from ImageIO
  - Array format conversion: MLXArray → CGImage (float32 [0,1] → uint8 ARGB)
  - Path: User-specified via CLI `--output` flag

**Configuration Files:**
- JSON format: Model configs, transformer config, VAE config, scheduler config
- Parser: `JSONDecoder` for config structs
- Location: `Sources/ZImage/Weights/ModelConfigs.swift`

## File Storage

**Local Filesystem:**
- Models: User-managed via CLI `--model` argument (local path or HuggingFace ID)
- LoRA weights: User-provided `.safetensors` files (local or HuggingFace ID via `--lora`)
- Input images: User paths to PNG files
- Output: Single PNG file written to disk via `QwenImageIO.saveImage()`

**No cloud storage:** All model caching and weights handled locally via HuggingFace Hub cache directory

## Caching

**HuggingFace Hub Caching:**
- Mechanism: `HubApi` manages automatic caching with directory watching
- Cache directory: `~/.cache/huggingface/hub/` (configurable via env)
- Cache detection: Smart lookup for already-downloaded models in `ModelResolution.findCachedModel()`
- Invalidation: Manual via `HubSnapshot.invalidateCache()` method
- Background downloads: Supported via `useBackgroundSession` flag in `HubApi`

**Model Resolution Cache:**
- Once resolved (URL obtained), model path cached in `HubSnapshot` actor
- In-memory caching prevents re-downloading during pipeline lifetime

**No other caching layers** - Relies entirely on HuggingFace Hub caching

## Authentication & Identity

**Auth Provider:**
- HuggingFace API Token
  - Implementation: Optional `hfToken` parameter in `HubApi` initialization
  - Environment: `HF_TOKEN` environment variable (if needed for private models)
  - Usage: Automatically added to Hub API requests for authentication
  - Files: `Sources/ZImage/Weights/HubSnapshot.swift`, `Sources/ZImage/Weights/ModelResolution.swift`

**No custom authentication:**
- No user login system
- No API keys beyond HF_TOKEN
- No OAuth or session management

## Monitoring & Observability

**Error Tracking:**
- None detected - No error reporting service integration

**Logs:**
- Framework: Swift's `Logging` (apple/swift-log)
- Output: Standard error via `StreamLogHandler.standardError(label:)` in `Sources/ZImageCLI/main.swift`
- Log levels: Info, warning, error
- Pipeline logging: Each pipeline (ZImagePipeline, ZImageControlPipeline) logs initialization, model loading, generation progress

**Progress Tracking:**
- Progress callbacks: Foundation `Progress` type used in model downloads
- Handler: `@Sendable` progress closures for download tracking
- Location: `Sources/ZImage/Weights/ModelResolution.swift`, `Sources/ZImage/Weights/HubSnapshot.swift`
- Calculated metrics: `fractionCompleted`, `completedUnitCount`, `totalUnitCount`, `estimatedSpeedBytesPerSecond`

**No metrics/telemetry service** - All observability is local logging and console output

## CI/CD & Deployment

**Hosting:**
- Deployment model: Standalone CLI binary
  - Built with: `xcodebuild -scheme ZImageCLI -configuration Release -destination 'platform=macOS'`
  - Output: `.build/xcode/Build/Products/Release/ZImageCLI` executable
  - No server deployment required

**CI Pipeline:**
- Not detected in codebase - No GitHub Actions, GitLab CI, or other CI configuration files found
- Testing: Manual via xcodebuild with test schemes
  - Unit tests: `xcodebuild test -scheme zimage.swift -only-testing:ZImageTests`
  - Integration tests: `xcodebuild test -scheme zimage.swift -only-testing:ZImageIntegrationTests`
  - E2E tests: `xcodebuild test -scheme zimage.swift -only-testing:ZImageE2ETests`

**No continuous deployment automation** - Binary manually built and distributed

## Environment Configuration

**Required Environment Variables:**
- `HF_TOKEN` (optional) - HuggingFace API token for private models
- `HF_HUB_CACHE` or `HF_HOME` (optional) - Override default Hub cache location

**Required CLI Arguments:**
- `--prompt` / `-p` - Text prompt for image generation (required)
- Other args optional with defaults (dimensions, steps, guidance scale, etc.)

**Secrets Location:**
- `HF_TOKEN` passed via environment (never committed to repo)
- No other secrets required or managed

## Webhooks & Callbacks

**Incoming:**
- None detected - No webhook endpoints

**Outgoing:**
- None detected - No callbacks to external services

**Progress Callbacks:**
- Internal: Download progress via `ProgressHandler` closures in Hub API
- Not webhooks - Local async callbacks within Swift Task context
- Implementation: `Sources/ZImage/Weights/ModelResolution.swift`, `Sources/ZImage/Weights/HubSnapshot.swift`

## Model Distribution

**Remote Models:**
- Primary source: HuggingFace Hub
  - Support: Any public or private (with auth token) HuggingFace model
  - Default: `Tongyi-MAI/Z-Image-Turbo`
  - Format: safetensors with config.json

- ControlNet models: `alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union-*`
  - Versions: v2.0, v2.1 (with inpainting support)

- LoRA models: Any HuggingFace LoRA weights
  - CLI support: `--lora repo-org/repo-name --lora-scale 0.8`
  - Implementation: `Sources/ZImage/LoRA/LoRALoader.swift`

**Local Models:**
- Support: Direct file paths or directories
  - Detection: `ModelResolution.isHuggingFaceModelId()` checks for local vs HF IDs
  - Pattern: `/path/to/model` or `./relative/path` or `~/home-relative`
  - No download for local paths - loads directly

---

*Integration audit: 2025-05-05*
